//
//  WebWallpaperView.swift
//  AIStreamWallpaper
//
//  WKWebView-based wallpaper for streaming Midjourney TV
//

import AppKit
import WebKit
import Combine

class WebWallpaperView: NSView {
    
    // MARK: - Properties
    
    private(set) var webView: WKWebView!  // 외부에서 읽기만 가능
    private var cancellables = Set<AnyCancellable>()
    
    var isMuted: Bool = true {
        didSet {
            updateMuteState()
        }
    }
    
    var currentVideoURL: URL?
    var currentMetadata: VideoMetadata?
    var currentPrompt: String?
    
    var onVideoDetected: ((URL, VideoMetadata) -> Void)?
    
    // MARK: - Initialization
    
    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        setupWebView()
    }
    
    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setupWebView()
    }
    
    deinit {
        webView?.configuration.userContentController.removeScriptMessageHandler(forName: "videoHandler")
    }
    
    // MARK: - Setup
    
    private func setupWebView() {
        wantsLayer = true
        
        // Configure WebView with performance settings
        let config = WKWebViewConfiguration()
        config.mediaTypesRequiringUserActionForPlayback = []
        config.allowsAirPlayForMediaPlayback = false
        
        // Suppress media capture for better performance
        config.suppressesIncrementalRendering = true
        
        // Allow inline playback
        let preferences = WKWebpagePreferences()
        preferences.allowsContentJavaScript = true
        config.defaultWebpagePreferences = preferences
        
        // Performance preferences
        let webPrefs = config.preferences
        webPrefs.setValue(true, forKey: "acceleratedDrawingEnabled")
        
        // Register message handler for video interception
        let contentController = config.userContentController
        contentController.add(self, name: "videoHandler")
        
        // Create WebView
        webView = WKWebView(frame: bounds, configuration: config)
        webView.autoresizingMask = [.width, .height]
        webView.navigationDelegate = self
        webView.uiDelegate = self
        
        // Make background transparent
        webView.setValue(false, forKey: "drawsBackground")
        
        // Performance: Use layer-backed views
        webView.wantsLayer = true
        webView.layerContentsRedrawPolicy = .onSetNeedsDisplay
        
        // Add to view hierarchy
        addSubview(webView)
        
        // Setup observers
        setupObservers()
    }
    
    private func setupObservers() {
        // Use removeDuplicates and debounce to reduce processing
        ConfigurationManager.shared.$config
            .debounce(for: .milliseconds(200), scheduler: DispatchQueue.main)
            .removeDuplicates { old, new in
                old.behavior.muteAudio == new.behavior.muteAudio &&
                old.overlay == new.overlay
            }
            .sink { [weak self] config in
                self?.isMuted = config.behavior.muteAudio
                self?.applyOverlaySettings(config.overlay)
            }
            .store(in: &cancellables)
    }
    
    // MARK: - Overlay Settings
    
    private var overlayView: NSView?
    private var currentOverlay: OverlayConfiguration?
    
    func applyOverlaySettings(_ overlay: OverlayConfiguration) {
        // Skip if unchanged
        if currentOverlay == overlay { return }
        currentOverlay = overlay
        
        // Simple opacity - no expensive filters
        webView.alphaValue = overlay.opacity
        
        // Use a simple dark overlay instead of CIFilters (much less CPU)
        if overlay.brightness < 0 || overlay.saturation < 1.0 || overlay.blur > 0 {
            if overlayView == nil {
                overlayView = NSView(frame: bounds)
                overlayView?.autoresizingMask = [.width, .height]
                overlayView?.wantsLayer = true
                addSubview(overlayView!, positioned: .above, relativeTo: webView)
            }
            
            // Dark overlay for brightness
            let darkness = max(0, -overlay.brightness)
            overlayView?.layer?.backgroundColor = NSColor.black.withAlphaComponent(darkness * 0.7).cgColor
            
            // Blur uses simple visual effect (if needed and > threshold)
            if overlay.blur > 5 {
                overlayView?.layer?.backgroundColor = NSColor.black.withAlphaComponent(0.1).cgColor
            }
            
            overlayView?.isHidden = false
        } else {
            overlayView?.isHidden = true
        }
    }
    
    // MARK: - Public Methods
    
    func loadMidjourneyTV() {
        let url = ConfigurationManager.shared.config.streaming.selectedSource.url
        guard let webURL = URL(string: url) else { return }
        webView.load(URLRequest(url: webURL))
        print("Loading: \(url)")
    }
    
    func loadURL(_ url: URL) {
        webView.load(URLRequest(url: url))
    }
    
    func pause() {
        webView.evaluateJavaScript("document.querySelectorAll('video').forEach(v => v.pause())", completionHandler: nil)
    }
    
    func play() {
        webView.evaluateJavaScript("document.querySelectorAll('video').forEach(v => v.play())", completionHandler: nil)
    }
    
    func reload() {
        webView.reload()
    }
    
    /// Copy current video prompt to clipboard
    func copyPromptToClipboard() {
        // JavaScript to extract prompt from Midjourney TV
        let script = """
        (function() {
            // Try to find prompt from various possible locations
            const videoInfo = document.querySelector('[class*="video-info"]') ||
                             document.querySelector('[class*="VideoInfo"]') ||
                             document.querySelector('[class*="prompt"]') ||
                             document.querySelector('[class*="Prompt"]');
            
            if (videoInfo) {
                return videoInfo.textContent?.trim() || '';
            }
            
            // Try to find in overlay or detail panel
            const overlay = document.querySelector('[class*="overlay"]') ||
                           document.querySelector('[class*="detail"]');
            if (overlay) {
                const text = overlay.textContent?.trim();
                if (text && text.length > 10) {
                    return text.substring(0, 500);
                }
            }
            
            // Try clicking the info button first
            const infoBtn = document.querySelector('button[class*="info"]') ||
                           document.querySelector('[class*="InfoButton"]') ||
                           document.querySelector('a[href*="/job/"]');
            
            if (infoBtn && infoBtn.href) {
                return 'JOB_URL:' + infoBtn.href;
            }
            
            return '';
        })();
        """
        
        webView.evaluateJavaScript(script) { [weak self] result, error in
            if let promptText = result as? String, !promptText.isEmpty {
                if promptText.hasPrefix("JOB_URL:") {
                    // Found job URL, try to fetch prompt from there
                    self?.fetchPromptFromJobURL(promptText.replacingOccurrences(of: "JOB_URL:", with: ""))
                } else {
                    self?.copyToClipboard(promptText)
                }
            } else if let currentPrompt = self?.currentPrompt, !currentPrompt.isEmpty {
                self?.copyToClipboard(currentPrompt)
            } else {
                self?.showCopyNotification(success: false, message: "프롬프트를 찾을 수 없습니다")
            }
        }
    }
    
    private func fetchPromptFromJobURL(_ urlString: String) {
        guard let url = URL(string: urlString) else { return }
        
        let task = URLSession.shared.dataTask(with: url) { [weak self] data, response, error in
            guard let data = data, let html = String(data: data, encoding: .utf8) else {
                DispatchQueue.main.async {
                    self?.showCopyNotification(success: false, message: "프롬프트를 가져올 수 없습니다")
                }
                return
            }
            
            // Extract prompt from HTML
            // Look for patterns like "prompt": "..." or class="prompt"
            if let range = html.range(of: #""prompt"\s*:\s*"([^"]+)""#, options: .regularExpression),
               let match = html[range].split(separator: ":").last {
                let prompt = String(match).trimmingCharacters(in: CharacterSet(charactersIn: "\" "))
                DispatchQueue.main.async {
                    self?.copyToClipboard(prompt)
                }
            } else {
                DispatchQueue.main.async {
                    self?.showCopyNotification(success: false, message: "프롬프트를 찾을 수 없습니다")
                }
            }
        }
        task.resume()
    }
    
    private func copyToClipboard(_ text: String) {
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.setString(text, forType: .string)
        showCopyNotification(success: true, message: "프롬프트가 클립보드에 복사되었습니다")
    }
    
    private func showCopyNotification(success: Bool, message: String) {
        let center = UNUserNotificationCenter.current()
        
        let content = UNMutableNotificationContent()
        content.title = success ? "✓ 복사 완료" : "⚠ 복사 실패"
        content.body = message
        content.sound = success ? nil : .default
        
        let request = UNNotificationRequest(identifier: UUID().uuidString, content: content, trigger: nil)
        center.add(request)
    }
    
    // MARK: - Private Methods
    
    private func updateMuteState() {
        let muteScript = isMuted
            ? "document.querySelectorAll('video').forEach(v => v.muted = true)"
            : "document.querySelectorAll('video').forEach(v => v.muted = false)"
        
        webView.evaluateJavaScript(muteScript, completionHandler: nil)
    }
    
    private func injectVideoObserver() {
        // 비디오 감지 스크립트 - 영상 전환 시 순차적으로 감지 (폴링 없음)
        let script = """
        (function() {
            if (window._streamWPInjected) return;
            window._streamWPInjected = true;
            
            let lastSrc = null;
            
            function notifyVideoChange(video, source) {
                if (!video) return;
                const src = video.src || video.currentSrc;
                if (!src || src.startsWith('blob:')) return;
                
                // 새 소스일 때만 알림
                if (src !== lastSrc) {
                    console.log('[StreamWP] 🎬 New video (' + source + '):', src.substring(src.lastIndexOf('/') + 1));
                    lastSrc = src;
                    
                    window.webkit.messageHandlers.videoHandler.postMessage({
                        type: 'videoFound',
                        src: src,
                        duration: video.duration || 0
                    });
                    
                    // 메타데이터 추출
                    setTimeout(() => extractMetadata(src), 500);
                }
            }
            
            function extractMetadata(videoSrc) {
                const promptEl = document.querySelector('[class*="prompt"]') ||
                                document.querySelector('[class*="Prompt"]') ||
                                document.querySelector('[class*="description"]');
                const authorEl = document.querySelector('[class*="author"]') ||
                                document.querySelector('a[href*="/u/"]');
                
                window.webkit.messageHandlers.videoHandler.postMessage({
                    type: 'metadata',
                    prompt: promptEl?.textContent?.substring(0, 500)?.trim(),
                    author: authorEl?.textContent?.trim(),
                    videoSrc: videoSrc
                });
            }
            
            function setupVideoListeners(video) {
                if (!video || video._streamWPWatched) return;
                video._streamWPWatched = true;
                
                console.log('[StreamWP] Setting up video listeners');
                
                // src 속성 변경 감지 (가장 중요)
                new MutationObserver(() => {
                    notifyVideoChange(video, 'srcChange');
                }).observe(video, { attributes: true, attributeFilter: ['src'] });
                
                // 영상 로드 시작
                video.addEventListener('loadstart', () => {
                    console.log('[StreamWP] loadstart event');
                    setTimeout(() => notifyVideoChange(video, 'loadstart'), 200);
                });
                
                // 메타데이터 로드 완료
                video.addEventListener('loadedmetadata', () => {
                    notifyVideoChange(video, 'loadedmetadata');
                });
                
                // 재생 시작
                video.addEventListener('play', () => {
                    notifyVideoChange(video, 'play');
                });
                
                // 영상 종료 (다음 영상 준비)
                video.addEventListener('ended', () => {
                    console.log('[StreamWP] Video ended - ready for next');
                    lastSrc = null;
                });
            }
            
            // DOM 변경 감시 (video 요소 추가/변경)
            new MutationObserver(() => {
                const video = document.querySelector('video');
                if (video) {
                    setupVideoListeners(video);
                    notifyVideoChange(video, 'domChange');
                }
            }).observe(document.body, { 
                childList: true, 
                subtree: true
            });
            
            // 초기 설정
            setTimeout(() => {
                const video = document.querySelector('video');
                if (video) {
                    setupVideoListeners(video);
                    notifyVideoChange(video, 'initial');
                }
            }, 1000);
        })();
        """
        
        webView.evaluateJavaScript(script) { _, error in
            if let error = error {
                print("Failed to inject video observer: \(error)")
            } else {
                print("Video observer injected successfully")
            }
        }
    }
}

