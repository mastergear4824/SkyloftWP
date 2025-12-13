//
//  VideoWallpaperView.swift
//  AIStreamWallpaper
//
//  AVPlayer-based wallpaper for local video playback
//

import AppKit
import AVKit
import AVFoundation
import Combine

class VideoWallpaperView: NSView {
    
    // MARK: - Properties
    
    private var playerLayer: AVPlayerLayer!
    private var player: AVPlayer?
    private var cancellables = Set<AnyCancellable>()
    private var timeObserver: Any?
    
    var isMuted: Bool = true {
        didSet { player?.isMuted = isMuted }
    }
    
    var isPlaying: Bool {
        (player?.rate ?? 0) > 0
    }
    
    var onPlaybackFinished: (() -> Void)?
    var onPlaybackProgress: ((Double, Double) -> Void)?
    
    // MARK: - Initialization
    
    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        setupPlayerLayer()
    }
    
    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setupPlayerLayer()
    }
    
    deinit {
        cleanup()
    }
    
    // MARK: - Setup
    
    private func setupPlayerLayer() {
        wantsLayer = true
        
        playerLayer = AVPlayerLayer()
        playerLayer.frame = bounds
        playerLayer.videoGravity = .resizeAspectFill
        playerLayer.backgroundColor = CGColor.black
        
        layer?.addSublayer(playerLayer)
        
        setupObservers()
    }
    
    private func setupObservers() {
        ConfigurationManager.shared.$config
            .debounce(for: .milliseconds(200), scheduler: DispatchQueue.main)
            .sink { [weak self] config in
                self?.isMuted = config.behavior.muteAudio
                self?.applyOverlaySettings(config.overlay)
            }
            .store(in: &cancellables)
    }
    
    // MARK: - Overlay Settings
    
    private var darkOverlayLayer: CALayer?
    
    func applyOverlaySettings(_ overlay: OverlayConfiguration) {
        playerLayer.opacity = Float(overlay.opacity)
        
        if overlay.brightness < 0 {
            if darkOverlayLayer == nil {
                darkOverlayLayer = CALayer()
                darkOverlayLayer?.frame = bounds
                darkOverlayLayer?.autoresizingMask = [.layerWidthSizable, .layerHeightSizable]
                layer?.addSublayer(darkOverlayLayer!)
            }
            darkOverlayLayer?.backgroundColor = NSColor.black.withAlphaComponent(-overlay.brightness * 0.8).cgColor
            darkOverlayLayer?.isHidden = false
        } else {
            darkOverlayLayer?.isHidden = true
        }
    }
    
    // MARK: - Layout
    
    override func layout() {
        super.layout()
        playerLayer.frame = bounds
    }
    
    // MARK: - Public Methods
    
    func loadVideo(_ video: VideoItem) {
        let url = video.localURL
        guard FileManager.default.fileExists(atPath: url.path) else {
            print("Video not found: \(url.path)")
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [weak self] in
                self?.onPlaybackFinished?()
            }
            return
        }
        
        // 이전 플레이어 정리
        cleanup()
        
        // 새 플레이어 생성
        let asset = AVURLAsset(url: url)
        let item = AVPlayerItem(asset: asset)
        player = AVPlayer(playerItem: item)
        player?.isMuted = isMuted
        playerLayer.player = player
        
        // 종료 알림 등록
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(playerItemDidFinish),
            name: .AVPlayerItemDidPlayToEndTime,
            object: item
        )
        
        print("▶️ Loaded: \(url.lastPathComponent)")
    }
    
    func loadVideo(at url: URL) {
        guard FileManager.default.fileExists(atPath: url.path) else {
            print("Video not found: \(url.path)")
            return
        }
        
        cleanup()
        
        let asset = AVURLAsset(url: url)
        let item = AVPlayerItem(asset: asset)
        player = AVPlayer(playerItem: item)
        player?.isMuted = isMuted
        playerLayer.player = player
        
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(playerItemDidFinish),
            name: .AVPlayerItemDidPlayToEndTime,
            object: item
        )
        
        print("▶️ Loaded: \(url.lastPathComponent)")
    }
    
    func play() {
        player?.play()
    }
    
    func pause() {
        player?.pause()
    }
    
    func togglePlayPause() {
        if isPlaying { pause() } else { play() }
    }
    
    func seek(to time: Double) {
        let cmTime = CMTime(seconds: time, preferredTimescale: 600)
        player?.seek(to: cmTime)
    }
    
    // MARK: - Private Methods
    
    @objc private func playerItemDidFinish(_ notification: Notification) {
        print("🏁 Video finished")
        onPlaybackFinished?()
    }
    
    private func cleanup() {
        if let observer = timeObserver {
            player?.removeTimeObserver(observer)
            timeObserver = nil
        }
        
        NotificationCenter.default.removeObserver(self, name: .AVPlayerItemDidPlayToEndTime, object: nil)
        
        player?.pause()
        player = nil
        playerLayer.player = nil
    }
}
