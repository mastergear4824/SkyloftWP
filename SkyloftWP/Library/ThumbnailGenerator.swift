//
//  ThumbnailGenerator.swift
//  SkyloftWP
//
//  Generates thumbnails from video files
//

import Foundation
import AVFoundation
import AppKit

class ThumbnailGenerator {
    
    // MARK: - Singleton
    
    static let shared = ThumbnailGenerator()
    
    // MARK: - Properties
    
    private let thumbnailSize = CGSize(width: 320, height: 180)  // 16:9 aspect ratio
    
    private var thumbnailsDirectory: URL {
        let path = ConfigurationManager.shared.config.library.path
        return URL(fileURLWithPath: path).appendingPathComponent("thumbnails")
    }
    
    // MARK: - Public Methods
    
    func generateThumbnail(for videoURL: URL, videoId: String) async throws -> String {
        // Ensure directory exists
        try FileManager.default.createDirectory(at: thumbnailsDirectory, withIntermediateDirectories: true)
        
        let thumbnailURL = thumbnailsDirectory.appendingPathComponent("\(videoId).jpg")
        
        // Generate thumbnail using AVAssetImageGenerator
        let asset = AVURLAsset(url: videoURL)
        let generator = AVAssetImageGenerator(asset: asset)
        generator.appliesPreferredTrackTransform = true
        generator.maximumSize = thumbnailSize
        
        // Get thumbnail at 1 second or 10% into the video
        let duration = try await asset.load(.duration)
        let durationSeconds = CMTimeGetSeconds(duration)
        let thumbnailTime = CMTime(seconds: min(1.0, durationSeconds * 0.1), preferredTimescale: 600)
        
        let cgImage = try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<CGImage, Error>) in
            generator.generateCGImagesAsynchronously(forTimes: [NSValue(time: thumbnailTime)]) { _, cgImage, _, result, error in
                if let error = error {
                    continuation.resume(throwing: error)
                } else if let cgImage = cgImage {
                    continuation.resume(returning: cgImage)
                } else {
                    continuation.resume(throwing: ThumbnailError.generationFailed)
                }
            }
        }
        
        // Convert to NSImage and save as JPEG
        let nsImage = NSImage(cgImage: cgImage, size: NSSize(width: cgImage.width, height: cgImage.height))
        
        guard let jpegData = nsImage.jpegData(compressionQuality: 0.8) else {
            throw ThumbnailError.compressionFailed
        }
        
        try jpegData.write(to: thumbnailURL)
        
        print("Generated thumbnail: \(thumbnailURL.lastPathComponent)")
        return thumbnailURL.path
    }
    
    func getThumbnail(for video: VideoItem) -> NSImage? {
        guard let thumbnailPath = video.thumbnailPath else { return nil }
        return NSImage(contentsOfFile: thumbnailPath)
    }
    
    func deleteThumbnail(for video: VideoItem) {
        guard let thumbnailPath = video.thumbnailPath else { return }
        try? FileManager.default.removeItem(atPath: thumbnailPath)
    }
    
    func regenerateThumbnail(for video: VideoItem) async throws -> String? {
        guard video.exists else { return nil }
        
        // Delete existing thumbnail
        deleteThumbnail(for: video)
        
        // Generate new thumbnail
        return try await generateThumbnail(for: video.localURL, videoId: video.id)
    }
}

// MARK: - Errors

enum ThumbnailError: Error {
    case generationFailed
    case compressionFailed
    case saveFailed
    
    var localizedDescription: String {
        switch self {
        case .generationFailed:
            return "썸네일 생성에 실패했습니다"
        case .compressionFailed:
            return "이미지 압축에 실패했습니다"
        case .saveFailed:
            return "썸네일 저장에 실패했습니다"
        }
    }
}

// MARK: - NSImage Extension

extension NSImage {
    func jpegData(compressionQuality: CGFloat) -> Data? {
        guard let tiffData = tiffRepresentation,
              let bitmapRep = NSBitmapImageRep(data: tiffData) else {
            return nil
        }
        
        return bitmapRep.representation(
            using: .jpeg,
            properties: [.compressionFactor: compressionQuality]
        )
    }
}