// MARK: - WKNavigationDelegate

extension WebWallpaperView: WKNavigationDelegate {
    func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        print("WebView finished loading")
        
        // Mute videos by default
        updateMuteState()
        
        // Inject video observer
        injectVideoObserver()
        
        // Apply overlay settings
        applyOverlaySettings(ConfigurationManager.shared.config.overlay)
        
        // Auto-play videos
        webView.evaluateJavaScript("document.querySelectorAll('video').forEach(v => v.play())", completionHandler: nil)
    }
    
    func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) {
        print("WebView failed to load: \(error)")
    }
    
    func webView(_ webView: WKWebView, decidePolicyFor navigationAction: WKNavigationAction, decisionHandler: @escaping (WKNavigationActionPolicy) -> Void) {
        decisionHandler(.allow)
    }
}

// MARK: - WKUIDelegate

extension WebWallpaperView: WKUIDelegate {
    func webView(_ webView: WKWebView, createWebViewWith configuration: WKWebViewConfiguration, for navigationAction: WKNavigationAction, windowFeatures: WKWindowFeatures) -> WKWebView? {
        if let url = navigationAction.request.url {
            webView.load(URLRequest(url: url))
        }
        return nil
    }
}

// MARK: - WKScriptMessageHandler

extension WebWallpaperView: WKScriptMessageHandler {
    func userContentController(_ userContentController: WKUserContentController, didReceive message: WKScriptMessage) {
        guard let body = message.body as? [String: Any] else { return }
        
        let type = body["type"] as? String
        
        switch type {
        case "videoFound":
            if let src = body["src"] as? String,
               !src.isEmpty,
               !src.hasPrefix("blob:"),
               let url = URL(string: src) {
                print("Video detected: \(src)")
                currentVideoURL = url
                
                if currentMetadata == nil {
                    currentMetadata = VideoMetadata(sourceUrl: src, prompt: nil, author: nil, midjourneyJobId: nil)
                } else {
                    currentMetadata?.sourceUrl = src
                }
                
                onVideoDetected?(url, currentMetadata!)
            }
            
        case "metadata":
            let prompt = body["prompt"] as? String
            let author = body["author"] as? String
            let videoSrc = body["videoSrc"] as? String
            
            if let p = prompt, !p.isEmpty {
                currentPrompt = p
            }
            
            if currentMetadata == nil {
                currentMetadata = VideoMetadata(
                    sourceUrl: videoSrc ?? "",
                    prompt: prompt,
                    author: author,
                    midjourneyJobId: nil
                )
            } else {
                if let p = prompt, !p.isEmpty { currentMetadata?.prompt = p }
                if let a = author, !a.isEmpty { currentMetadata?.author = a }
            }
            
            if let src = videoSrc, !src.isEmpty, !src.hasPrefix("blob:"), let url = URL(string: src) {
                currentVideoURL = url
            }
            
        default:
            break
        }
    }
}

// Import for notifications
import UserNotifications
