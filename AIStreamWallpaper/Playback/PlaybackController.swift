//
//  PlaybackController.swift
//  AIStreamWallpaper
//
//  Controls video playback and navigation
//

import Foundation
import Combine

class PlaybackController: ObservableObject {
    
    // MARK: - Singleton
    
    static let shared = PlaybackController()
    
    // MARK: - Published Properties
    
    @Published var currentVideo: VideoItem?
    @Published var currentIndex: Int = 0
    @Published var isPlaying = false
    
    // MARK: - Properties
    
    private let libraryManager = LibraryManager.shared
    private let configManager = ConfigurationManager.shared
    private var cancellables = Set<AnyCancellable>()
    
    // MARK: - Initialization
    
    private init() {
        setupObservers()
    }
    
    private func setupObservers() {
        libraryManager.$videos
            .receive(on: DispatchQueue.main)
            .sink { [weak self] videos in
                // 현재 영상이 삭제되었으면 첫 번째 영상 재생
                if let self = self,
                   let current = self.currentVideo,
                   !videos.contains(where: { $0.id == current.id }) {
                    self.playFirst()
                }
            }
            .store(in: &cancellables)
    }
    
    // MARK: - Playback Control
    
    func play(video: VideoItem) {
        currentVideo = video
        
        if let index = libraryManager.videos.firstIndex(where: { $0.id == video.id }) {
            currentIndex = index
        }
        
        isPlaying = true
        libraryManager.updatePlayCount(video)
        
        configManager.config.library.currentVideoId = video.id
        configManager.save()
    }
    
    func playFirst() {
        let videos = libraryManager.videos
        guard !videos.isEmpty else {
            currentVideo = nil
            return
        }
        play(video: videos[0])
    }
    
    func next() {
        let videos = libraryManager.videos
        guard !videos.isEmpty else { return }
        
        var nextIdx = currentIndex + 1
        if nextIdx >= videos.count {
            nextIdx = 0
        }
        
        currentIndex = nextIdx
        currentVideo = videos[nextIdx]
        isPlaying = true
    }
    
    func previous() {
        let videos = libraryManager.videos
        guard !videos.isEmpty else { return }
        
        var prevIdx = currentIndex - 1
        if prevIdx < 0 {
            prevIdx = videos.count - 1
        }
        
        currentIndex = prevIdx
        play(video: videos[prevIdx])
    }
    
    func pause() {
        isPlaying = false
    }
    
    func resume() {
        isPlaying = true
    }
    
    func togglePlayPause() {
        isPlaying.toggle()
    }
    
    func restoreLastPlayedVideo() {
        guard let lastVideoId = configManager.config.library.currentVideoId,
              let video = libraryManager.videos.first(where: { $0.id == lastVideoId }) else {
            return
        }
        
        currentVideo = video
        if let index = libraryManager.videos.firstIndex(where: { $0.id == video.id }) {
            currentIndex = index
        }
    }
}

// MARK: - Playlist Info

extension PlaybackController {
    var playlistCount: Int {
        libraryManager.videos.count
    }
    
    var currentPosition: String {
        let count = libraryManager.videos.count
        guard count > 0 else { return "0 / 0" }
        return "\(currentIndex + 1) / \(count)"
    }
}
