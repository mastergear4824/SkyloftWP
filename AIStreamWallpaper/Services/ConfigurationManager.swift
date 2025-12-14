//
//  ConfigurationManager.swift
//  AIStreamWallpaper
//
//  Configuration persistence and management
//

import Foundation
import Combine
import ServiceManagement

class ConfigurationManager: ObservableObject {
    
    // MARK: - Singleton
    
    static let shared = ConfigurationManager()
    
    // MARK: - Published Properties
    
    @Published var config: AppConfiguration
    
    // MARK: - Private Properties
    
    private let fileManager = FileManager.default
    private var configURL: URL {
        let appSupport = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        let appDirectory = appSupport.appendingPathComponent("AIStreamWallpaper")
        return appDirectory.appendingPathComponent("config.json")
    }
    
    // MARK: - Initialization
    
    private init() {
        self.config = Self.loadConfiguration() ?? .default
        ensureDirectoriesExist()
        migrateConfigurationIfNeeded()
    }
    
    // MARK: - Properties for debounced save
    
    private var saveWorkItem: DispatchWorkItem?
    
    // MARK: - Public Methods
    
    func save() {
        // Debounce saves to reduce disk I/O
        saveWorkItem?.cancel()
        saveWorkItem = DispatchWorkItem { [weak self] in
            self?.performSave()
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5, execute: saveWorkItem!)
    }
    
    func saveImmediately() {
        saveWorkItem?.cancel()
        performSave()
    }
    
    private func performSave() {
        do {
            let data = try JSONEncoder().encode(config)
            
            // Ensure directory exists
            let directory = configURL.deletingLastPathComponent()
            try fileManager.createDirectory(at: directory, withIntermediateDirectories: true)
            
            try data.write(to: configURL)
        } catch {
            print("Failed to save configuration: \(error)")
        }
    }
    
    func reset() {
        config = .default
        save()
    }
    
    func updateLibraryPath(_ path: String) {
        config.library.path = path
        save()
        ensureDirectoriesExist()
    }
    
    
    
    func toggleMute() {
        config.behavior.muteAudio.toggle()
        save()
    }
    
