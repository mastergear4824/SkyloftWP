//
//  SkyloftScreenSaverView.swift
//  SkyloftWP Screen Saver
//
//  Plays videos from the SkyloftWP library as a screensaver
//

import ScreenSaver
import AVFoundation
import AVKit

class SkyloftScreenSaverView: ScreenSaverView {
    
    // MARK: - Properties
    
    private var playerView: AVPlayerView?
    private var player: AVPlayer?
    private var playerLooper: AVPlayerLooper?
    private var queuePlayer: AVQueuePlayer?
    
    private var videoURLs: [URL] = []
    private var currentIndex = 0
    private var isConfigured = false
    
    // MARK: - Initialization
    
    override init?(frame: NSRect, isPreview: Bool) {
        super.init(frame: frame, isPreview: isPreview)
        initialize()
    }
    
    required init?(coder: NSCoder) {
        super.init(coder: coder)
        initialize()
    }
    
    private func initialize() {
        // 배경색 설정
        wantsLayer = true
        layer?.backgroundColor = NSColor.black.cgColor
        
        // 애니메이션 간격 (0 = 시스템이 알아서)
        animationTimeInterval = 1.0 / 30.0
        
        // 비디오 플레이어 뷰 설정
        setupPlayerView()
        
        // 비디오 목록 로드
        loadVideoList()
    }
    
    private func setupPlayerView() {
        playerView = AVPlayerView(frame: bounds)
        playerView?.autoresizingMask = [.width, .height]
        playerView?.controlsStyle = .none
        playerView?.videoGravity = .resizeAspectFill
        
        if let playerView = playerView {
            addSubview(playerView)
        }
    }
    
    // MARK: - Video Management
    
    private func loadVideoList() {
        // SkyloftWP 라이브러리 경로
        let libraryPath = getLibraryPath()
        
        guard FileManager.default.fileExists(atPath: libraryPath) else {
            print("📺 [ScreenSaver] Library path not found: \(libraryPath)")
            return
        }
        
        do {
            let files = try FileManager.default.contentsOfDirectory(atPath: libraryPath)
            videoURLs = files
                .filter { $0.hasSuffix(".mp4") || $0.hasSuffix(".mov") || $0.hasSuffix(".m4v") }
                .map { URL(fileURLWithPath: libraryPath).appendingPathComponent($0) }
            
            print("📺 [ScreenSaver] Found \(videoURLs.count) videos")
            
            // 무작위 섞기
            videoURLs.shuffle()
            
        } catch {
            print("📺 [ScreenSaver] Error loading videos: \(error)")
        }
    }
    
    private func getLibraryPath() -> String {
        // 공유 Application Support 경로
        let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        let path = appSupport.appendingPathComponent("SkyloftWP/videos").path
        print("📺 [ScreenSaver] Library path: \(path)")
        return path
    }
    
    private func playNextVideo() {
        guard !videoURLs.isEmpty else {
            print("📺 [ScreenSaver] No videos to play")
            return
        }
        
        // 다음 비디오로 이동
        currentIndex = (currentIndex + 1) % videoURLs.count
        let videoURL = videoURLs[currentIndex]
        
        print("📺 [ScreenSaver] Playing: \(videoURL.lastPathComponent)")
        
        // 기존 플레이어 정리
        player?.pause()
        NotificationCenter.default.removeObserver(self, name: .AVPlayerItemDidPlayToEndTime, object: nil)
        
        // 새 플레이어 생성
        let playerItem = AVPlayerItem(url: videoURL)
        player = AVPlayer(playerItem: playerItem)
        player?.isMuted = true  // 스크린세이버는 음소거
        player?.actionAtItemEnd = .none
        
        playerView?.player = player
        
        // 재생 완료 시 다음 비디오
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(playerDidFinishPlaying),
            name: .AVPlayerItemDidPlayToEndTime,
            object: playerItem
        )
        
        player?.play()
    }
    
    @objc private func playerDidFinishPlaying(_ notification: Notification) {
        DispatchQueue.main.async { [weak self] in
            self?.playNextVideo()
        }
    }
    
    // MARK: - ScreenSaverView Overrides
    
    override func startAnimation() {
        super.startAnimation()
        
        print("📺 [ScreenSaver] Starting animation")
        
        if !isConfigured {
            isConfigured = true
            // 첫 비디오 재생
            if !videoURLs.isEmpty {
                currentIndex = -1  // playNextVideo에서 0으로 증가
                playNextVideo()
            }
        } else {
            // 재개
            player?.play()
        }
    }
    
    override func stopAnimation() {
        super.stopAnimation()
        
        print("📺 [ScreenSaver] Stopping animation")
        player?.pause()
    }
    
    override func animateOneFrame() {
        // AVPlayer가 자체적으로 렌더링하므로 여기서 할 일 없음
    }
    
    override func draw(_ rect: NSRect) {
        // 배경을 검은색으로
        NSColor.black.setFill()
        rect.fill()
    }
    
    override var hasConfigureSheet: Bool {
        return false  // 설정 시트 없음 (앱에서 설정)
    }
    
    override var configureSheet: NSWindow? {
        return nil
    }
    
    // MARK: - Cleanup
    
    deinit {
        NotificationCenter.default.removeObserver(self)
        player?.pause()
        player = nil
    }
}
