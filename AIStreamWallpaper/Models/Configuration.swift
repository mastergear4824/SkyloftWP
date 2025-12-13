//
//  Configuration.swift
//  AIStreamWallpaper
//
//  Application configuration model
//

import Foundation

// MARK: - Main Configuration

struct AppConfiguration: Codable {
    var streaming: StreamingConfiguration  // 스트리밍 연결 설정
    var library: LibraryConfiguration      // 라이브러리 설정 (재생은 항상 여기서)
    var monitors: [MonitorConfiguration]
    var schedule: ScheduleConfiguration
    var behavior: BehaviorConfiguration
    var shortcuts: ShortcutConfiguration
    var overlay: OverlayConfiguration
    
    static var `default`: AppConfiguration {
        AppConfiguration(
            streaming: .default,
            library: .default,
            monitors: [],
            schedule: .default,
            behavior: .default,
            shortcuts: .default,
            overlay: .default
        )
    }
    
    // 이전 버전 호환성을 위한 커스텀 디코더
    // playbackMode와 caching 필드는 무시
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        streaming = try container.decodeIfPresent(StreamingConfiguration.self, forKey: .streaming) ?? .default
        library = try container.decodeIfPresent(LibraryConfiguration.self, forKey: .library) ?? .default
        monitors = try container.decodeIfPresent([MonitorConfiguration].self, forKey: .monitors) ?? []
        schedule = try container.decodeIfPresent(ScheduleConfiguration.self, forKey: .schedule) ?? .default
        behavior = try container.decodeIfPresent(BehaviorConfiguration.self, forKey: .behavior) ?? .default
        shortcuts = try container.decodeIfPresent(ShortcutConfiguration.self, forKey: .shortcuts) ?? .default
        overlay = try container.decodeIfPresent(OverlayConfiguration.self, forKey: .overlay) ?? .default
    }
    
    init(streaming: StreamingConfiguration, library: LibraryConfiguration, monitors: [MonitorConfiguration],
         schedule: ScheduleConfiguration, behavior: BehaviorConfiguration,
         shortcuts: ShortcutConfiguration, overlay: OverlayConfiguration) {
        self.streaming = streaming
        self.library = library
        self.monitors = monitors
        self.schedule = schedule
        self.behavior = behavior
        self.shortcuts = shortcuts
        self.overlay = overlay
    }
    
    private enum CodingKeys: String, CodingKey {
        case streaming, library, monitors, schedule, behavior, shortcuts, overlay
        // playbackMode와 caching은 의도적으로 제외 (이전 버전 호환)
    }
}

// MARK: - Playback Mode (Legacy - 재생은 항상 라이브러리에서)
// PlaybackMode는 더 이상 사용하지 않음. 재생은 항상 라이브러리 기준.

// MARK: - Video Source

struct VideoSource: Codable, Identifiable, Equatable, Hashable {
    var id: String
    var name: String
    var url: String
    var isBuiltIn: Bool
    
    static let midjourneyTV = VideoSource(
        id: "midjourney-tv",
        name: "Midjourney TV",
        url: "https://www.midjourney.tv/",
        isBuiltIn: true
    )
}

// MARK: - Streaming Configuration

struct StreamingConfiguration: Codable {
    var selectedSourceId: String
    var sources: [VideoSource]
    var connectionEnabled: Bool    // 스트리밍 연결 ON/OFF
    var autoSaveEnabled: Bool      // 자동 저장 활성화 (false면 버퍼 모드)
    var autoSaveCount: Int         // 라이브러리에 자동 저장할 최신 영상 개수
    
    static var `default`: StreamingConfiguration {
        StreamingConfiguration(
            selectedSourceId: VideoSource.midjourneyTV.id,
            sources: [VideoSource.midjourneyTV],
            connectionEnabled: true,   // 기본: 스트리밍 연결 활성화
            autoSaveEnabled: false,    // 기본: Buffer Mode (자동 저장 비활성화) - ToS 준수 권장
            autoSaveCount: 10          // 자동 저장 활성화 시 최신 10개 저장
        )
    }
    
