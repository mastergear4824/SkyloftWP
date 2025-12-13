//
//  VideoItem.swift
//  AIStreamWallpaper
//
//  Video metadata model for library management
//

import Foundation

struct VideoItem: Identifiable, Codable, Equatable, Hashable {
    let id: String
    var sourceUrl: String?
    var prompt: String?
    var author: String?
    var midjourneyJobId: String?
    var savedAt: Date
    var duration: Double?
    var resolution: String?
    var fileSize: Int64?
    var localPath: String
    var thumbnailPath: String?
    var favorite: Bool
    var playCount: Int
    var lastPlayed: Date?
    
    // MARK: - Computed Properties
    
    var fileName: String {
        URL(fileURLWithPath: localPath).lastPathComponent
    }
    
    var displayDuration: String {
        guard let duration = duration else { return "--:--" }
        let minutes = Int(duration) / 60
        let seconds = Int(duration) % 60
        return String(format: "%d:%02d", minutes, seconds)
    }
    
    var displayFileSize: String {
        guard let size = fileSize else { return "--" }
        let formatter = ByteCountFormatter()
        formatter.countStyle = .file
        return formatter.string(fromByteCount: size)
    }
    
    var localURL: URL {
        URL(fileURLWithPath: localPath)
    }
    
    var thumbnailURL: URL? {
        guard let path = thumbnailPath else { return nil }
        return URL(fileURLWithPath: path)
    }
    
    var exists: Bool {
        FileManager.default.fileExists(atPath: localPath)
    }
    
    // MARK: - Initialization
    
    init(
        id: String = UUID().uuidString,
        sourceUrl: String? = nil,
        prompt: String? = nil,
        author: String? = nil,
        midjourneyJobId: String? = nil,
        savedAt: Date = Date(),
        duration: Double? = nil,
        resolution: String? = nil,
        fileSize: Int64? = nil,
        localPath: String,
        thumbnailPath: String? = nil,
        favorite: Bool = false,
        playCount: Int = 0,
        lastPlayed: Date? = nil
    ) {
        self.id = id
        self.sourceUrl = sourceUrl
        self.prompt = prompt
        self.author = author
        self.midjourneyJobId = midjourneyJobId
        self.savedAt = savedAt
        self.duration = duration
        self.resolution = resolution
        self.fileSize = fileSize
        self.localPath = localPath
        self.thumbnailPath = thumbnailPath
        self.favorite = favorite
        self.playCount = playCount
        self.lastPlayed = lastPlayed
    }
    
    // MARK: - Methods
    
    mutating func incrementPlayCount() {
        playCount += 1
        lastPlayed = Date()
    }
    
    mutating func toggleFavorite() {
        favorite.toggle()
    }
}

// MARK: - Video Metadata (from streaming)

struct VideoMetadata {
    var sourceUrl: String
    var prompt: String?
    var author: String?
    var midjourneyJobId: String?
    
    func toVideoItem(localPath: String, thumbnailPath: String? = nil) -> VideoItem {
        VideoItem(
            sourceUrl: sourceUrl,
            prompt: prompt,
            author: author,
            midjourneyJobId: midjourneyJobId,
            localPath: localPath,
            thumbnailPath: thumbnailPath
        )
    }
}

// MARK: - Sorting Options

enum VideoSortOption: String, CaseIterable {
    case savedAtDesc = "savedAtDesc"
    case savedAtAsc = "savedAtAsc"
    case nameAsc = "nameAsc"
    case nameDesc = "nameDesc"
    case playCountDesc = "playCountDesc"
    case durationAsc = "durationAsc"
    case durationDesc = "durationDesc"
    
    var displayName: String {
        switch self {
        case .savedAtDesc: return "최근 저장순"
        case .savedAtAsc: return "오래된 순"
        case .nameAsc: return "이름 (A-Z)"
        case .nameDesc: return "이름 (Z-A)"
        case .playCountDesc: return "재생 횟수순"
        case .durationAsc: return "짧은 순"
        case .durationDesc: return "긴 순"
        }
    }
}

