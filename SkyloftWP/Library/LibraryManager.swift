//
//  LibraryManager.swift
//  SkyloftWP
//
//  High-level library management
//

import Foundation
import Combine

class LibraryManager: ObservableObject {
    
    // MARK: - Singleton
    
    static let shared = LibraryManager()
    
    // MARK: - Published Properties
    
    @Published var videos: [VideoItem] = []
    @Published var isLoading = false
    
    // MARK: - Properties
    
    private let database = LibraryDatabase.shared
    private let fileManager = FileManager.default
    
    // NotificationCenter 알림 debounce용
    private var notifyWorkItem: DispatchWorkItem?
    
    // 숨김 처리된 비디오 ID (싫어요) - 메모리 캐시 적용
    private var _dislikedCache: Set<String>?
    private var dislikedVideoIds: Set<String> {
        get {
            if let cached = _dislikedCache { return cached }
            let ids = Set(UserDefaults.standard.stringArray(forKey: "DislikedVideoIds") ?? [])
            _dislikedCache = ids
            return ids
        }
        set {
            _dislikedCache = newValue
            UserDefaults.standard.set(Array(newValue), forKey: "DislikedVideoIds")
        }
    }
    
    var dislikedCount: Int {
        dislikedVideoIds.count
    }
    
    var videosDirectory: URL {
        let path = ConfigurationManager.shared.config.library.path
        return URL(fileURLWithPath: path).appendingPathComponent("videos")
    }
    
    private var thumbnailsDirectory: URL {
        let path = ConfigurationManager.shared.config.library.path
        return URL(fileURLWithPath: path).appendingPathComponent("thumbnails")
    }
    
    // MARK: - Initialization
    
    private init() {
        loadLibrary()
    }
    
    // MARK: - Debounced Notification (중복 알림 방지)
    
    private func notifyLibraryUpdate() {
        notifyWorkItem?.cancel()
        notifyWorkItem = DispatchWorkItem { [weak self] in
            guard self != nil else { return }
            NotificationCenter.default.post(name: .libraryDidUpdate, object: nil)
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3, execute: notifyWorkItem!)
    }
    
    // MARK: - Public Methods
    
