//
//  VideoWallpaperView.swift
//  SkyloftWP
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
        // Must cleanup on deinit to prevent crashes
        NotificationCenter.default.removeObserver(self)
        cancellables.removeAll()
        
        // ⚠️ 중요: NotificationCenter observer 제거 (소리 섞임 방지)
        NotificationCenter.default.removeObserver(self, name: .AVPlayerItemDidPlayToEndTime, object: nil)
        
        if let observer = timeObserver {
            player?.removeTimeObserver(observer)
            timeObserver = nil
        }
        
        onPlaybackFinished = nil
        onPlaybackProgress = nil
        
        player?.pause()
        player?.replaceCurrentItem(with: nil)  // 현재 아이템도 제거
        playerLayer?.player = nil
        player = nil
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
    private var currentBlurRadius: Double = 0
    private var currentSaturation: Double = 1.0
    
    func applyOverlaySettings(_ overlay: OverlayConfiguration) {
        playerLayer.opacity = Float(overlay.opacity)
        
        // Brightness (dark overlay)
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
        
        // Blur and Saturation (combined filter)
        applyFilters(blur: overlay.blur, saturation: overlay.saturation)
    }
    
    private func applyFilters(blur: Double, saturation: Double) {
        // 값이 변경되지 않았으면 스킵
        guard blur != currentBlurRadius || saturation != currentSaturation else { return }
        
        currentBlurRadius = blur
        currentSaturation = saturation
        
        var filters: [CIFilter] = []
        
        // Gaussian Blur 필터
        if blur > 1 {
            if let blurFilter = CIFilter(name: "CIGaussianBlur") {
                blurFilter.setValue(blur, forKey: kCIInputRadiusKey)
                filters.append(blurFilter)
            }
        }
        
        // Saturation 필터
        if saturation != 1.0 {
            if let colorFilter = CIFilter(name: "CIColorControls") {
                colorFilter.setValue(saturation, forKey: kCIInputSaturationKey)
                filters.append(colorFilter)
            }
        }
        
        // 필터 적용
        if filters.isEmpty {
            playerLayer.filters = nil
        } else {
            playerLayer.filters = filters
        }
    }
    
    // MARK: - Layout
    
    override func layout() {
        super.layout()
        playerLayer.frame = bounds
    }
    
    // MARK: - Crossfade Duration
    
    private let crossfadeDuration: Double = 0.8
    
    // MARK: - Public Methods
    
    func loadVideo(_ video: VideoItem, withCrossfade: Bool = false) {
        let url = video.localURL
        guard FileManager.default.fileExists(atPath: url.path) else {
            print("Video not found: \(url.path)")
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [weak self] in
                self?.onPlaybackFinished?()
            }
            return
        }
        
        if withCrossfade && player != nil {
            // 기존 영상이 있으면 크로스페이드
            crossfadeToVideo(url: url)
        } else {
            // 처음 로드 시 즉시 로드
            loadVideoImmediately(url: url)
        }
    }
    
    private func loadVideoImmediately(url: URL) {
        // 이전 플레이어 정리
        cleanup()
        
        // 새 플레이어 생성 (CPU 최적화 설정 포함)
        let asset = AVURLAsset(url: url)
        let item = AVPlayerItem(asset: asset)
        
        // 🔋 CPU/메모리 최적화: 버퍼 크기 제한 (5초)
        item.preferredForwardBufferDuration = 5
        
        player = AVPlayer(playerItem: item)
        player?.isMuted = isMuted
        
        // ⚠️ 중요: 스크린세이버와 잠금 화면 진입을 방해하지 않도록 설정
        player?.preventsDisplaySleepDuringVideoPlayback = false
        
        // 🔋 CPU 최적화: 자동 대기 비활성화
        player?.automaticallyWaitsToMinimizeStalling = false
        
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
    
    private func crossfadeToVideo(url: URL) {
        // 새 플레이어 레이어 생성
        let newPlayerLayer = AVPlayerLayer()
        newPlayerLayer.frame = bounds
        newPlayerLayer.videoGravity = .resizeAspectFill
        newPlayerLayer.backgroundColor = CGColor.black
        newPlayerLayer.opacity = 0  // 처음엔 투명
        
        // 새 플레이어 생성 (CPU 최적화 설정 포함)
        let asset = AVURLAsset(url: url)
        let item = AVPlayerItem(asset: asset)
        
        // 🔋 CPU/메모리 최적화: 버퍼 크기 제한 (5초)
        item.preferredForwardBufferDuration = 5
        
        let newPlayer = AVPlayer(playerItem: item)
        newPlayer.isMuted = isMuted
        
        // ⚠️ 중요: 스크린세이버와 잠금 화면 진입을 방해하지 않도록 설정
        newPlayer.preventsDisplaySleepDuringVideoPlayback = false
        
        // 🔋 CPU 최적화: 자동 대기 비활성화
        newPlayer.automaticallyWaitsToMinimizeStalling = false
        
        newPlayerLayer.player = newPlayer
        
        // ⚠️ 중요: 기존 플레이어 즉시 음소거 (소리 섞임 방지)
        player?.isMuted = true
        
        // 새 레이어를 기존 레이어 위에 추가
        layer?.insertSublayer(newPlayerLayer, above: playerLayer)
        
        // 기존 플레이어 opacity 애니메이션과 함께 fade out
        CATransaction.begin()
        CATransaction.setAnimationDuration(crossfadeDuration)
        CATransaction.setAnimationTimingFunction(CAMediaTimingFunction(name: .easeInEaseOut))
        
        // 새 레이어 fade in
        newPlayerLayer.opacity = playerLayer.opacity
        
        CATransaction.setCompletionBlock { [weak self] in
            guard let self = self else { return }
            
            // 애니메이션 완료 후 기존 플레이어 정리
            self.cleanup()
            
            // 새 플레이어로 교체
            self.playerLayer.removeFromSuperlayer()
            self.playerLayer = newPlayerLayer
            self.player = newPlayer
            
            // 종료 알림 등록
            NotificationCenter.default.addObserver(
                self,
                selector: #selector(self.playerItemDidFinish),
                name: .AVPlayerItemDidPlayToEndTime,
                object: item
            )
        }
        
        CATransaction.commit()
        
        // 새 영상 재생 시작
        newPlayer.play()
        
        print("🔄 Crossfade to: \(url.lastPathComponent)")
    }
    
    func loadVideo(at url: URL) {
        guard FileManager.default.fileExists(atPath: url.path) else {
            print("Video not found: \(url.path)")
            return
        }
        
        cleanup()
        
        // CPU 최적화 설정 포함
        let asset = AVURLAsset(url: url)
        let item = AVPlayerItem(asset: asset)
        item.preferredForwardBufferDuration = 5
        
        player = AVPlayer(playerItem: item)
        player?.isMuted = isMuted
        player?.preventsDisplaySleepDuringVideoPlayback = false
        player?.automaticallyWaitsToMinimizeStalling = false
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
        // Remove time observer
        if let observer = timeObserver, let p = player {
            p.removeTimeObserver(observer)
        }
        timeObserver = nil
        
        // Remove notification observer
        NotificationCenter.default.removeObserver(self, name: .AVPlayerItemDidPlayToEndTime, object: nil)
        
        // Stop playback and clear player
        player?.pause()
        player?.replaceCurrentItem(with: nil)
        playerLayer?.player = nil
        player = nil
    }
}