    func setAutoStart(_ enabled: Bool) {
        config.behavior.autoStart = enabled
        save()
        
        // Use SMAppService for modern macOS (13.0+)
        if #available(macOS 13.0, *) {
            do {
                if enabled {
                    try SMAppService.mainApp.register()
                    print("✅ Auto-start registered with SMAppService")
                } else {
                    try SMAppService.mainApp.unregister()
                    print("✅ Auto-start unregistered from SMAppService")
                }
            } catch {
                print("❌ Failed to set auto-start: \(error)")
                // Fallback to LaunchAgent if SMAppService fails
                LaunchAgentManager.shared.setEnabled(enabled)
            }
        } else {
            // Fallback for older macOS
            LaunchAgentManager.shared.setEnabled(enabled)
        }
    }
    
    func selectVideoSource(_ source: VideoSource) {
        config.streaming.selectedSourceId = source.id
        save()
    }
    
    func addVideoSource(name: String, url: String) -> VideoSource {
        let source = VideoSource(
            id: UUID().uuidString,
            name: name,
            url: url,
            isBuiltIn: false
        )
        config.streaming.sources.append(source)
        save()
        return source
    }
    
    func removeVideoSource(_ source: VideoSource) {
        guard !source.isBuiltIn else { return }
        config.streaming.sources.removeAll { $0.id == source.id }
        if config.streaming.selectedSourceId == source.id {
            config.streaming.selectedSourceId = VideoSource.midjourneyTV.id
        }
        save()
    }
    
    // MARK: - Private Methods
    
    private static func loadConfiguration() -> AppConfiguration? {
        let fileManager = FileManager.default
        let appSupport = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        
        // 새 경로에서 먼저 시도
        let newConfigURL = appSupport.appendingPathComponent("AIStreamWallpaper/config.json")
        if fileManager.fileExists(atPath: newConfigURL.path) {
            do {
                let data = try Data(contentsOf: newConfigURL)
                print("📂 Loaded config from: AIStreamWallpaper")
                return try JSONDecoder().decode(AppConfiguration.self, from: data)
            } catch {
                print("Failed to load new config: \(error)")
            }
        }
        
        // 이전 경로에서 로드 (마이그레이션)
        let oldConfigURL = appSupport.appendingPathComponent("AIStreamWallpaper/config.json")
        if fileManager.fileExists(atPath: oldConfigURL.path) {
            do {
                let data = try Data(contentsOf: oldConfigURL)
                print("📂 Loaded config from: AIStreamWallpaper (will migrate)")
                var config = try JSONDecoder().decode(AppConfiguration.self, from: data)
                // 경로를 새 경로로 업데이트
                config.library.path = appSupport.appendingPathComponent("AIStreamWallpaper").path
                return config
            } catch {
                print("Failed to load old config: \(error)")
            }
        }
        
        return nil
    }
    
    private func migrateConfigurationIfNeeded() {
        // Ensure Midjourney TV source exists
        if !config.streaming.sources.contains(where: { $0.id == VideoSource.midjourneyTV.id }) {
            config.streaming.sources.insert(VideoSource.midjourneyTV, at: 0)
        }
        
        // 이전 데이터 마이그레이션
        migrateOldData()
        
        save()
    }
    
    private func migrateOldData() {
        let fileManager = FileManager.default
        let appSupport = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        let oldPath = appSupport.appendingPathComponent("AIStreamWallpaper")
        let newPath = appSupport.appendingPathComponent("AIStreamWallpaper")
        
        // 이전 데이터베이스가 있고 새 데이터베이스가 없거나 비어있으면 복사
        let oldDB = oldPath.appendingPathComponent("library.sqlite")
        let newDB = newPath.appendingPathComponent("library.sqlite")
        
        if fileManager.fileExists(atPath: oldDB.path) {
            // 새 DB가 없거나 비어있는지 확인
            let newDBExists = fileManager.fileExists(atPath: newDB.path)
            let newDBEmpty = (try? fileManager.attributesOfItem(atPath: newDB.path)[.size] as? Int) == 0
            
            if !newDBExists || newDBEmpty == true {
                print("📦 Migrating database from AIStreamWallpaper...")
                
                // 새 디렉토리 생성
                try? fileManager.createDirectory(at: newPath, withIntermediateDirectories: true)
                
                // DB 복사
                try? fileManager.removeItem(at: newDB)
                do {
                    try fileManager.copyItem(at: oldDB, to: newDB)
                    print("📦 ✅ Database migrated")
                } catch {
                    print("📦 ❌ DB migration failed: \(error)")
                }
                
                // 비디오 폴더 복사/심볼릭 링크
                let oldVideos = oldPath.appendingPathComponent("videos")
                let newVideos = newPath.appendingPathComponent("videos")
                if fileManager.fileExists(atPath: oldVideos.path) && !fileManager.fileExists(atPath: newVideos.path) {
                    do {
                        try fileManager.copyItem(at: oldVideos, to: newVideos)
                        print("📦 ✅ Videos folder migrated")
                    } catch {
                        print("📦 ❌ Videos migration failed: \(error)")
                    }
                }
                
                // 썸네일 폴더 복사
                let oldThumbs = oldPath.appendingPathComponent("thumbnails")
                let newThumbs = newPath.appendingPathComponent("thumbnails")
                if fileManager.fileExists(atPath: oldThumbs.path) && !fileManager.fileExists(atPath: newThumbs.path) {
                    do {
                        try fileManager.copyItem(at: oldThumbs, to: newThumbs)
                        print("📦 ✅ Thumbnails folder migrated")
                    } catch {
                        print("📦 ❌ Thumbnails migration failed: \(error)")
                    }
                }
            }
        }
    }
    
    private func ensureDirectoriesExist() {
        let libraryPath = config.library.path
        let videosPath = (libraryPath as NSString).appendingPathComponent("videos")
        let thumbnailsPath = (libraryPath as NSString).appendingPathComponent("thumbnails")
        let cachePath = (libraryPath as NSString).appendingPathComponent("cache")
        
        do {
            try fileManager.createDirectory(atPath: libraryPath, withIntermediateDirectories: true)
            try fileManager.createDirectory(atPath: videosPath, withIntermediateDirectories: true)
            try fileManager.createDirectory(atPath: thumbnailsPath, withIntermediateDirectories: true)
            try fileManager.createDirectory(atPath: cachePath, withIntermediateDirectories: true)
        } catch {
            print("Failed to create directories: \(error)")
        }
    }
}

// MARK: - Launch Agent Manager

class LaunchAgentManager {
    
    static let shared = LaunchAgentManager()
    
    private let launchAgentPath: String = {
        let home = FileManager.default.homeDirectoryForCurrentUser
        return home.appendingPathComponent("Library/LaunchAgents/com.midtv.wallpaper.plist").path
    }()
    
    func setEnabled(_ enabled: Bool) {
        if enabled {
            createLaunchAgent()
        } else {
            removeLaunchAgent()
        }
    }
    
    var isEnabled: Bool {
        FileManager.default.fileExists(atPath: launchAgentPath)
    }
    
    private func createLaunchAgent() {
        guard let bundlePath = Bundle.main.bundlePath as String? else { return }
        
        let plist: [String: Any] = [
            "Label": "com.midtv.wallpaper",
            "ProgramArguments": [bundlePath + "/Contents/MacOS/AIStreamWallpaper"],
            "RunAtLoad": true,
            "KeepAlive": false
        ]
        
        do {
            let data = try PropertyListSerialization.data(fromPropertyList: plist, format: .xml, options: 0)
            
            let directory = (launchAgentPath as NSString).deletingLastPathComponent
            try FileManager.default.createDirectory(atPath: directory, withIntermediateDirectories: true)
            
            try data.write(to: URL(fileURLWithPath: launchAgentPath))
            print("Launch agent created at: \(launchAgentPath)")
        } catch {
            print("Failed to create launch agent: \(error)")
        }
    }
    
    private func removeLaunchAgent() {
        do {
            try FileManager.default.removeItem(atPath: launchAgentPath)
            print("Launch agent removed")
        } catch {
            print("Failed to remove launch agent: \(error)")
        }
    }
}
