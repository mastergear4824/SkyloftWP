//
//  WallpaperManager.swift
//  SkyloftWP
//
//  Manages wallpaper windows across all monitors
//  새 구조: 재생은 항상 라이브러리에서, 스트리밍은 자동 저장만 담당
//

import AppKit
import Combine
import UserNotifications
import Photos
import AVFoundation

class WallpaperManager: ObservableObject {
    
    // MARK: - Singleton
    
    static let shared = WallpaperManager()
    
    // MARK: - Published Properties
    
    @Published var isPlaying = false
    @Published var isPaused = false
    @Published var isStreamingConnected = false  // 스트리밍 연결 상태
    
    // MARK: - Private Properties
    
    private var wallpaperWindows: [CGDirectDisplayID: WallpaperWindow] = [:]
    private var videoViews: [CGDirectDisplayID: VideoWallpaperView] = [:]
    
    // 스트리밍 연결용 (백그라운드 다운로드)
    private var streamingWebView: WebWallpaperView?
    private var streamingWindow: NSWindow?
    
    private let monitorManager = MonitorManager.shared
    private let configManager = ConfigurationManager.shared
    private let playbackController = PlaybackController.shared
    private let libraryDatabase = LibraryDatabase.shared
    private let libraryManager = LibraryManager.shared
    private let networkMonitor = NetworkMonitorService.shared
    
    private var cancellables = Set<AnyCancellable>()
    private var displayObserver: Any?
    private var currentlySavingIds = Set<String>()  // 현재 저장 중인 비디오 ID (동시 저장 방지)
    private var recentlyProcessedUrls = Set<String>()  // 최근 처리한 URL (중복 방지)
    private let autoSaveQueue = DispatchQueue(label: "com.midtv.autosave", qos: .utility)
    
    // MARK: - Initialization
    
    private init() {
        setupObservers()
        requestNotificationPermission()
    }
    
    // MARK: - Setup
    
