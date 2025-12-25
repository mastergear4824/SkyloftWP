//
//  DownloadManager.swift
//  SkyloftWP
//
//  Manages video downloads with queue system and optimized processing
//

import Foundation
import AVFoundation
import Combine

// MARK: - Download Error

enum DownloadError: Error {
    case invalidURL
    case downloadFailed(statusCode: Int)
    case networkError(Error)
    case saveFailed
    case videoProcessingFailed
    case alreadyDownloading
    case queueFull
    case cancelled
    
    var localizedDescription: String {
        switch self {
        case .invalidURL:
            return "Invalid URL"
        case .downloadFailed(let code):
            return "Download failed (HTTP \(code))"
        case .networkError(let error):
            return "Network error: \(error.localizedDescription)"
        case .saveFailed:
            return "Failed to save file"
        case .videoProcessingFailed:
            return "Video processing failed"
        case .alreadyDownloading:
            return "Already downloading this video"
        case .queueFull:
            return "Download queue is full"
        case .cancelled:
            return "Download cancelled"
        }
    }
}

// MARK: - Download State

enum DownloadState: Equatable {
    case queued
    case downloading(progress: Double)
    case processing
    case completed
    case failed(String)
}

// MARK: - Download Item

struct DownloadItem: Identifiable {
    let id: String
    let url: URL
    let metadata: VideoMetadata
    var state: DownloadState = .queued
    var retryCount: Int = 0
    let createdAt: Date = Date()
}

// MARK: - Download Manager

class DownloadManager: ObservableObject {
    
    // MARK: - Singleton
    
    static let shared = DownloadManager()
    
    // MARK: - Published Properties
    
    @Published private(set) var downloadQueue: [DownloadItem] = []
    @Published private(set) var activeDownloadCount: Int = 0
    @Published private(set) var totalDownloaded: Int = 0
    
    // MARK: - Configuration
    
    private let maxConcurrentDownloads = 2
    private let maxRetries = 3
    private let maxQueueSize = 10
    
    // MARK: - Properties
    
    private let fileManager = FileManager.default
    private let session: URLSession
    private var downloadTasks: [String: URLSessionDownloadTask] = [:]
    private var downloadingURLs: Set<String> = []
    private let queue = DispatchQueue(label: "com.aistreamwallpaper.download", qos: .userInitiated)
    // 섬네일 생성 우선순위를 높이고 병렬 처리 지원
    private var processingQueue = DispatchQueue(label: "com.aistreamwallpaper.processing", qos: .userInitiated, attributes: .concurrent)
    
    private var videosDirectory: URL {
        let path = ConfigurationManager.shared.config.library.path
        return URL(fileURLWithPath: path).appendingPathComponent("videos")
    }
    
    // MARK: - Initialization
    
    private init() {
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 30
        config.timeoutIntervalForResource = 180
        config.httpMaximumConnectionsPerHost = 4
        config.waitsForConnectivity = true
        self.session = URLSession(configuration: config)
    }
    
    // MARK: - Public Methods
    
    /// Add video to download queue
    func queueDownload(from url: URL, metadata: VideoMetadata) {
        let urlString = url.absoluteString
        
        queue.async { [weak self] in
            guard let self = self else { return }
            
            // Check if already downloading or queued
            if self.downloadingURLs.contains(urlString) {
                print("⏭️ [Download] Already downloading: \(url.lastPathComponent)")
                return
            }
            
            // Check queue size
            if self.downloadQueue.count >= self.maxQueueSize {
                print("⚠️ [Download] Queue full, dropping oldest")
                DispatchQueue.main.async {
                    if !self.downloadQueue.isEmpty {
                        self.downloadQueue.removeFirst()
                    }
                }
            }
            
            // Add to queue
            let item = DownloadItem(id: UUID().uuidString, url: url, metadata: metadata)
            self.downloadingURLs.insert(urlString)
            
            DispatchQueue.main.async {
                self.downloadQueue.append(item)
                print("📥 [Download] Queued: \(url.lastPathComponent) (Queue: \(self.downloadQueue.count))")
            }
            
            // Process queue
            self.processQueue()
        }
    }
    
