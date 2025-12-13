//
//  DownloadManager.swift
//  AIStreamWallpaper
//
//  Manages video downloads and saves to library
//

import Foundation
import AVFoundation

enum DownloadError: Error {
    case invalidURL
    case downloadFailed
    case saveFailed
    case videoProcessingFailed
    
    var localizedDescription: String {
        switch self {
        case .invalidURL:
            return "유효하지 않은 URL입니다"
        case .downloadFailed:
            return "다운로드에 실패했습니다"
        case .saveFailed:
            return "파일 저장에 실패했습니다"
        case .videoProcessingFailed:
            return "영상 처리에 실패했습니다"
        }
    }
}

class DownloadManager {
    
    // MARK: - Singleton
    
    static let shared = DownloadManager()
    
    // MARK: - Properties
    
    private let fileManager = FileManager.default
    private let session: URLSession
    private var activeDownloads: [String: URLSessionDownloadTask] = [:]
    
    private var videosDirectory: URL {
        let path = ConfigurationManager.shared.config.library.path
        return URL(fileURLWithPath: path).appendingPathComponent("videos")
    }
    
    // MARK: - Initialization
    
    private init() {
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 60
        config.timeoutIntervalForResource = 300
        self.session = URLSession(configuration: config)
    }
    
    // MARK: - Public Methods
    
    func downloadVideo(from url: URL, metadata: VideoMetadata) async throws -> VideoItem {
        // Generate unique ID
        let videoId = UUID().uuidString
        let fileExtension = url.pathExtension.isEmpty ? "mp4" : url.pathExtension
        let fileName = "\(videoId).\(fileExtension)"
        let localURL = videosDirectory.appendingPathComponent(fileName)
        
        // Ensure directory exists
        try fileManager.createDirectory(at: videosDirectory, withIntermediateDirectories: true)
        
        // Download file
        let (tempURL, response) = try await session.download(from: url)
        
        guard let httpResponse = response as? HTTPURLResponse,
              (200...299).contains(httpResponse.statusCode) else {
            throw DownloadError.downloadFailed
        }
        
        // Move to final location
        if fileManager.fileExists(atPath: localURL.path) {
            try fileManager.removeItem(at: localURL)
        }
        try fileManager.moveItem(at: tempURL, to: localURL)
        
        // Get video metadata
        let videoInfo = try await getVideoInfo(from: localURL)
        
        // Generate thumbnail
        let thumbnailPath = try await ThumbnailGenerator.shared.generateThumbnail(for: localURL, videoId: videoId)
        
        // Create video item
        var video = metadata.toVideoItem(localPath: localURL.path, thumbnailPath: thumbnailPath)
        video = VideoItem(
            id: videoId,
            sourceUrl: metadata.sourceUrl,
            prompt: metadata.prompt,
            author: metadata.author,
            midjourneyJobId: metadata.midjourneyJobId,
            savedAt: Date(),
            duration: videoInfo.duration,
            resolution: videoInfo.resolution,
            fileSize: videoInfo.fileSize,
            localPath: localURL.path,
            thumbnailPath: thumbnailPath
        )
        
        // Save to library
        LibraryManager.shared.add(video)
        
        print("Downloaded video: \(fileName)")
        return video
    }
    
    func cancelDownload(for urlString: String) {
        activeDownloads[urlString]?.cancel()
        activeDownloads.removeValue(forKey: urlString)
    }
    
    func cancelAllDownloads() {
        activeDownloads.values.forEach { $0.cancel() }
        activeDownloads.removeAll()
    }
    
    // MARK: - Private Methods
    
    private func getVideoInfo(from url: URL) async throws -> (duration: Double, resolution: String, fileSize: Int64) {
        let asset = AVURLAsset(url: url)
        
        // Get duration
        let duration = try await asset.load(.duration)
        let durationSeconds = CMTimeGetSeconds(duration)
        
        // Get resolution
        var resolution = "Unknown"
        let tracks = try await asset.loadTracks(withMediaType: .video)
        if let videoTrack = tracks.first {
            let size = try await videoTrack.load(.naturalSize)
            resolution = "\(Int(size.width))x\(Int(size.height))"
        }
        
        // Get file size
        let attributes = try fileManager.attributesOfItem(atPath: url.path)
        let fileSize = attributes[.size] as? Int64 ?? 0
        
        return (durationSeconds, resolution, fileSize)
    }
}

// MARK: - Import Manager

class ImportManager {
    
    static let shared = ImportManager()
    
    private let fileManager = FileManager.default
    
    private var videosDirectory: URL {
        let path = ConfigurationManager.shared.config.library.path
        return URL(fileURLWithPath: path).appendingPathComponent("videos")
    }
    
    func importVideo(from sourceURL: URL) async throws -> VideoItem {
        let videoId = UUID().uuidString
        let fileName = "\(videoId).\(sourceURL.pathExtension)"
        let localURL = videosDirectory.appendingPathComponent(fileName)
        
        // Ensure directory exists
        try fileManager.createDirectory(at: videosDirectory, withIntermediateDirectories: true)
        
        // Copy file
        try fileManager.copyItem(at: sourceURL, to: localURL)
        
        // Get video info
        let asset = AVURLAsset(url: localURL)
        let duration = try await asset.load(.duration)
        let durationSeconds = CMTimeGetSeconds(duration)
        
        var resolution = "Unknown"
        let tracks = try await asset.loadTracks(withMediaType: .video)
        if let videoTrack = tracks.first {
            let size = try await videoTrack.load(.naturalSize)
            resolution = "\(Int(size.width))x\(Int(size.height))"
        }
        
        let attributes = try fileManager.attributesOfItem(atPath: localURL.path)
        let fileSize = attributes[.size] as? Int64 ?? 0
        
        // Generate thumbnail
        let thumbnailPath = try await ThumbnailGenerator.shared.generateThumbnail(for: localURL, videoId: videoId)
        
        // Create video item
        let video = VideoItem(
            id: videoId,
            sourceUrl: nil,
            prompt: sourceURL.deletingPathExtension().lastPathComponent,
            author: nil,
            midjourneyJobId: nil,
            savedAt: Date(),
            duration: durationSeconds,
            resolution: resolution,
            fileSize: fileSize,
            localPath: localURL.path,
            thumbnailPath: thumbnailPath
        )
        
        // Save to library
        LibraryManager.shared.add(video)
        
        return video
    }
}