    private func requestNotificationPermission() {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound]) { _, _ in }
    }
    
    private func setupObservers() {
        // Observe config changes with debounce
        configManager.$config
            .debounce(for: .milliseconds(300), scheduler: DispatchQueue.main)
            .sink { [weak self] config in
                self?.handleConfigChange(config)
            }
            .store(in: &cancellables)
        
        // Observe playback changes - 초기 재생 및 외부에서 변경 시
        // ⚠️ removeDuplicates 제거: 같은 영상을 클릭해도 재생해야 함
        playbackController.$currentVideo
            .debounce(for: .milliseconds(100), scheduler: DispatchQueue.main)
            .sink { [weak self] video in
                guard let self = self, let video = video else { return }
                // 같은 영상이라도 강제 재생 (사용자가 클릭한 것일 수 있음)
                self.currentlyPlayingVideoId = ""  // ID 리셋
                self.playVideo(video)
            }
            .store(in: &cancellables)
        
        // Observe monitor changes - handled by AppDelegate for better control
        // NotificationCenter.default.addObserver(
        //     self,
        //     selector: #selector(handleDisplayChangeNotification),
        //     name: NSApplication.didChangeScreenParametersNotification,
        //     object: nil
        // )
        
        // Observe new video saved (for auto-advance)
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleVideoSaved),
            name: .videoDidSave,
            object: nil
        )
        
        // 네트워크 상태 변화 감시 - 연결되면 스트리밍 자동 재연결
        networkMonitor.$isConnected
            .dropFirst()  // 초기값 무시
            .sink { [weak self] isConnected in
                guard let self = self else { return }
                
                if isConnected {
                    print("📡 [Network] Connected - checking streaming status...")
                    // 스트리밍 설정이 켜져있고 연결이 안 되어있으면 재연결
                    if self.configManager.config.streaming.connectionEnabled && !self.isStreamingConnected {
                        print("📡 [Network] Reconnecting streaming...")
                        self.startStreamingConnection()
                    }
                } else {
                    print("📡 [Network] Disconnected")
                }
            }
            .store(in: &cancellables)
    }
    
    // MARK: - Public Methods
    
    func start() {
        print("🚀 [Start] App starting...")
        
        // 고아 파일 정리 (이전 크래시로 남은 파일들)
        libraryManager.cleanupOrphanedFiles()
        
        // ⚠️ 앱 시작 시 즉시 최대 개수 강제 적용
        if configManager.config.streaming.autoSaveEnabled {
            let maxCount = configManager.config.streaming.autoSaveCount
            let currentVideos = libraryDatabase.fetchAll()
            print("🚀 [Start] Library: \(currentVideos.count) videos, max: \(maxCount)")
            
            if currentVideos.count > maxCount {
                print("🚀 [Start] ⚠️ Over limit! Deleting \(currentVideos.count - maxCount) oldest videos...")
                let sorted = currentVideos.sorted { $0.savedAt < $1.savedAt }
                let deleteCount = currentVideos.count - maxCount
                for i in 0..<deleteCount {
                    deleteVideo(sorted[i])
                }
                libraryManager.loadLibrary()
                print("🚀 [Start] ✅ Trimmed to \(maxCount) videos")
            }
        }
        
        createWallpaperWindows()
        
        // 스트리밍 연결이 활성화되어 있으면 백그라운드 연결
        if configManager.config.streaming.connectionEnabled {
            startStreamingConnection()
        }
        
        // 📷 Photos Library가 기본 소스로 선택되어 있으면 자동 연결
        let selectedSource = configManager.config.streaming.selectedSource
        if selectedSource.isPhotosLibrary {
            print("📷 [Start] Photos Library is default - auto connecting...")
            startStreamingConnection()
        }
        
        // 라이브러리에서 첫 번째 영상 재생 - 확실하게 실행
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [weak self] in
            guard let self = self else { return }
            
            // 이미 재생 중이면 스킵
            if self.playbackController.currentVideo != nil {
                self.playVideo(self.playbackController.currentVideo!)
                print("🎬 [Start] Resumed current video")
            } else {
                // 라이브러리에서 첫 번째 영상 재생
                self.libraryManager.loadLibrary()
                
                if let firstVideo = self.libraryManager.videos.first {
                    self.playbackController.play(video: firstVideo)
                    print("🎬 [Start] Playing first library video: \(firstVideo.fileName)")
                } else {
                    print("🎬 [Start] No videos in library")
                }
            }
        }
        
        isPlaying = true
        isPaused = false
        
        NotificationCenter.default.post(name: .wallpaperDidStart, object: nil)
    }
    
    func stop() {
        // 재생 중지
        for (_, videoView) in videoViews {
            videoView.pause()
        }
        
        // 스트리밍 연결 종료
        stopStreamingConnection()
        
        isPlaying = false
        isPaused = false
        
        NotificationCenter.default.post(name: .wallpaperDidStop, object: nil)
    }
    
    func togglePlayPause() {
        if isPaused {
            resume()
        } else {
            pause()
        }
    }
    
    func pause() {
        for (_, videoView) in videoViews {
            videoView.pause()
        }
        isPaused = true
    }
    
    func resume() {
        for (_, videoView) in videoViews {
            videoView.play()
        }
        isPaused = false
    }
    
    /// Hide all wallpaper windows (for screen lock)
    func hideWindows() {
        for (_, window) in wallpaperWindows {
            window.safeHide()
        }
        print("🙈 [Windows] Hidden")
    }
    
    /// Show all wallpaper windows (for screen unlock)
    func showWindows() {
        for (_, window) in wallpaperWindows {
            window.safeShow()
        }
        print("👁️ [Windows] Shown")
    }
    
    func nextVideo() {
        playbackController.next()
    }
    
    func previousVideo() {
        playbackController.previous()
    }
    
    // MARK: - Streaming Connection (Auto-Save)
    
    func toggleStreamingConnection() {
        if isStreamingConnected {
            stopStreamingConnection()
        } else {
            startStreamingConnection()
        }
        configManager.config.streaming.connectionEnabled = isStreamingConnected
        configManager.save()
    }
    
    private var streamingKeepAliveTimer: Timer?
    private var photosStreamingTimer: Timer?
    private var usedPhotoAssetIds = Set<String>()  // 이미 사용한 사진 라이브러리 영상 ID
    
    private func startStreamingConnection() {
        let selectedSource = configManager.config.streaming.selectedSource
        
        // Photos Library 소스인 경우
        if selectedSource.isPhotosLibrary {
            // 웹 스트리밍 정리 후 사진 스트리밍 시작
            cleanupWebStreaming()
            startPhotosLibraryStreaming()
            return
        }
        
        // 웹 소스인 경우 - Photos 스트리밍 정리
        stopPhotosLibraryStreaming()
        
        // 네트워크 필요
        guard networkMonitor.isConnected else {
            print("📡 [Streaming] No network - cannot start")
            return
        }
        
        print("📡 [Streaming] Starting continuous connection...")
        
        // 숨겨진 윈도우 생성 (비디오 재생을 위해 화면 밖에 배치)
        if streamingWindow == nil {
            streamingWindow = NSWindow(
                contentRect: NSRect(x: -2000, y: -2000, width: 640, height: 360),
                styleMask: [.borderless],
                backing: .buffered,
                defer: false
            )
            streamingWindow?.isReleasedWhenClosed = false
            streamingWindow?.level = .init(rawValue: -1000)
            streamingWindow?.alphaValue = 0.01
            streamingWindow?.orderFront(nil)
        }
        
        if streamingWebView == nil {
            streamingWebView = WebWallpaperView(frame: streamingWindow!.contentView!.bounds)
            streamingWebView?.autoresizingMask = [.width, .height]
            streamingWebView?.isMuted = true  // 백그라운드이므로 음소거
            streamingWindow?.contentView?.addSubview(streamingWebView!)
            print("📡 [Streaming] Created WebView")
        }
        
        // 비디오 감지 콜백 설정 - 영상이 바뀔 때마다 순차적으로 저장
        streamingWebView?.onVideoDetected = { [weak self] url, metadata in
            print("📡 [Streaming] 🎬 Video detected: \(url.lastPathComponent)")
            self?.handleAutoSave(url: url, metadata: metadata)
        }
        
        // 스트리밍 사이트 로드
        print("📡 [Streaming] Loading streaming source...")
        streamingWebView?.loadStreamingSource()
        isStreamingConnected = true
        
        // Keep-alive 타이머 시작: 비디오가 계속 재생되도록 보장
        startKeepAliveTimer()
        
        print("📡 [Streaming] ✅ Connection started - will stay connected continuously")
    }
    
    // MARK: - Photos Library Streaming
    
    private func startPhotosLibraryStreaming() {
        print("📷 [Photos] Starting Photos Library streaming...")
        
        // 권한 확인
        let status = PHPhotoLibrary.authorizationStatus(for: .readWrite)
        
        switch status {
        case .authorized, .limited:
            // 권한 있음 - 스트리밍 시작
            actuallyStartPhotosStreaming()
            
        case .notDetermined:
            // 권한 요청
            print("📷 [Photos] Requesting authorization...")
            PHPhotoLibrary.requestAuthorization(for: .readWrite) { [weak self] newStatus in
                DispatchQueue.main.async {
                    if newStatus == .authorized || newStatus == .limited {
                        self?.actuallyStartPhotosStreaming()
                    } else {
                        print("📷 [Photos] ❌ Authorization denied by user")
                        self?.showPhotosAccessAlert()
                    }
                }
            }
            
        case .denied, .restricted:
            print("📷 [Photos] ❌ Access denied or restricted")
            showPhotosAccessAlert()
            
        @unknown default:
            print("📷 [Photos] ❌ Unknown authorization status")
        }
    }
    
    private func actuallyStartPhotosStreaming() {
        isStreamingConnected = true
        
        // 즉시 첫 번째 영상 가져오기
        fetchRandomPhotosVideo()
        
        // 타이머 시작 - 10초마다 새 영상 가져오기 (오래된 영상 교체)
        photosStreamingTimer?.invalidate()
        photosStreamingTimer = Timer.scheduledTimer(withTimeInterval: 10.0, repeats: true) { [weak self] _ in
            self?.fetchRandomPhotosVideo()
        }
        
        print("📷 [Photos] ✅ Photos Library streaming started")
    }
    
    private func showPhotosAccessAlert() {
        DispatchQueue.main.async {
            let alert = NSAlert()
            alert.messageText = "Photos Access Required"
            alert.informativeText = "Please allow access to your Photos library in System Settings > Privacy & Security > Photos."
            alert.alertStyle = .warning
            alert.addButton(withTitle: "Open Settings")
            alert.addButton(withTitle: "Cancel")
            
            if alert.runModal() == .alertFirstButtonReturn {
                if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Photos") {
                    NSWorkspace.shared.open(url)
                }
            }
        }
    }
    
    private func stopPhotosLibraryStreaming() {
        guard photosStreamingTimer != nil else { return }  // 이미 정지 상태면 스킵
        photosStreamingTimer?.invalidate()
        photosStreamingTimer = nil
        usedPhotoAssetIds.removeAll()  // 사용한 ID 초기화
        print("📷 [Photos] Stopped Photos Library streaming")
    }
    
    /// 웹 스트리밍 관련 리소스만 정리 (Photos 전환 시 사용)
    private func cleanupWebStreaming() {
        print("📡 [Streaming] Cleaning up web streaming...")
        
        // Keep-alive 타이머 정지
        streamingKeepAliveTimer?.invalidate()
        streamingKeepAliveTimer = nil
        
        // WebView 정지
        streamingWebView?.pause()
        streamingWebView?.onVideoDetected = nil
        
        print("📡 [Streaming] Web streaming cleaned up")
    }
    
    private func fetchRandomPhotosVideo() {
        guard isStreamingConnected else { return }
        
        let maxCount = configManager.config.streaming.autoSaveCount
        
        // 폴더의 실제 파일 수 확인
        let videosDir = libraryManager.videosDirectory
        let actualFiles = (try? FileManager.default.contentsOfDirectory(at: videosDir, includingPropertiesForKeys: [.creationDateKey]))?.filter {
            let ext = $0.pathExtension.lowercased()
            return ext == "mp4" || ext == "mov" || ext == "m4v"
        } ?? []
        
        let currentCount = actualFiles.count
        
        // maxCount 이상이면 오래된 것 삭제 후 계속 진행
        if currentCount >= maxCount {
            print("📷 [Photos] At limit (\(currentCount)/\(maxCount)), deleting oldest...")
            
            // 오래된 순으로 정렬
            let sorted = actualFiles.sorted {
                let date1 = (try? $0.resourceValues(forKeys: [.creationDateKey]))?.creationDate ?? Date.distantPast
                let date2 = (try? $1.resourceValues(forKeys: [.creationDateKey]))?.creationDate ?? Date.distantPast
                return date1 < date2
            }
            
            // 가장 오래된 것 삭제
            if let oldest = sorted.first {
                print("📷 [Photos] 🗑️ Deleting oldest: \(oldest.lastPathComponent)")
                try? FileManager.default.removeItem(at: oldest)
                
                // DB와 동기화
                DispatchQueue.main.async {
                    self.libraryManager.syncFromFolder()
                }
            }
        }
        
        print("📷 [Photos] Fetching random 16:9 video... (current: \(currentCount)/\(maxCount))")
        
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            guard let self = self else { return }
            
            // 16:9 비율 영상만 가져오기
            let fetchOptions = PHFetchOptions()
            fetchOptions.sortDescriptors = [NSSortDescriptor(key: "creationDate", ascending: false)]
            fetchOptions.predicate = NSPredicate(format: "mediaType == %d", PHAssetMediaType.video.rawValue)
            
            let allVideos = PHAsset.fetchAssets(with: .video, options: fetchOptions)
            
            guard allVideos.count > 0 else {
                print("📷 [Photos] No videos in Photos library")
                return
            }
            
            // 16:9 비율 영상 필터링 (허용 오차 5%)
            var widescreenVideos: [PHAsset] = []
            allVideos.enumerateObjects { asset, _, _ in
                let width = CGFloat(asset.pixelWidth)
                let height = CGFloat(asset.pixelHeight)
                let ratio = width / height
                let targetRatio: CGFloat = 16.0 / 9.0
                
                // 16:9 비율 (1.77 ~ 1.87 범위)
                if ratio >= targetRatio * 0.95 && ratio <= targetRatio * 1.05 {
                    // 이미 사용한 영상 제외
                    if !self.usedPhotoAssetIds.contains(asset.localIdentifier) {
                        widescreenVideos.append(asset)
                    }
                }
            }
            
            guard !widescreenVideos.isEmpty else {
                print("📷 [Photos] No 16:9 videos found (or all used)")
                // 모두 사용했으면 리셋
                self.usedPhotoAssetIds.removeAll()
                return
            }
            
            // 무작위 선택
            let randomIndex = Int.random(in: 0..<widescreenVideos.count)
            let selectedAsset = widescreenVideos[randomIndex]
            
            // 사용된 것으로 표시
            self.usedPhotoAssetIds.insert(selectedAsset.localIdentifier)
            
            print("📷 [Photos] Selected random video: \(selectedAsset.localIdentifier)")
            
            // 영상 가져오기 및 라이브러리에 저장
            self.importPhotosAssetToLibrary(selectedAsset)
        }
    }
    
    private func importPhotosAssetToLibrary(_ asset: PHAsset) {
        // PHAssetResource를 사용하여 실제 파일 내보내기
        guard let resource = PHAssetResource.assetResources(for: asset).first(where: { $0.type == .video }) else {
            print("📷 [Photos] No video resource found")
            return
        }
        
        // 임시 파일 경로 생성
        let tempDir = FileManager.default.temporaryDirectory
        let tempFileName = "\(UUID().uuidString).\(resource.originalFilename.split(separator: ".").last ?? "mov")"
        let tempURL = tempDir.appendingPathComponent(tempFileName)
        
        // 기존 임시 파일 삭제
        try? FileManager.default.removeItem(at: tempURL)
        
        let options = PHAssetResourceRequestOptions()
        options.isNetworkAccessAllowed = true
        
        print("📷 [Photos] Exporting video: \(resource.originalFilename)")
        
        PHAssetResourceManager.default().writeData(for: resource, toFile: tempURL, options: options) { [weak self] error in
            guard let self = self else { return }
            
            if let error = error {
                print("📷 [Photos] ❌ Export failed: \(error.localizedDescription)")
                return
            }
            
            // 파일이 제대로 생성되었는지 확인
            guard FileManager.default.fileExists(atPath: tempURL.path) else {
                print("📷 [Photos] ❌ Exported file not found")
                return
            }
            
            let attributes = try? FileManager.default.attributesOfItem(atPath: tempURL.path)
            let fileSize = attributes?[.size] as? Int64 ?? 0
            
            guard fileSize > 0 else {
                print("📷 [Photos] ❌ Exported file is empty")
                try? FileManager.default.removeItem(at: tempURL)
                return
            }
            
            print("📷 [Photos] ✅ Exported successfully (\(fileSize) bytes)")
            
            DispatchQueue.main.async {
                // maxCount 체크 - 초과 시 가져오지 않음
                let maxCount = self.configManager.config.streaming.autoSaveCount
                if self.libraryManager.videos.count >= maxCount {
                    print("📷 [Photos] ⚠️ Already at limit, discarding exported video")
                    try? FileManager.default.removeItem(at: tempURL)
                    return
                }
                
                print("📷 [Photos] Importing video to library...")
                self.libraryManager.importVideo(from: tempURL)
                
                // 영상이 없으면 자동 재생 시작
                if self.playbackController.currentVideo == nil {
                    DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                        if let firstVideo = self.libraryManager.videos.first {
                            self.playbackController.play(video: firstVideo)
                        }
                    }
                }
                
                // 임시 파일은 import 후 정리됨 (복사되므로)
            }
        }
    }
    
    private var lastDetectedVideoSrc: String = ""
    
    private func startKeepAliveTimer() {
        streamingKeepAliveTimer?.invalidate()
        
        // 5초마다 비디오 체크 - 이벤트가 놓쳐도 폴링으로 잡기
        streamingKeepAliveTimer = Timer.scheduledTimer(withTimeInterval: 5.0, repeats: true) { [weak self] _ in
            self?.checkAndCaptureVideo()
        }
        
        print("📡 [Streaming] Keep-alive timer started (5s interval)")
    }
    
    private func checkAndCaptureVideo() {
        guard isStreamingConnected, let webView = streamingWebView else { return }
        
        // 비디오 상태 확인하고, 새 비디오면 캡처
        webView.webView.evaluateJavaScript("""
            (function() {
                const video = document.querySelector('video');
                if (!video) return JSON.stringify({ status: 'no_video' });
                
                // 일시정지되어 있으면 재생
                if (video.paused) {
                    video.play();
                }
                
                const src = video.src || video.currentSrc;
                if (!src || src.startsWith('blob:')) {
                    return JSON.stringify({ status: 'no_src' });
                }
                
                return JSON.stringify({
                    status: 'playing',
                    src: src,
                    currentTime: video.currentTime,
                    duration: video.duration
                });
            })()
        """) { [weak self] result, error in
            guard let self = self,
                  let jsonString = result as? String,
                  let data = jsonString.data(using: .utf8),
                  let info = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
                return
            }
            
            let status = info["status"] as? String ?? "unknown"
            
            if status == "no_video" {
                print("📡 [Poll] No video - reloading...")
                self.streamingWebView?.reload()
                return
            }
            
            if status == "playing", let src = info["src"] as? String {
                // 새 비디오면 저장
                if src != self.lastDetectedVideoSrc {
                    self.lastDetectedVideoSrc = src
                    print("📡 [Poll] 🎬 New video: \(src.suffix(40))")
                    
                    if let url = URL(string: src) {
                        let metadata = VideoMetadata(
                            sourceUrl: src,
                            prompt: nil,
                            author: nil,
                            midjourneyJobId: nil
                        )
                        self.handleAutoSave(url: url, metadata: metadata)
                    }
                }
            }
        }
    }
    
    private func stopStreamingConnection() {
        print("📡 [Streaming] Stopping connection...")
        
        // Keep-alive 타이머 정지
        streamingKeepAliveTimer?.invalidate()
        streamingKeepAliveTimer = nil
        
        // Photos Library 타이머 정지
        stopPhotosLibraryStreaming()
        
        // WebView 정지
        streamingWebView?.pause()
        isStreamingConnected = false
        
        print("📡 [Streaming] Connection stopped")
    }
    
    // 버퍼 모드 관련
    private var bufferVideoPath: String?
    private var lastBufferVideoId: String?
    
    private func handleAutoSave(url: URL, metadata: VideoMetadata) {
        // Video URL 형식에서 UUID 추출
        // UUID 부분을 추출해야 함
        let pathComponents = url.pathComponents
        var videoId: String
        
        if let uuidIndex = pathComponents.firstIndex(of: "video"),
           uuidIndex + 1 < pathComponents.count {
            // "video" 다음 경로가 UUID
            videoId = pathComponents[uuidIndex + 1]
        } else {
            // 다른 URL 형식이면 전체 경로 해시 사용
            videoId = String(url.path.hashValue)
        }
        
        // 자동 저장 비활성화 시 버퍼 모드
        let autoSaveEnabled = configManager.config.streaming.autoSaveEnabled
        
        if !autoSaveEnabled {
            handleBufferMode(url: url, metadata: metadata, videoId: videoId)
            return
        }
        
        // 자동 저장 활성화 - 기존 로직
        handleLibrarySave(url: url, metadata: metadata, videoId: videoId)
    }
    
    // MARK: - Buffer Mode (자동 저장 비활성화)
    
    private func handleBufferMode(url: URL, metadata: VideoMetadata, videoId: String) {
        // 같은 영상이면 무시
        if lastBufferVideoId == videoId { return }
        
        print("🎬 [Buffer] New video: \(videoId)")
        lastBufferVideoId = videoId
        
        Task {
            do {
                // 버퍼 디렉토리 생성
                let bufferDir = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
                    .appendingPathComponent("SkyloftWP")
                    .appendingPathComponent("Buffer")
                
                try FileManager.default.createDirectory(at: bufferDir, withIntermediateDirectories: true)
                
                // 이전 버퍼 파일 삭제
                if let oldPath = bufferVideoPath {
                    try? FileManager.default.removeItem(atPath: oldPath)
                }
                
                // 새 영상 다운로드 (버퍼 디렉토리에)
                let fileName = "\(videoId).mp4"
                let localPath = bufferDir.appendingPathComponent(fileName)
                
                let (data, _) = try await URLSession.shared.data(from: url)
                try data.write(to: localPath)
                
                await MainActor.run {
                    self.bufferVideoPath = localPath.path
                    print("🎬 [Buffer] ✅ Downloaded: \(fileName)")
                    
                    // 버퍼 영상을 바로 재생
                    let bufferVideo = VideoItem(
                        id: videoId,
                        sourceUrl: url.absoluteString,
                        prompt: metadata.prompt,
                        author: nil,
                        midjourneyJobId: videoId,
                        savedAt: Date(),
                        duration: nil,
                        resolution: nil,
                        fileSize: Int64(data.count),
                        localPath: localPath.path,
                        thumbnailPath: nil,
                        favorite: false,
                        playCount: 0,
                        lastPlayed: nil
                    )
                    
                    self.playVideo(bufferVideo)
                }
            } catch {
                print("🎬 [Buffer] ❌ Failed: \(error)")
            }
        }
    }
    
    // MARK: - Library Save (자동 저장 활성화)
    
    private func handleLibrarySave(url: URL, metadata: VideoMetadata, videoId: String) {
        let maxCount = configManager.config.streaming.autoSaveCount
        let urlString = url.absoluteString
        
        // 이미 처리한 URL인지 먼저 체크 (영구적)
        if recentlyProcessedUrls.contains(urlString) {
            print("📥 [Save] ⏭️ Skip - already processed this URL")
            return
        }
        
        print("📥 [Save] Video detected: \(videoId.prefix(8))...")
        
        // URL 기준으로 중복 체크
        var shouldSave = false
        autoSaveQueue.sync {
            if currentlySavingIds.contains(videoId) || currentlySavingIds.contains(urlString) {
                print("📥 [Save] ⏭️ Skip - already saving")
                return
            }
            currentlySavingIds.insert(videoId)
            currentlySavingIds.insert(urlString)
            shouldSave = true
        }
        
        guard shouldSave else { return }
        
        // URL을 영구적으로 기억 (같은 세션 내에서)
        recentlyProcessedUrls.insert(urlString)
        
        // 비동기로 저장
        Task {
            defer {
                autoSaveQueue.sync {
                    currentlySavingIds.remove(videoId)
                    currentlySavingIds.remove(urlString)
                }
            }
            
            // 폴더의 실제 파일 수 확인 및 정리
            let videosDir = libraryManager.videosDirectory
            var actualFiles = (try? FileManager.default.contentsOfDirectory(at: videosDir, includingPropertiesForKeys: [.creationDateKey]))?.filter {
                let ext = $0.pathExtension.lowercased()
                return ext == "mp4" || ext == "mov" || ext == "m4v"
            } ?? []
            
            // maxCount 이상이면 오래된 것 삭제 (스킵하지 않고 계속 진행!)
            if actualFiles.count >= maxCount {
                print("📥 [Save] 🗑️ At limit (\(actualFiles.count)/\(maxCount)) - deleting oldest")
                
                // 오래된 순으로 정렬
                let sorted = actualFiles.sorted {
                    let date1 = (try? $0.resourceValues(forKeys: [.creationDateKey]))?.creationDate ?? Date.distantPast
                    let date2 = (try? $1.resourceValues(forKeys: [.creationDateKey]))?.creationDate ?? Date.distantPast
                    return date1 < date2
                }
                
                // 가장 오래된 것 삭제
                if let oldest = sorted.first {
                    print("📥 [Save] 🗑️ Deleting: \(oldest.lastPathComponent)")
                    try? FileManager.default.removeItem(at: oldest)
                }
            }
            
            // DB에 이미 있는지 체크 (URL 기준)
            let existingVideos = await MainActor.run { libraryDatabase.fetchAll() }
            let alreadyExists = existingVideos.contains { video in
                // URL 전체 또는 videoId로 체크
                if let sourceUrl = video.sourceUrl {
                    return sourceUrl == urlString || sourceUrl.contains(videoId) || urlString.contains(video.fileName.replacingOccurrences(of: ".mp4", with: "").replacingOccurrences(of: ".mov", with: ""))
                }
                return false
            }
            
            if alreadyExists {
                print("📥 [Save] ⏭️ Skip - already in library")
                return
            }
            
            // 다운로드
            do {
                print("📥 [Save] ⬇️ Downloading...")
                _ = try await DownloadManager.shared.downloadVideo(from: url, metadata: metadata)
                
                await MainActor.run {
                    // 폴더 동기화
                    libraryManager.syncFromFolder()
                    
                    let finalCount = libraryManager.videos.count
                    print("📥 [Save] ✅ Saved! Library now: \(finalCount)/\(maxCount)")
                    
                    if playbackController.currentVideo == nil {
                        playbackController.playFirst()
                    }
                }
            } catch {
                print("📥 [Save] ❌ Failed: \(error)")
            }
        }
    }
    
    /// 최대 영상 수 강제 적용 - 초과분 삭제
    private func enforceMaxVideoCount() {
        let maxCount = configManager.config.streaming.autoSaveCount
        var videos = libraryDatabase.fetchAll()
        
        if videos.count > maxCount {
            print("🔄 [Enforce] \(videos.count) > \(maxCount), deleting excess...")
            videos.sort { $0.savedAt < $1.savedAt }
            
            let deleteCount = videos.count - maxCount
            for i in 0..<deleteCount {
                deleteVideo(videos[i])
            }
            libraryManager.loadLibrary()
        }
    }
    
    private func deleteVideo(_ video: VideoItem) {
        _ = libraryDatabase.delete(id: video.id)
        try? FileManager.default.removeItem(atPath: video.localPath)
        if let thumbnailPath = video.thumbnailPath {
            try? FileManager.default.removeItem(atPath: thumbnailPath)
        }
    }
    
    /// 수동으로 현재 스트리밍 영상 저장
    @MainActor
    func saveCurrentVideo() async {
        guard let webView = streamingWebView, let videoURL = webView.currentVideoURL else {
            showNotification(title: L("notification.saveFailed"), message: L("notification.noVideoURL"))
            return
        }
        
        let metadata = webView.currentMetadata ?? VideoMetadata(
            sourceUrl: videoURL.absoluteString,
            prompt: "Streaming Video",
            author: nil,
            midjourneyJobId: nil
        )
        
        do {
            let video = try await DownloadManager.shared.downloadVideo(from: videoURL, metadata: metadata)
            showNotification(title: L("notification.saved"), message: video.prompt ?? video.fileName)
            NotificationCenter.default.post(name: .videoDidSave, object: video)
        } catch {
            showNotification(title: L("notification.saveFailed"), message: error.localizedDescription)
        }
    }
    
    /// Downloads 폴더에 현재 영상 저장
    @MainActor
    func saveCurrentVideoToDownloads() async {
        guard let webView = streamingWebView, let videoURL = webView.currentVideoURL else {
            showNotification(title: L("notification.saveFailed"), message: L("notification.noVideoURL"))
            return
        }
        
        do {
            // Downloads 폴더 경로
            let downloadsURL = FileManager.default.urls(for: .downloadsDirectory, in: .userDomainMask).first!
            
            // 파일명 생성
            let fileName = videoURL.lastPathComponent.isEmpty ? "MidTV_\(Date().timeIntervalSince1970).mp4" : videoURL.lastPathComponent
            let destinationURL = downloadsURL.appendingPathComponent(fileName)
            
            // 다운로드
            let (tempURL, _) = try await URLSession.shared.download(from: videoURL)
            
            // 이미 존재하면 삭제
            if FileManager.default.fileExists(atPath: destinationURL.path) {
                try FileManager.default.removeItem(at: destinationURL)
            }
            
            // 이동
            try FileManager.default.moveItem(at: tempURL, to: destinationURL)
            
            showNotification(title: L("notification.saved"), message: "Downloads/\(fileName)")
        } catch {
            showNotification(title: L("notification.saveFailed"), message: error.localizedDescription)
        }
    }
    
    func copyCurrentPrompt() {
        streamingWebView?.copyPromptToClipboard()
    }
    
    /// Copy prompt from specific display (for hotkeys)
    func copyCurrentPrompt(from displayID: CGDirectDisplayID) {
        streamingWebView?.copyPromptToClipboard()
    }
    
    /// Save video from specific display (for hotkeys)
    @MainActor
    func saveCurrentVideo(from displayID: CGDirectDisplayID) async {
        await saveCurrentVideo()
    }
    
    /// Toggle play/pause on specific display
    func togglePlayPause(on displayID: CGDirectDisplayID) {
        if let videoView = videoViews[displayID] {
            videoView.togglePlayPause()
        } else {
            togglePlayPause()
        }
        isPaused.toggle()
    }
    
    /// Next video on specific display
    func nextVideo(on displayID: CGDirectDisplayID) {
        playbackController.next()
    }
    
    /// Previous video on specific display
    func previousVideo(on displayID: CGDirectDisplayID) {
        playbackController.previous()
    }
    
    func applyOverlaySettings() {
        let overlay = configManager.config.overlay
        
        for (_, videoView) in videoViews {
            videoView.applyOverlaySettings(overlay)
        }
    }
    
    // MARK: - Private Methods
    
    private func createWallpaperWindows() {
        // Clean up existing windows safely
        for (_, window) in wallpaperWindows {
            window.prepareForClose()
        }
        wallpaperWindows.removeAll()
        videoViews.removeAll()
        
        // Create windows for each enabled monitor
        for monitor in monitorManager.monitors {
            guard isMonitorEnabled(monitor) else { continue }
            
            guard let screen = monitorManager.screen(for: monitor) else { continue }
            
            let window = WallpaperWindow(screen: screen)
            wallpaperWindows[monitor.id] = window
            
            // Create video view (재생은 항상 로컬 비디오)
            let videoView = VideoWallpaperView(frame: window.contentView!.bounds)
            videoView.autoresizingMask = [.width, .height]
            window.contentView?.addSubview(videoView)
            videoViews[monitor.id] = videoView
        }
    }
    
    // 모니터별 현재 재생 중인 영상 인덱스
    private var monitorVideoIndices: [CGDirectDisplayID: Int] = [:]
    private var currentlyPlayingVideoId: String = ""  // 현재 재생 중인 영상 ID
    
    private func playVideo(_ video: VideoItem) {
        // videoViews가 없으면 생성
        if videoViews.isEmpty {
            print("⚠️ No video views, creating wallpaper windows...")
            createWallpaperWindows()
        }
        
        guard !videoViews.isEmpty else {
            print("❌ Failed to create video views")
            return
        }
        
        // 같은 영상이면 재생하지 않음
        guard video.id != currentlyPlayingVideoId else {
            print("⏭️ Skip: already playing \(video.fileName)")
            return
        }
        
        currentlyPlayingVideoId = video.id
        print("▶️ Playing: \(video.fileName)")
        // 단일 모니터: 모든 모니터에 같은 영상
        // 다중 모니터: 각 모니터에 다른 영상
        let videos = libraryManager.videos
        let monitorIds = Array(videoViews.keys)
        
        if monitorIds.count <= 1 || videos.count <= 1 {
            // 단일 모니터 또는 영상이 1개일 때: 모든 모니터에 같은 영상
            // 첫 번째 모니터만 콜백 설정 (중복 호출 방지)
            var isFirstMonitor = true
            for (_, videoView) in videoViews {
                videoView.loadVideo(video)
                if isFirstMonitor {
                    videoView.onPlaybackFinished = { [weak self] in
                        self?.handleVideoFinished()
                    }
                    isFirstMonitor = false
                } else {
                    videoView.onPlaybackFinished = nil  // 나머지는 콜백 없음
                }
                videoView.play()
            }
        } else {
            // 다중 모니터: 각 모니터에 다른 영상 배정
            for (index, monitorId) in monitorIds.enumerated() {
                guard let videoView = videoViews[monitorId] else { continue }
                
                // 각 모니터에 오프셋된 영상 인덱스 할당
                let videoIndex = (playbackController.currentIndex + index) % videos.count
                monitorVideoIndices[monitorId] = videoIndex
                
                let monitorVideo = videos[videoIndex]
                videoView.loadVideo(monitorVideo)
                videoView.onPlaybackFinished = { [weak self] in
                    self?.handleVideoFinishedOnMonitor(monitorId)
                }
                videoView.play()
                
                print("🖥️ Monitor \(index): Playing \(monitorVideo.fileName)")
            }
        }
        
        // 오버레이 설정 적용
        applyOverlaySettings()
    }
    
    private func handleVideoFinished() {
        let videos = libraryManager.videos
        guard !videos.isEmpty else { return }
        
        // 현재 재생 중인 영상의 ID로 다음 영상 찾기 (인덱스가 아닌 ID 기반)
        let currentId = currentlyPlayingVideoId
        
        // 현재 영상의 위치 찾기
        let currentIdx = videos.firstIndex { $0.id == currentId } ?? -1
        
        // 다음 영상 인덱스 계산
        var nextIdx = currentIdx + 1
        if nextIdx >= videos.count || currentIdx < 0 {
            nextIdx = 0  // 처음으로 돌아감
        }
        
        let nextVideo = videos[nextIdx]
        print("➡️ Next: \(nextVideo.fileName) (\(nextIdx + 1)/\(videos.count))")
        
        // 상태 업데이트
        currentlyPlayingVideoId = ""
        playbackController.currentIndex = nextIdx
        playbackController.currentVideo = nextVideo
        
        // 재생
        playVideo(nextVideo)
    }
    
    private func handleVideoFinishedOnMonitor(_ monitorId: CGDirectDisplayID) {
        let videos = libraryManager.videos
        guard !videos.isEmpty, let videoView = videoViews[monitorId] else {
            handleVideoFinished()
            return
        }
        
        // 해당 모니터의 다음 영상으로
        let currentIndex = monitorVideoIndices[monitorId] ?? 0
        let nextIndex = (currentIndex + 1) % videos.count
        monitorVideoIndices[monitorId] = nextIndex
        
        let nextVideo = videos[nextIndex]
        videoView.loadVideo(nextVideo)
        videoView.play()
        
        print("🖥️ Monitor \(monitorId): Next video \(nextVideo.fileName)")
    }
    
    private func isMonitorEnabled(_ monitor: Monitor) -> Bool {
        let monitorConfig = configManager.config.monitors.first { $0.id == String(monitor.id) }
        return monitorConfig?.enabled ?? true
    }
    
    private func handleConfigChange(_ config: AppConfiguration) {
        // Update mute state
        for (_, videoView) in videoViews {
            videoView.isMuted = config.behavior.muteAudio
        }
        
        // Handle streaming connection change
        if config.streaming.connectionEnabled && !isStreamingConnected {
            startStreamingConnection()
        } else if !config.streaming.connectionEnabled && isStreamingConnected {
            stopStreamingConnection()
        }
    }
    
    /// Handle display configuration changes safely
    func handleDisplayChange() {
        // Must be called on main thread
        guard Thread.isMainThread else {
            DispatchQueue.main.async { [weak self] in
                self?.handleDisplayChange()
            }
            return
        }
        
        print("🖥️ [Display] Configuration changed, recreating windows...")
        
        // Save current playback state
        let wasPlaying = isPlaying
        let currentVideo = playbackController.currentVideo
        
        // Stop all video playback first and clear callbacks
        for (_, videoView) in videoViews {
            videoView.onPlaybackFinished = nil  // Clear callback first
            videoView.pause()
        }
        
        // Safely prepare windows for closing
        let windowsToClose = Array(wallpaperWindows.values)
        wallpaperWindows.removeAll()
        videoViews.removeAll()
        
        // Clean up windows safely
        for window in windowsToClose {
            window.prepareForClose()
        }
        
        // Recreate windows after displays are ready
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) { [weak self] in
            guard let self = self, wasPlaying else { return }
            
            self.createWallpaperWindows()
            
            if let video = currentVideo {
                self.currentlyPlayingVideoId = ""
                self.playVideo(video)
            }
            
            print("🖥️ [Display] ✅ Windows recreated")
        }
    }
    
    @objc private func handleVideoSaved(_ notification: Notification) {
        // 새 영상이 저장되면 플레이리스트 갱신
        libraryManager.loadLibrary()
    }
    
    private func showNotification(title: String, message: String) {
        let center = UNUserNotificationCenter.current()
        
        let content = UNMutableNotificationContent()
        content.title = title
        content.body = message
        content.sound = .default
        
        let request = UNNotificationRequest(identifier: UUID().uuidString, content: content, trigger: nil)
        center.add(request)
    }
}