    func loadLibrary() {
        isLoading = true
        
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            guard let self = self else { return }
            
            // ✅ 폴더 기준으로 직접 스캔 (DB는 메타데이터 보조용)
            // 최적화: 모든 속성을 한 번에 요청 (파일 시스템 접근 50% 감소)
            let videosDir = self.videosDirectory
            let resourceKeys: Set<URLResourceKey> = [.creationDateKey, .fileSizeKey, .isRegularFileKey]
            let actualFiles = (try? FileManager.default.contentsOfDirectory(
                at: videosDir,
                includingPropertiesForKeys: Array(resourceKeys),
                options: [.skipsHiddenFiles]
            ))?.filter { 
                let ext = $0.pathExtension.lowercased()
                return ext == "mp4" || ext == "mov" || ext == "m4v"
            } ?? []
            
            // DB에서 기존 메타데이터 로드 (중복 키는 최신 것 사용)
            let dbVideos = self.database.fetchAll()
            let dbByPath = Dictionary(dbVideos.map { ($0.localPath, $0) }, uniquingKeysWith: { _, new in new })
            
            // 싫어요 목록 (캐시됨)
            let dislikedIds = self.dislikedVideoIds
            
            // 폴더의 실제 파일로 비디오 목록 생성
            var validVideos: [VideoItem] = []
            var validPaths = Set<String>()
            
            for file in actualFiles {
                // 최적화: 이미 요청한 resourceValues 재사용 (추가 I/O 없음)
                guard let resources = try? file.resourceValues(forKeys: resourceKeys),
                      let size = resources.fileSize, size > 0 else {
                    continue
                }
                
                let path = file.path
                
                // 중복 경로 체크
                guard !validPaths.contains(path) else { continue }
                validPaths.insert(path)
                
                // DB에 있으면 메타데이터 사용, 없으면 새로 생성
                if let existing = dbByPath[path], !dislikedIds.contains(existing.id) {
                    validVideos.append(existing)
                } else if !dislikedIds.contains(path) {
                    // 새 파일 - VideoItem 생성 (이미 로드된 resourceValues 사용)
                    let creationDate = resources.creationDate ?? Date()
                    
                    let video = VideoItem(
                        id: UUID().uuidString,
                        sourceUrl: file.absoluteString,
                        prompt: nil,
                        author: nil,
                        midjourneyJobId: nil,
                        savedAt: creationDate,
                        duration: nil,
                        resolution: nil,
                        fileSize: Int64(size),
                        localPath: path,
                        thumbnailPath: nil,
                        favorite: false,
                        playCount: 0,
                        lastPlayed: nil
                    )
                    
                    self.database.insert(video)
                    validVideos.append(video)
                    print("➕ [Library] New file: \(file.lastPathComponent)")
                }
            }
            
            // DB 정리 - 파일이 없는 항목 삭제
            for dbVideo in dbVideos {
                if !validPaths.contains(dbVideo.localPath) {
                    self.database.delete(id: dbVideo.id)
                    print("🗑️ [Library] Removed from DB: \(dbVideo.fileName)")
                }
            }
            
            // ✅ 오래된 것부터 재생하도록 savedAt 기준 오름차순 정렬
            let sortedVideos = validVideos.sorted { ($0.savedAt ?? Date.distantPast) < ($1.savedAt ?? Date.distantPast) }
            
            DispatchQueue.main.async {
                self.videos = sortedVideos
                self.isLoading = false
                
                print("📚 [Library] Folder scan: \(sortedVideos.count) videos (files: \(actualFiles.count)), sorted by date (oldest first)")
                
                self.notifyLibraryUpdate()
            }
        }
    }
    
    // MARK: - Dislike (싫어요/숨김 처리)
    
    func dislike(_ video: VideoItem) {
        var ids = dislikedVideoIds
        ids.insert(video.id)
        dislikedVideoIds = ids
        
        DispatchQueue.main.async { [weak self] in
            self?.videos.removeAll { $0.id == video.id }
            self?.notifyLibraryUpdate()
        }
    }
    
    func undislike(_ videoId: String) {
        var ids = dislikedVideoIds
        ids.remove(videoId)
        dislikedVideoIds = ids
        loadLibrary() // 다시 로드해서 복원
    }
    
    func isDisliked(_ videoId: String) -> Bool {
        dislikedVideoIds.contains(videoId)
    }
    
    func clearDisliked() {
        dislikedVideoIds = []
        loadLibrary()
    }
    
    /// 폴더에 파일이 추가된 후 호출 - DB 동기화 트리거
    func syncFromFolder() {
        loadLibrary()
    }
    
    /// 비디오 삭제 - 폴더에서 파일 삭제 후 동기화
    func delete(_ video: VideoItem) {
        // 1. 폴더에서 파일 삭제
        try? fileManager.removeItem(atPath: video.localPath)
        if let thumbnailPath = video.thumbnailPath {
            try? fileManager.removeItem(atPath: thumbnailPath)
        }
        
        // 2. 폴더 스캔해서 DB 동기화 (삭제된 파일은 자동 제거됨)
        // notifyLibraryUpdate는 syncFromFolder 내부에서 호출됨
        DispatchQueue.main.async { [weak self] in
            self?.syncFromFolder()
        }
    }
    
    func toggleFavorite(_ video: VideoItem) {
        guard database.toggleFavorite(id: video.id) else {
            print("Failed to toggle favorite")
            return
        }
        
        DispatchQueue.main.async { [weak self] in
            if let index = self?.videos.firstIndex(where: { $0.id == video.id }) {
                self?.videos[index].favorite.toggle()
            }
        }
    }
    
    func updatePlayCount(_ video: VideoItem) {
        database.updatePlayCount(id: video.id)
        
        DispatchQueue.main.async { [weak self] in
            if let index = self?.videos.firstIndex(where: { $0.id == video.id }) {
                self?.videos[index].incrementPlayCount()
            }
        }
    }
    
    /// Update video metadata after background processing
    func updateVideoMetadata(videoId: String, duration: Double, resolution: String, thumbnailPath: String?) {
        // Update in database
        database.updateMetadata(id: videoId, duration: duration, resolution: resolution, thumbnailPath: thumbnailPath)
        
        // Update in memory - objectWillChange를 명시적으로 트리거해서 UI 업데이트
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            
            if let index = self.videos.firstIndex(where: { $0.id == videoId }) {
                // @Published 배열 변경 감지를 위해 새 객체로 교체
                var updatedVideo = self.videos[index]
                updatedVideo.duration = duration
                updatedVideo.resolution = resolution
                if let path = thumbnailPath {
                    updatedVideo.thumbnailPath = path
                }
                
                // 배열 자체를 수정해야 SwiftUI가 감지함
                self.videos[index] = updatedVideo
                
                // 명시적으로 UI 업데이트 알림
                self.objectWillChange.send()
                
                print("🖼️ [Library] Updated thumbnail for: \(videoId.prefix(8))...")
            }
            self.notifyLibraryUpdate()
        }
    }
    
    func search(query: String) -> [VideoItem] {
        if query.isEmpty {
            return videos
        }
        return database.search(query: query)
    }
    
    func getFavorites() -> [VideoItem] {
        return database.fetchFavorites()
    }
    
    /// 외부 파일을 라이브러리 폴더로 복사 후 동기화
    func importVideo(from url: URL) {
        Task {
            do {
                // 1. 파일을 폴더에 복사만 함 (DB 조작 없음)
                _ = try await ImportManager.shared.importVideo(from: url)
                
                // 2. 폴더 스캔해서 DB 동기화
                await MainActor.run {
                    syncFromFolder()
                }
            } catch {
                print("Failed to import video: \(error)")
            }
        }
    }
    
    // MARK: - Storage Management
    
    var totalStorageUsedBytes: Int64 {
        videos.compactMap { $0.fileSize }.reduce(0, +)
    }
    
    var totalStorageUsed: String {
        let bytes = totalStorageUsedBytes
        let formatter = ByteCountFormatter()
        formatter.countStyle = .file
        return formatter.string(fromByteCount: bytes)
    }
    
    func clearAll() {
        // 모든 비디오 파일 삭제
        for video in videos {
            try? fileManager.removeItem(atPath: video.localPath)
            if let thumbnailPath = video.thumbnailPath {
                try? fileManager.removeItem(atPath: thumbnailPath)
            }
            database.delete(id: video.id)
        }
        
        loadLibrary()
    }
    
    func cleanupOrphanedFiles() {
        DispatchQueue.global(qos: .utility).async { [weak self] in
            guard let self = self else { return }
            
            // 데이터베이스에서 직접 가져와서 확인 (메모리 배열이 아직 로드되지 않았을 수 있음)
            let dbVideos = self.database.fetchAll()
            
            // 데이터베이스가 비어있으면 정리하지 않음 (아직 초기화 중일 수 있음)
            guard !dbVideos.isEmpty else {
                print("⚠️ [Cleanup] Skipping - database is empty (might be initializing)")
                return
            }
            
            // Get all video files in directory
            let videoFiles = (try? self.fileManager.contentsOfDirectory(
                at: self.videosDirectory,
                includingPropertiesForKeys: nil
            )) ?? []
            
            // Get all known video paths from database
            let knownPaths = Set(dbVideos.map { $0.localPath })
            
            // Delete orphaned files
            for fileURL in videoFiles {
                if !knownPaths.contains(fileURL.path) {
                    try? self.fileManager.removeItem(at: fileURL)
                    print("Deleted orphaned file: \(fileURL.lastPathComponent)")
                }
            }
            
            // Same for thumbnails
            let thumbnailFiles = (try? self.fileManager.contentsOfDirectory(
                at: self.thumbnailsDirectory,
                includingPropertiesForKeys: nil
            )) ?? []
            
            let knownThumbnails = Set(dbVideos.compactMap { $0.thumbnailPath })
            
            for fileURL in thumbnailFiles {
                if !knownThumbnails.contains(fileURL.path) {
                    try? self.fileManager.removeItem(at: fileURL)
                    print("Deleted orphaned thumbnail: \(fileURL.lastPathComponent)")
                }
            }
        }
    }
}

