//
//  LibraryManager.swift
//  AIStreamWallpaper
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
    
    // 숨김 처리된 비디오 ID (싫어요)
    private var dislikedVideoIds: Set<String> {
        get {
            Set(UserDefaults.standard.stringArray(forKey: "DislikedVideoIds") ?? [])
        }
        set {
            UserDefaults.standard.set(Array(newValue), forKey: "DislikedVideoIds")
        }
    }
    
    var dislikedCount: Int {
        dislikedVideoIds.count
    }
    
    private var videosDirectory: URL {
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
    
    // MARK: - Public Methods
    
    func loadLibrary() {
        isLoading = true
        
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            guard let self = self else { return }
            let loadedVideos = self.database.fetchAll()
            
            // Filter out videos that no longer exist on disk OR are disliked
            let dislikedIds = self.dislikedVideoIds
            let existingVideos = loadedVideos.filter { $0.exists && !dislikedIds.contains($0.id) }
            
            DispatchQueue.main.async {
                self.videos = existingVideos
                self.isLoading = false
                
                // Clean up database entries for missing files
                let missingIds = loadedVideos.filter { !$0.exists }.map { $0.id }
                for id in missingIds {
                    self.database.delete(id: id)
                }
                
                NotificationCenter.default.post(name: .libraryDidUpdate, object: nil)
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
            NotificationCenter.default.post(name: .libraryDidUpdate, object: nil)
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
    
    func add(_ video: VideoItem) {
        guard database.insert(video) else {
            print("Failed to add video to database")
            return
        }
        
        DispatchQueue.main.async { [weak self] in
            self?.videos.insert(video, at: 0)
            NotificationCenter.default.post(name: .libraryDidUpdate, object: video)
        }
    }
    
    func delete(_ video: VideoItem) {
        // Delete files
        try? fileManager.removeItem(atPath: video.localPath)
        if let thumbnailPath = video.thumbnailPath {
            try? fileManager.removeItem(atPath: thumbnailPath)
        }
        
        // Delete from database
        guard database.delete(id: video.id) else {
            print("Failed to delete video from database")
            return
        }
        
        DispatchQueue.main.async { [weak self] in
            self?.videos.removeAll { $0.id == video.id }
            NotificationCenter.default.post(name: .libraryDidUpdate, object: nil)
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
    
    func search(query: String) -> [VideoItem] {
        if query.isEmpty {
            return videos
        }
        return database.search(query: query)
    }
    
    func getFavorites() -> [VideoItem] {
        return database.fetchFavorites()
    }
    
    func importVideo(from url: URL) {
        Task {
            do {
                let video = try await ImportManager.shared.importVideo(from: url)
                await MainActor.run {
                    videos.insert(video, at: 0)
                    NotificationCenter.default.post(name: .libraryDidUpdate, object: video)
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

