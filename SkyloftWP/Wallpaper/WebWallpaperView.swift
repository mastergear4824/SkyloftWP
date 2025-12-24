//
//  WebWallpaperView.swift
//  SkyloftWP
//
//  WKWebView-based wallpaper for streaming video sources
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
    
    func loadStreamingSource() {
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
        // JavaScript to extract prompt from streaming source
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
        // 소스의 fetchMode에 따라 폴링 활성화 여부 결정
        let currentSource = ConfigurationManager.shared.config.streaming.selectedSource
        let enablePolling = currentSource.fetchMode == .polling
        let isStreaming = currentSource.fetchMode == .streaming
        
        let script = """
        (function() {
            if (window._streamWPInjected) return;
            window._streamWPInjected = true;
            
            const ENABLE_POLLING = \(enablePolling);
            const IS_STREAMING = \(isStreaming);
            
            let lastSrc = null;
            let collectedVideos = new Set();
            let pollingInterval = null;
            const POLLING_INTERVAL = 30000; // 30초마다
            
            console.log('[StreamWP] Mode: ' + (IS_STREAMING ? 'Streaming (Event-based)' : 'Polling (Periodic)'));
            
            function notifyVideoChange(video, source) {
                if (!video) return;
                const src = video.src || video.currentSrc;
                if (!src || src.startsWith('blob:') || src.startsWith('data:')) return;
                
                // 이미 수집된 비디오면 스킵
                if (collectedVideos.has(src)) return;
                
                // 16:9 비율 확인 (메타데이터 로드된 경우)
                if (video.videoWidth > 0 && video.videoHeight > 0) {
                    if (!is16x9(video.videoWidth, video.videoHeight)) {
                        console.log('[StreamWP] ❌ Skipping non-16:9: ' + video.videoWidth + 'x' + video.videoHeight);
                        collectedVideos.add(src); // 다시 체크 안 하도록
                        return;
                    }
                    console.log('[StreamWP] ✅ 16:9 verified: ' + video.videoWidth + 'x' + video.videoHeight);
                }
                
                // 새 소스일 때만 알림
                if (src !== lastSrc) {
                    console.log('[StreamWP] 🎬 New video (' + source + '):', src.substring(src.lastIndexOf('/') + 1));
                    lastSrc = src;
                    collectedVideos.add(src);
                    
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
                                document.querySelector('[class*="description"]') ||
                                document.querySelector('h1') ||
                                document.querySelector('[class*="title"]');
                const authorEl = document.querySelector('[class*="author"]') ||
                                document.querySelector('a[href*="/u/"]') ||
                                document.querySelector('[class*="user"]');
                
                window.webkit.messageHandlers.videoHandler.postMessage({
                    type: 'metadata',
                    prompt: promptEl?.textContent?.substring(0, 500)?.trim(),
                    author: authorEl?.textContent?.trim(),
                    videoSrc: videoSrc
                });
            }
            
            // 16:9 비율 확인 (허용 오차 5%)
            function is16x9(width, height) {
                if (!width || !height || height === 0) return false;
                const ratio = width / height;
                const targetRatio = 16 / 9; // 1.777...
                return ratio >= targetRatio * 0.95 && ratio <= targetRatio * 1.05;
            }
            
            // 페이지에서 비디오 링크 수집 (스톡 사이트용)
            function collectVideoLinks() {
                if (IS_STREAMING) return []; // 스트리밍 모드는 폴링 수집 안함
                
                const videoLinks = [];
                const addedUrls = new Set();
                
                function addLink(url) {
                    if (!url || addedUrls.has(url)) return;
                    if (url.startsWith('blob:') || url.startsWith('data:')) return;
                    addedUrls.add(url);
                    videoLinks.push(url);
                }
                
                // 1. 직접 video 태그
                document.querySelectorAll('video').forEach(video => {
                    const src = video.src || video.currentSrc;
                    if (src) addLink(src);
                });
                
                // 2. video source 태그
                document.querySelectorAll('video source').forEach(source => {
                    const src = source.src || source.getAttribute('src');
                    if (src) addLink(src);
                });
                
                // 3. Pixabay 스타일 - file-url 파라미터에서 추출
                document.querySelectorAll('a[href*="file-url="]').forEach(link => {
                    try {
                        const href = link.href;
                        const urlParams = new URLSearchParams(href.split('?')[1]);
                        const fileUrl = urlParams.get('file-url');
                        if (fileUrl) {
                            const decoded = decodeURIComponent(fileUrl);
                            if (decoded.includes('.mp4') || decoded.includes('.webm')) {
                                console.log('[StreamWP] 📦 Pixabay-style video found:', decoded.substring(decoded.lastIndexOf('/') + 1));
                                addLink(decoded);
                            }
                        }
                    } catch (e) { /* ignore */ }
                });
                
                // 4. data-video-urls 속성에서 추출 (일부 사이트)
                document.querySelectorAll('[data-video-urls]').forEach(el => {
                    try {
                        const urls = JSON.parse(el.getAttribute('data-video-urls'));
                        if (Array.isArray(urls)) {
                            urls.forEach(u => addLink(u.url || u.src || u));
                        } else if (typeof urls === 'object') {
                            Object.values(urls).forEach(u => addLink(u));
                        }
                    } catch (e) { /* ignore */ }
                });
                
                // 5. data-src 또는 data-video 속성 (Lazy loading)
                document.querySelectorAll('[data-src], [data-video]').forEach(el => {
                    const src = el.getAttribute('data-src') || el.getAttribute('data-video');
                    if (src && (src.includes('.mp4') || src.includes('.webm'))) {
                        addLink(src);
                    }
                });
                
                // 6. 페이지 HTML에서 CDN 패턴 직접 탐색 (Pixabay CDN 등)
                const cdnPatterns = [
                    /https?:\\/\\/cdn\\.pixabay\\.com\\/video\\/[^\\s"'<>]+\\.mp4/gi,
                    /https?:\\/\\/[^\\s"'<>]+\\.pexels\\.com[^\\s"'<>]+\\.mp4/gi,
                    /https?:\\/\\/[^\\s"'<>]+coverr[^\\s"'<>]+\\.mp4/gi
                ];
                
                const pageHtml = document.body.innerHTML;
                cdnPatterns.forEach(pattern => {
                    const matches = pageHtml.match(pattern);
                    if (matches) {
                        matches.forEach(url => {
                            // URL 디코딩 시도
                            try {
                                addLink(decodeURIComponent(url));
                            } catch (e) {
                                addLink(url);
                            }
                        });
                    }
                });
                
                console.log('[StreamWP] 🔍 Found ' + videoLinks.length + ' video links');
                return videoLinks;
            }
            
            // 랜덤 비디오 선택 및 재생 (스톡 사이트용)
            function playRandomVideo() {
                if (IS_STREAMING) return; // 스트리밍 모드는 자동 전환 (폴링 안함)
                
                const links = collectVideoLinks();
                const newLinks = links.filter(l => !collectedVideos.has(l));
                
                if (newLinks.length > 0) {
                    const randomLink = newLinks[Math.floor(Math.random() * newLinks.length)];
                    console.log('[StreamWP] 🎲 Found new video link:', randomLink);
                    
                    // 비디오 URL이면 직접 알림
                    if (randomLink.includes('.mp4') || randomLink.includes('.webm')) {
                        collectedVideos.add(randomLink);
                        window.webkit.messageHandlers.videoHandler.postMessage({
                            type: 'videoFound',
                            src: randomLink,
                            duration: 0
                        });
                    } else {
                        // 페이지 링크면 이동
                        window.location.href = randomLink;
                    }
                } else {
                    // 새 링크 없으면 스크롤해서 더 로드
                    window.scrollBy(0, 500);
                    console.log('[StreamWP] 📜 Scrolling for more content...');
                }
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
                
                // 영상 종료 - 다음 비디오로
                video.addEventListener('ended', () => {
                    console.log('[StreamWP] Video ended - finding next');
                    lastSrc = null;
                    if (!IS_STREAMING) {
                        setTimeout(playRandomVideo, 1000);
                    }
                    // 스트리밍 모드는 자동으로 다음 영상이 재생됨
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
                
                // 폴링 시작 (폴링 모드 전용 - 스트리밍 모드는 비활성화)
                if (ENABLE_POLLING) {
                    console.log('[StreamWP] 🔄 Starting polling mode (infinite scroll)');
                    
                    // 스크롤을 내려서 새 비디오 로드하는 함수
                    function scrollToLoadMore() {
                        window.scrollBy(0, window.innerHeight * 2);
                        console.log('[StreamWP] 📜 Scrolled down to load more');
                    }
                    
                    pollingInterval = setInterval(() => {
                        const links = collectVideoLinks();
                        const newLinks = links.filter(l => !collectedVideos.has(l));
                        
                        if (newLinks.length > 0) {
                            console.log('[StreamWP] 🔍 Found ' + newLinks.length + ' new videos');
                            // 새 비디오 1개만 발견 알림
                            const src = newLinks[0];
                            if (src.includes('.mp4') || src.includes('.webm') || src.includes('.mov')) {
                                collectedVideos.add(src);
                                window.webkit.messageHandlers.videoHandler.postMessage({
                                    type: 'videoFound',
                                    src: src,
                                    duration: 0
                                });
                            }
                        }
                        
                        // 항상 스크롤을 내려서 새 콘텐츠 로드 (무한 스크롤)
                        scrollToLoadMore();
                        
                    }, POLLING_INTERVAL);
                } else {
                    console.log('[StreamWP] ⏹️ Polling disabled (Streaming mode)');
                }
            }, 2000);
            
            // 페이지 언로드 시 정리
            window.addEventListener('beforeunload', () => {
                if (pollingInterval) clearInterval(pollingInterval);
            });
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