    // 이전 버전 호환성을 위한 커스텀 디코더
    // 주의: 기존 사용자의 설정은 유지됨 (저장된 값 사용)
    // 새 사용자만 기본값 false(Buffer Mode) 적용
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        selectedSourceId = try container.decodeIfPresent(String.self, forKey: .selectedSourceId) ?? VideoSource.midjourneyTV.id
        sources = try container.decodeIfPresent([VideoSource].self, forKey: .sources) ?? [VideoSource.midjourneyTV]
        connectionEnabled = try container.decodeIfPresent(Bool.self, forKey: .connectionEnabled) ?? true
        autoSaveEnabled = try container.decodeIfPresent(Bool.self, forKey: .autoSaveEnabled) ?? false  // 기본: Buffer Mode
        autoSaveCount = try container.decodeIfPresent(Int.self, forKey: .autoSaveCount) ?? 10
    }
    
    init(selectedSourceId: String, sources: [VideoSource], connectionEnabled: Bool, autoSaveEnabled: Bool, autoSaveCount: Int) {
        self.selectedSourceId = selectedSourceId
        self.sources = sources
        self.connectionEnabled = connectionEnabled
        self.autoSaveEnabled = autoSaveEnabled
        self.autoSaveCount = autoSaveCount
    }
    
    private enum CodingKeys: String, CodingKey {
        case selectedSourceId, sources, connectionEnabled, autoSaveEnabled, autoSaveCount
    }
    
    var selectedSource: VideoSource {
        sources.first { $0.id == selectedSourceId } ?? VideoSource.midjourneyTV
    }
    
    var url: String {
        selectedSource.url
    }
}

// MARK: - Overlay Configuration

struct OverlayConfiguration: Codable, Equatable {
    var opacity: Double        // 0.0 ~ 1.0
    var brightness: Double     // -1.0 ~ 1.0 (0 = normal)
    var saturation: Double     // 0.0 ~ 2.0 (1 = normal)
    var blur: Double           // 0.0 ~ 50.0
    
    static var `default`: OverlayConfiguration {
        OverlayConfiguration(
            opacity: 1.0,
            brightness: 0.0,
            saturation: 1.0,
            blur: 0.0
        )
    }
}

// CachingConfiguration 삭제됨 - 캐시는 라이브러리로 통합됨

// MARK: - Library Configuration

struct LibraryConfiguration: Codable, Equatable {
    var path: String
    var currentVideoId: String?
    var autoAdvanceSeconds: Int
    
    static var `default`: LibraryConfiguration {
        let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        let libraryPath = appSupport.appendingPathComponent("AIStreamWallpaper").path
        
        return LibraryConfiguration(
            path: libraryPath,
            currentVideoId: nil,
            autoAdvanceSeconds: 0
        )
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        path = try container.decodeIfPresent(String.self, forKey: .path) ?? Self.default.path
        currentVideoId = try container.decodeIfPresent(String.self, forKey: .currentVideoId)
        autoAdvanceSeconds = try container.decodeIfPresent(Int.self, forKey: .autoAdvanceSeconds) ?? 0
    }
    
    init(path: String, currentVideoId: String?, autoAdvanceSeconds: Int) {
        self.path = path
        self.currentVideoId = currentVideoId
        self.autoAdvanceSeconds = autoAdvanceSeconds
    }
}

// MARK: - Monitor Configuration

struct MonitorConfiguration: Codable, Identifiable {
    var id: String
    var enabled: Bool
    var sourceOverride: String?
    
    init(id: String, enabled: Bool = true, sourceOverride: String? = nil) {
        self.id = id
        self.enabled = enabled
        self.sourceOverride = sourceOverride
    }
}

// MARK: - Schedule Configuration

struct ScheduleConfiguration: Codable {
    var enabled: Bool
    var startTime: String
    var endTime: String
    var pauseOnBattery: Bool
    var pauseOnFullscreen: Bool
    