    /// Download video directly (async)
    func downloadVideo(from url: URL, metadata: VideoMetadata) async throws -> VideoItem {
        let videoId = UUID().uuidString
        let fileExtension = url.pathExtension.isEmpty ? "mp4" : url.pathExtension
        let fileName = "\(videoId).\(fileExtension)"
        let localURL = videosDirectory.appendingPathComponent(fileName)
        
        // Ensure directory exists
        try fileManager.createDirectory(at: videosDirectory, withIntermediateDirectories: true)
        
        // Download with retry logic
        var lastError: Error?
        
        for attempt in 1...maxRetries {
            do {
                print("⬇️ [Download] Attempt \(attempt)/\(maxRetries): \(url.lastPathComponent)")
                
                let (tempURL, response) = try await session.download(from: url)
                
                guard let httpResponse = response as? HTTPURLResponse else {
                    throw DownloadError.downloadFailed(statusCode: 0)
                }
                
                guard (200...299).contains(httpResponse.statusCode) else {
                    throw DownloadError.downloadFailed(statusCode: httpResponse.statusCode)
                }
                
                // Move to final location
                if fileManager.fileExists(atPath: localURL.path) {
                    try fileManager.removeItem(at: localURL)
                }
                try fileManager.moveItem(at: tempURL, to: localURL)
                
                // Get file size immediately (fast)
                let attributes = try fileManager.attributesOfItem(atPath: localURL.path)
                let fileSize = attributes[.size] as? Int64 ?? 0
                
                // ✅ 최적화: 16:9 검증 + 메타데이터 추출을 한 번에 처리 (AVAsset 재사용)
                let validationResult = try await validateAndGetVideoInfo(from: localURL)
                
                if !validationResult.isValid {
                    // 16:9가 아니면 삭제
                    print("❌ [Download] Not 16:9, deleting...")
                    try? fileManager.removeItem(at: localURL)
                    throw DownloadError.downloadFailed(statusCode: -1) // 스킵
                }
                
                print("✅ [Download] Saved: \(fileName) (\(ByteCountFormatter.string(fromByteCount: fileSize, countStyle: .file)))")
                
                // Create video item with metadata from validation (이미 추출됨)
                let video = VideoItem(
                    id: videoId,
                    sourceUrl: metadata.sourceUrl,
                    prompt: metadata.prompt,
                    author: metadata.author,
                    midjourneyJobId: metadata.midjourneyJobId,
                    savedAt: Date(),
                    duration: validationResult.duration,
                    resolution: validationResult.resolution,
                    fileSize: fileSize,
                    localPath: localURL.path,
                    thumbnailPath: nil
                )
                
                // 폴더에 파일 저장 완료 → DB 동기화
                LibraryManager.shared.syncFromFolder()
                
                // 썸네일만 백그라운드에서 처리 (메타데이터는 이미 있음)
                processVideoThumbnailInBackground(videoId: videoId, localURL: localURL, duration: validationResult.duration, resolution: validationResult.resolution)
                
                DispatchQueue.main.async {
                    self.totalDownloaded += 1
                }
                
                return video
                
            } catch {
                lastError = error
                print("❌ [Download] Attempt \(attempt) failed: \(error.localizedDescription)")
                
                if attempt < maxRetries {
                    // Exponential backoff
                    let delay = Double(attempt) * 1.0
                    try await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
                }
            }
        }
        
        throw lastError ?? DownloadError.downloadFailed(statusCode: 0)
    }
    
    // MARK: - 최적화: 16:9 검증 + 메타데이터 추출 통합 (AVAsset 1회 생성)
    
    private func validateAndGetVideoInfo(from localURL: URL) async throws -> (isValid: Bool, duration: Double, resolution: String) {
        let asset = AVURLAsset(url: localURL)
        
        // 비디오 트랙 로드
        let tracks = try await asset.loadTracks(withMediaType: .video)
        guard let track = tracks.first else {
            return (false, 0, "Unknown")
        }
        
        // 크기와 변환 동시 로드
        let size = try await track.load(.naturalSize)
        let transform = try await track.load(.preferredTransform)
        let transformedSize = size.applying(transform)
        
        let width = abs(transformedSize.width)
        let height = abs(transformedSize.height)
        
        // 16:9 비율 확인 (허용 오차 5%)
        var isValid = true
        if height > 0 {
            let ratio = width / height
            let targetRatio: CGFloat = 16.0 / 9.0
            isValid = ratio >= targetRatio * 0.95 && ratio <= targetRatio * 1.05
            
            if isValid {
                print("✅ [Download] 16:9 verified: \(Int(width))x\(Int(height))")
            } else {
                print("❌ [Download] Not 16:9 (\(Int(width))x\(Int(height)) = \(String(format: "%.2f", ratio)))")
            }
        }
        
        // duration 로드
        let duration = try await asset.load(.duration)
        let durationSeconds = CMTimeGetSeconds(duration)
        
        let resolution = "\(Int(width))x\(Int(height))"
        
        return (isValid, durationSeconds, resolution)
    }
    
