//
//  WallpaperManager.swift
//  AIStreamWallpaper
//
//  Manages wallpaper windows across all monitors
//  새 구조: 재생은 항상 라이브러리에서, 스트리밍은 자동 저장만 담당
//

import AppKit
import Combine
import UserNotifications

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
        playbackController.$currentVideo
            .removeDuplicates { $0?.id == $1?.id }
            .debounce(for: .milliseconds(100), scheduler: DispatchQueue.main)
            .sink { [weak self] video in
                guard let self = self, let video = video else { return }
                self.playVideo(video)
            }
            .store(in: &cancellables)
        
        // Observe monitor changes
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleDisplayChange),
            name: NSApplication.didChangeScreenParametersNotification,
            object: nil
        )
        
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
        
        // 라이브러리에서 첫 번째 영상 재생
        if let video = playbackController.currentVideo {
            playVideo(video)
        } else {
            playbackController.playFirst()
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
    
    private func startStreamingConnection() {
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
        print("📡 [Streaming] Loading Midjourney TV...")
        streamingWebView?.loadMidjourneyTV()
        isStreamingConnected = true
        
        // Keep-alive 타이머 시작: 비디오가 계속 재생되도록 보장
        startKeepAliveTimer()
        
        print("📡 [Streaming] ✅ Connection started - will stay connected continuously")
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
        
        // WebView 정지
        streamingWebView?.pause()
        isStreamingConnected = false
        
        print("📡 [Streaming] Connection stopped")
    }
    
    // 버퍼 모드 관련
    private var bufferVideoPath: String?
    private var lastBufferVideoId: String?
    
    private func handleAutoSave(url: URL, metadata: VideoMetadata) {
        // Midjourney TV URL 형식: https://cdn.midjourney.com/video/{UUID}/0.mp4?...
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
                    .appendingPathComponent("AIStreamWallpaper")
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
        
        print("📥 [Save] Video detected: \(videoId.prefix(8))...")
        
        // 현재 저장 중인지 체크
        var shouldSave = false
        autoSaveQueue.sync {
            if currentlySavingIds.contains(videoId) {
                print("📥 [Save] ⏭️ Skip - already saving")
                return
            }
            currentlySavingIds.insert(videoId)
            shouldSave = true
        }
        
        guard shouldSave else { return }
        
        // 비동기로 저장
        Task {
            defer {
                autoSaveQueue.sync {
                    currentlySavingIds.remove(videoId)
                }
            }
            
            // 라이브러리에 이미 있는지 체크 (DB 직접 조회)
            let existingVideos = await MainActor.run { libraryDatabase.fetchAll() }
            let alreadyExists = existingVideos.contains { video in
                if let sourceUrl = video.sourceUrl {
                    return sourceUrl.contains(videoId)
                }
                return false
            }
            
            if alreadyExists {
                print("📥 [Save] ⏭️ Skip - already in library (\(existingVideos.count) videos)")
                return
            }
            
            // 최대 개수 도달 시 가장 오래된 것 삭제 (저장 전)
            await MainActor.run {
                let currentVideos = libraryDatabase.fetchAll()
                print("📥 [Save] Library: \(currentVideos.count)/\(maxCount)")
                
                if currentVideos.count >= maxCount {
                    // 오래된 순으로 정렬
                    let sorted = currentVideos.sorted { $0.savedAt < $1.savedAt }
                    let deleteCount = currentVideos.count - maxCount + 1  // +1 for new video
                    
                    for i in 0..<deleteCount {
                        print("📥 [Save] 🗑️ Deleting oldest: \(sorted[i].fileName)")
                        deleteVideo(sorted[i])
                    }
                }
            }
            
            // 다운로드
            do {
                print("📥 [Save] ⬇️ Downloading...")
                let video = try await DownloadManager.shared.downloadVideo(from: url, metadata: metadata)
                
                await MainActor.run {
                    print("📥 [Save] ✅ Saved: \(video.fileName)")
                    libraryManager.loadLibrary()
                    
                    let finalCount = libraryDatabase.fetchAll().count
                    print("📥 [Save] Library now: \(finalCount)/\(maxCount)")
                    
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
            prompt: "Midjourney TV Video",
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
        // Clean up existing windows
        wallpaperWindows.values.forEach { $0.close() }
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
    
    @objc private func handleDisplayChange() {
        if isPlaying {
            createWallpaperWindows()
            if let video = playbackController.currentVideo {
                playVideo(video)
            }
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