    static var `default`: ScheduleConfiguration {
        ScheduleConfiguration(
            enabled: false,
            startTime: "09:00",
            endTime: "18:00",
            pauseOnBattery: true,
            pauseOnFullscreen: true
        )
    }
    
    // Legacy support
    var activeHours: ActiveHours {
        get { ActiveHours(start: startTime, end: endTime) }
        set {
            startTime = newValue.start
            endTime = newValue.end
        }
    }
}

struct ActiveHours: Codable {
    var start: String
    var end: String
}

// MARK: - Behavior Configuration

struct BehaviorConfiguration: Codable {
    var autoStart: Bool
    var muteAudio: Bool
    var quality: VideoQuality
    var showNotificationOnSave: Bool
    
    // 표시 모드
    var useAsWallpaper: Bool      // 배경화면으로 사용
    var useAsScreensaver: Bool    // 화면보호기로 사용
    var screensaverIdleTime: Int  // 화면보호기 시작까지의 유휴 시간 (초)
    
    static var `default`: BehaviorConfiguration {
        BehaviorConfiguration(
            autoStart: true,
            muteAudio: true,
            quality: .auto,
            showNotificationOnSave: true,
            useAsWallpaper: true,
            useAsScreensaver: false,
            screensaverIdleTime: 300  // 기본 5분
        )
    }
    
    // 이전 버전 호환성
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        autoStart = try container.decodeIfPresent(Bool.self, forKey: .autoStart) ?? true
        muteAudio = try container.decodeIfPresent(Bool.self, forKey: .muteAudio) ?? true
        quality = try container.decodeIfPresent(VideoQuality.self, forKey: .quality) ?? .auto
        showNotificationOnSave = try container.decodeIfPresent(Bool.self, forKey: .showNotificationOnSave) ?? true
        useAsWallpaper = try container.decodeIfPresent(Bool.self, forKey: .useAsWallpaper) ?? true
        useAsScreensaver = try container.decodeIfPresent(Bool.self, forKey: .useAsScreensaver) ?? false
        screensaverIdleTime = try container.decodeIfPresent(Int.self, forKey: .screensaverIdleTime) ?? 300
    }
    
    init(autoStart: Bool, muteAudio: Bool, quality: VideoQuality, showNotificationOnSave: Bool,
         useAsWallpaper: Bool = true, useAsScreensaver: Bool = false, screensaverIdleTime: Int = 300) {
        self.autoStart = autoStart
        self.muteAudio = muteAudio
        self.quality = quality
        self.showNotificationOnSave = showNotificationOnSave
        self.useAsWallpaper = useAsWallpaper
        self.useAsScreensaver = useAsScreensaver
        self.screensaverIdleTime = screensaverIdleTime
    }
    
    private enum CodingKeys: String, CodingKey {
        case autoStart, muteAudio, quality, showNotificationOnSave
        case useAsWallpaper, useAsScreensaver, screensaverIdleTime
    }
}

enum VideoQuality: String, Codable, CaseIterable {
    case auto = "auto"
    case high = "high"
    case medium = "medium"
    case low = "low"
    
    var displayName: String {
        switch self {
        case .auto: return "자동"
        case .high: return "고화질"
        case .medium: return "중간"
        case .low: return "저화질"
        }
    }
}

// MARK: - Shortcut Configuration

struct ShortcutConfiguration: Codable {
    var nextVideo: String
    var prevVideo: String
    var saveVideo: String
    var toggleMute: String
    var togglePlayPause: String
    var openLibrary: String
    var copyPrompt: String
    var showControls: String
    
    static var `default`: ShortcutConfiguration {
        ShortcutConfiguration(
            nextVideo: "⌥⌘→",
            prevVideo: "⌥⌘←",
            saveVideo: "⌥⌘S",
            toggleMute: "⌥⌘M",
            togglePlayPause: "⌥⌘P",
            openLibrary: "⌥⌘L",
            copyPrompt: "⌥⌘C",
            showControls: "⌥⌘W"
        )
    }
}
