//
//  Configuration.swift
//  SkyloftWP
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
    var isBuiltIn: Bool = false  // 더 이상 빌트인 소스 없음
    var description: String?
    var fetchMode: FetchMode  // 수집 방식
    var sourceType: SourceType  // 소스 유형
    
    enum FetchMode: String, Codable, CaseIterable {
        case streaming = "streaming"  // 이벤트 기반 (영상 전환 시 감지)
        case polling = "polling"      // 폴링 방식 (주기적 수집)
        
        var displayName: String {
            switch self {
            case .streaming: return "Streaming (Event-based)"
            case .polling: return "Polling (Periodic)"
            }
        }
        
        var description: String {
            switch self {
            case .streaming: return "Detects video changes automatically (for auto-playing sites)"
            case .polling: return "Periodically scans for new videos (for static pages)"
            }
        }
    }
    
    enum SourceType: String, Codable {
        case web = "web"                    // 웹사이트 URL
        case photosLibrary = "photos"       // macOS 사진 라이브러리
        
        var displayName: String {
            switch self {
            case .web: return "Website"
            case .photosLibrary: return "Photos Library"
            }
        }
    }
    
    // 기본 생성자 (기존 호환성)
    init(id: String, name: String, url: String, isBuiltIn: Bool = false, description: String? = nil, fetchMode: FetchMode = .streaming, sourceType: SourceType = .web) {
        self.id = id
        self.name = name
        self.url = url
        self.isBuiltIn = isBuiltIn
        self.description = description
        self.fetchMode = fetchMode
        self.sourceType = sourceType
    }
    
    // 이전 버전 호환을 위한 디코더
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(String.self, forKey: .id)
        name = try container.decode(String.self, forKey: .name)
        url = try container.decode(String.self, forKey: .url)
        isBuiltIn = try container.decodeIfPresent(Bool.self, forKey: .isBuiltIn) ?? false
        description = try container.decodeIfPresent(String.self, forKey: .description)
        fetchMode = try container.decodeIfPresent(FetchMode.self, forKey: .fetchMode) ?? .streaming
        sourceType = try container.decodeIfPresent(SourceType.self, forKey: .sourceType) ?? .web
    }
    
    private enum CodingKeys: String, CodingKey {
        case id, name, url, isBuiltIn, description, fetchMode, sourceType
    }
    
    // Photos Library 소스 (빌트인)
    static let photosLibrary = VideoSource(
        id: "photos-library",
        name: "Photos Library",
        url: "photos://library",
        isBuiltIn: true,
        description: "Stream 16:9 videos from your Photos library",
        fetchMode: .polling,
        sourceType: .photosLibrary
    )
    
    // 빌트인 소스 - Photos Library만 포함
    static let allBuiltIn: [VideoSource] = [photosLibrary]
    
    // Photos Library 소스인지 확인
    var isPhotosLibrary: Bool {
        sourceType == .photosLibrary
    }
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
            selectedSourceId: "",
            sources: [],           // 사용자 추가 소스만 저장
            connectionEnabled: false,
            autoSaveEnabled: true,     // Photos Library용: 자동 저장 활성화
            autoSaveCount: 10
        )
    }
    
    // 이전 버전 호환성을 위한 커스텀 디코더
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        
        // 기존 소스 로드 후 구버전 빌트인 소스 제거 (Photos Library 제외)
        var loadedSources = try container.decodeIfPresent([VideoSource].self, forKey: .sources) ?? []
        loadedSources.removeAll { $0.isBuiltIn && $0.sourceType != .photosLibrary }
        sources = loadedSources
        
        // 선택된 소스가 유효한지 확인 (Photos Library 포함)
        let savedSourceId = try container.decodeIfPresent(String.self, forKey: .selectedSourceId) ?? ""
        let allSources = sources + [VideoSource.photosLibrary]
        if allSources.contains(where: { $0.id == savedSourceId }) {
            selectedSourceId = savedSourceId
        } else {
            selectedSourceId = ""
        }
        
        connectionEnabled = try container.decodeIfPresent(Bool.self, forKey: .connectionEnabled) ?? false
        autoSaveEnabled = try container.decodeIfPresent(Bool.self, forKey: .autoSaveEnabled) ?? true
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
        // Photos Library 확인
        if selectedSourceId == VideoSource.photosLibrary.id {
            return VideoSource.photosLibrary
        }
        // 사용자 추가 소스에서 찾기
        return sources.first { $0.id == selectedSourceId } ?? VideoSource(
            id: "placeholder",
            name: "No Source",
            url: "about:blank",
            isBuiltIn: false,
            description: nil,
            fetchMode: .streaming
        )
    }
    
    var hasValidSource: Bool {
        // Photos Library가 선택되었거나 사용자 소스가 있으면 유효
        selectedSourceId == VideoSource.photosLibrary.id || (!sources.isEmpty && sources.contains { $0.id == selectedSourceId })
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
        let libraryPath = appSupport.appendingPathComponent("SkyloftWP").path
        
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
            screensaverIdleTime: 300
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