    func cancelDownload(for urlString: String) {
        downloadTasks[urlString]?.cancel()
        downloadTasks.removeValue(forKey: urlString)
        downloadingURLs.remove(urlString)
        
        DispatchQueue.main.async {
            self.downloadQueue.removeAll { $0.url.absoluteString == urlString }
        }
    }
    
    func cancelAllDownloads() {
        downloadTasks.values.forEach { $0.cancel() }
        downloadTasks.removeAll()
        downloadingURLs.removeAll()
        
        DispatchQueue.main.async {
            self.downloadQueue.removeAll()
            self.activeDownloadCount = 0
        }
    }
    
    // MARK: - Queue Processing
    
    private func processQueue() {
        queue.async { [weak self] in
            guard let self = self else { return }
            
            // Check if we can start more downloads
            while self.activeDownloadCount < self.maxConcurrentDownloads {
                // Find next queued item
                guard let index = self.downloadQueue.firstIndex(where: {
                    if case .queued = $0.state { return true }
                    return false
                }) else {
                    break
                }
                
                var item = self.downloadQueue[index]
                item.state = .downloading(progress: 0)
                
                DispatchQueue.main.async {
                    self.downloadQueue[index] = item
                    self.activeDownloadCount += 1
                }
                
                // Start download
                Task {
                    await self.performDownload(item: item, index: index)
                }
            }
        }
    }
    
    private func performDownload(item: DownloadItem, index: Int) async {
        do {
            let _ = try await downloadVideo(from: item.url, metadata: item.metadata)
            
            await MainActor.run {
                if index < self.downloadQueue.count {
                    self.downloadQueue[index].state = .completed
                }
                self.activeDownloadCount = max(0, self.activeDownloadCount - 1)
                self.downloadingURLs.remove(item.url.absoluteString)
                
                // Remove completed items after delay
                DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                    self.downloadQueue.removeAll { $0.id == item.id }
                }
            }
            
        } catch {
            await MainActor.run {
                if index < self.downloadQueue.count {
                    self.downloadQueue[index].state = .failed(error.localizedDescription)
                }
                self.activeDownloadCount = max(0, self.activeDownloadCount - 1)
                self.downloadingURLs.remove(item.url.absoluteString)
            }
        }
        
        // Process next in queue
        processQueue()
    }
    
    // MARK: - Background Processing
    
    /// 썸네일만 백그라운드에서 처리 (메타데이터는 이미 추출됨)
    private func processVideoThumbnailInBackground(videoId: String, localURL: URL, duration: Double, resolution: String) {
        Task(priority: .high) {
            do {
                // 섬네일 생성
                let thumbnailPath = try await ThumbnailGenerator.shared.generateThumbnail(for: localURL, videoId: videoId)
                
                // 섬네일이 생성되면 메타데이터와 함께 업데이트
                await MainActor.run {
                    LibraryManager.shared.updateVideoMetadata(
                        videoId: videoId,
                        duration: duration,
                        resolution: resolution,
                        thumbnailPath: thumbnailPath
                    )
                    print("🖼️ [Process] Thumbnail ready: \(videoId.prefix(8))...")
                }
                
            } catch {
                print("⚠️ [Process] Failed to generate thumbnail: \(error.localizedDescription)")
            }
        }
    }
    
    /// 기존 호환성을 위한 메서드 (메타데이터 + 썸네일 모두 처리)
    private func processVideoInBackground(videoId: String, localURL: URL) {
        Task(priority: .high) {
            do {
                // 메타데이터 추출
                let info = try await validateAndGetVideoInfo(from: localURL)
                
                // 섬네일 생성
                let thumbnailPath = try await ThumbnailGenerator.shared.generateThumbnail(for: localURL, videoId: videoId)
                
                // 업데이트
                await MainActor.run {
                    LibraryManager.shared.updateVideoMetadata(
                        videoId: videoId,
                        duration: info.duration,
                        resolution: info.resolution,
                        thumbnailPath: thumbnailPath
                    )
                    print("🎬 [Process] Complete: \(videoId.prefix(8))...")
                }
                
            } catch {
                print("⚠️ [Process] Failed to process video: \(error.localizedDescription)")
            }
        }
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
        
        // 폴더에 파일 저장 완료 → DB 동기화
        LibraryManager.shared.syncFromFolder()
        
        return video
    }
}
