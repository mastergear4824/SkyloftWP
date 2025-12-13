//
//  LibraryBrowserView.swift
//  AIStreamWallpaper
//
//  Video library browser window
//

import SwiftUI

struct LibraryBrowserView: View {
    @StateObject private var libraryManager = LibraryManager.shared
    @StateObject private var playbackController = PlaybackController.shared
    
    @State private var searchText = ""
    @State private var viewMode: ViewMode = .grid
    @State private var sortOption: VideoSortOption = .savedAtDesc
    @State private var showFavoritesOnly = false
    @State private var selectedVideo: VideoItem?
    @State private var showingDeleteConfirmation = false
    
    @Environment(\.dismiss) private var dismiss
    
    // Callback for closing when used in standalone window
    var onClose: (() -> Void)?
    
    init(onClose: (() -> Void)? = nil) {
        self.onClose = onClose
    }
    
    enum ViewMode {
        case grid
        case list
    }
    
    var filteredVideos: [VideoItem] {
        var videos = libraryManager.videos
        
        // Filter by search
        if !searchText.isEmpty {
            videos = videos.filter { video in
                video.fileName.localizedCaseInsensitiveContains(searchText) ||
                (video.prompt?.localizedCaseInsensitiveContains(searchText) ?? false) ||
                (video.author?.localizedCaseInsensitiveContains(searchText) ?? false)
            }
        }
        
        // Filter favorites
        if showFavoritesOnly {
            videos = videos.filter { $0.favorite }
        }
        
        // Sort
        videos = sortVideos(videos, by: sortOption)
        
        return videos
    }
    
    var body: some View {
        VStack(spacing: 0) {
            // Toolbar
            toolbar
            
            Divider()
            
            // Content
            if filteredVideos.isEmpty {
                emptyState
            } else {
                if viewMode == .grid {
                    gridView
                } else {
                    listView
                }
            }
            
            Divider()
            
            // Footer
            footer
        }
        .frame(minWidth: 600, minHeight: 500)
        .onAppear {
            libraryManager.loadLibrary()
        }
    }
    
    // MARK: - Toolbar
    
    private var toolbar: some View {
        HStack(spacing: 12) {
            // Search
            HStack {
                Image(systemName: "magnifyingglass")
                    .foregroundColor(.secondary)
                TextField("검색...", text: $searchText)
                    .textFieldStyle(.plain)
                if !searchText.isEmpty {
                    Button(action: { searchText = "" }) {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundColor(.secondary)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(8)
            .background(Color.secondary.opacity(0.1))
            .cornerRadius(8)
            .frame(maxWidth: 250)
            
            Spacer()
            
            // Favorites filter
            Button(action: { showFavoritesOnly.toggle() }) {
                Image(systemName: showFavoritesOnly ? "star.fill" : "star")
                    .foregroundColor(showFavoritesOnly ? .yellow : .secondary)
            }
            .buttonStyle(.plain)
            .help("즐겨찾기만 표시")
            
            // Sort menu
            Menu {
                ForEach(VideoSortOption.allCases, id: \.self) { option in
                    Button(action: { sortOption = option }) {
                        HStack {
                            Text(option.displayName)
                            if sortOption == option {
                                Image(systemName: "checkmark")
                            }
                        }
                    }
                }
            } label: {
                Image(systemName: "arrow.up.arrow.down")
            }
            .menuStyle(.borderlessButton)
            .frame(width: 30)
            
            // View mode
            Picker("", selection: $viewMode) {
                Image(systemName: "square.grid.2x2")
                    .tag(ViewMode.grid)
                Image(systemName: "list.bullet")
                    .tag(ViewMode.list)
            }
            .pickerStyle(.segmented)
            .frame(width: 80)
            
            // Add local video
            Button(action: { addLocalVideo() }) {
                Image(systemName: "plus")
            }
            .help("로컬 영상 추가")
        }
        .padding()
    }
    
    // MARK: - Grid View
    
    private var gridView: some View {
        ScrollView {
            LazyVGrid(columns: [
                GridItem(.adaptive(minimum: 160, maximum: 200), spacing: 16)
            ], spacing: 16) {
                ForEach(filteredVideos) { video in
                    VideoThumbnailView(video: video, isSelected: selectedVideo?.id == video.id)
                        .onTapGesture {
                            selectedVideo = video
                        }
                        .onTapGesture(count: 2) {
                            playVideo(video)
                        }
                        .contextMenu {
                            videoContextMenu(for: video)
                        }
                }
            }
            .padding()
        }
    }
    
    // MARK: - List View
    
    private var listView: some View {
        List(selection: $selectedVideo) {
            ForEach(filteredVideos) { video in
                VideoListRow(video: video)
                    .tag(video)
                    .onTapGesture(count: 2) {
                        playVideo(video)
                    }
                    .contextMenu {
                        videoContextMenu(for: video)
                    }
            }
        }
    }
    
    // MARK: - Empty State
    
    private var emptyState: some View {
        VStack(spacing: 16) {
            Image(systemName: "film.stack")
                .font(.system(size: 64))
                .foregroundColor(.secondary)
            
            Text(searchText.isEmpty ? "라이브러리가 비어있습니다" : "검색 결과 없음")
                .font(.title2)
                .foregroundColor(.secondary)
            
            if searchText.isEmpty {
                Text("스트리밍 모드에서 영상을 저장하거나\n로컬 영상 파일을 추가하세요")
                    .multilineTextAlignment(.center)
                    .foregroundColor(.secondary)
                
                Button("로컬 영상 추가") {
                    addLocalVideo()
                }
                .buttonStyle(.borderedProminent)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    
    // MARK: - Footer
    
    private var footer: some View {
        HStack {
            Text("\(filteredVideos.count)개 영상")
                .foregroundColor(.secondary)
            
            Text("•")
                .foregroundColor(.secondary)
            
            Text(formatStorageSize())
                .foregroundColor(.secondary)
            
            if showFavoritesOnly {
                Text("•")
                    .foregroundColor(.secondary)
                Text("⭐ \(libraryManager.videos.filter { $0.favorite }.count)개 즐겨찾기")
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            if let selected = selectedVideo {
                Button("배경화면으로 설정") {
                    playVideo(selected)
                    closeWindow()
                }
                .buttonStyle(.borderedProminent)
            }
            
            Button("닫기") {
                closeWindow()
            }
        }
        .padding()
    }
    
    // MARK: - Context Menu
    
    @ViewBuilder
    private func videoContextMenu(for video: VideoItem) -> some View {
        Button(action: { playVideo(video) }) {
            Label("배경화면으로 설정", systemImage: "play.fill")
        }
        
        Divider()
        
        Button(action: { toggleFavorite(video) }) {
            Label(video.favorite ? "즐겨찾기 해제" : "즐겨찾기 추가", systemImage: video.favorite ? "star.slash" : "star")
        }
        
        Button(action: { revealInFinder(video) }) {
            Label("Finder에서 보기", systemImage: "folder")
        }
        
        Divider()
        
        Button(role: .destructive, action: { deleteVideo(video) }) {
            Label("삭제", systemImage: "trash")
        }
    }
    
    // MARK: - Actions
    
    private func closeWindow() {
        if let onClose = onClose {
            onClose()
        } else {
            dismiss()
        }
    }
    
    private func playVideo(_ video: VideoItem) {
        playbackController.play(video: video)
    }
    
    private func toggleFavorite(_ video: VideoItem) {
        libraryManager.toggleFavorite(video)
    }
    
    private func revealInFinder(_ video: VideoItem) {
        NSWorkspace.shared.selectFile(video.localPath, inFileViewerRootedAtPath: "")
    }
    
    private func deleteVideo(_ video: VideoItem) {
        libraryManager.delete(video)
    }
    
    private func addLocalVideo() {
        let panel = NSOpenPanel()
        panel.canChooseFiles = true
        panel.canChooseDirectories = false
        panel.allowsMultipleSelection = true
        panel.allowedContentTypes = [.movie, .video, .mpeg4Movie, .quickTimeMovie]
        
        if panel.runModal() == .OK {
            for url in panel.urls {
                libraryManager.importVideo(from: url)
            }
        }
    }
    
    private func sortVideos(_ videos: [VideoItem], by option: VideoSortOption) -> [VideoItem] {
        switch option {
        case .savedAtDesc:
            return videos.sorted { $0.savedAt > $1.savedAt }
        case .savedAtAsc:
            return videos.sorted { $0.savedAt < $1.savedAt }
        case .nameAsc:
            return videos.sorted { $0.fileName < $1.fileName }
        case .nameDesc:
            return videos.sorted { $0.fileName > $1.fileName }
        case .playCountDesc:
            return videos.sorted { $0.playCount > $1.playCount }
        case .durationAsc:
            return videos.sorted { ($0.duration ?? 0) < ($1.duration ?? 0) }
        case .durationDesc:
            return videos.sorted { ($0.duration ?? 0) > ($1.duration ?? 0) }
        }
    }
    
    private func formatStorageSize() -> String {
        let totalSize = libraryManager.videos.compactMap { $0.fileSize }.reduce(0, +)
        let formatter = ByteCountFormatter()
        formatter.countStyle = .file
        return formatter.string(fromByteCount: totalSize)
    }
}

// MARK: - Video Thumbnail View

struct VideoThumbnailView: View {
    let video: VideoItem
    let isSelected: Bool
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Thumbnail
            ZStack {
                if let thumbnailURL = video.thumbnailURL,
                   let nsImage = NSImage(contentsOf: thumbnailURL) {
                    Image(nsImage: nsImage)
                        .resizable()
                        .aspectRatio(16/9, contentMode: .fill)
                        .clipped()
                } else {
                    Rectangle()
                        .fill(Color.secondary.opacity(0.3))
                        .aspectRatio(16/9, contentMode: .fit)
                        .overlay {
                            Image(systemName: "film")
                                .font(.largeTitle)
                                .foregroundColor(.secondary)
                        }
                }
                
                // Duration badge
                if let duration = video.duration {
                    VStack {
                        Spacer()
                        HStack {
                            Spacer()
                            Text(formatDuration(duration))
                                .font(.caption2)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(.black.opacity(0.7))
                                .foregroundColor(.white)
                                .cornerRadius(4)
                        }
                    }
                    .padding(8)
                }
                
                // Favorite indicator
                if video.favorite {
                    VStack {
                        HStack {
                            Image(systemName: "star.fill")
                                .foregroundColor(.yellow)
                                .font(.caption)
                            Spacer()
                        }
                        Spacer()
                    }
                    .padding(8)
                }
            }
            .cornerRadius(8)
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(isSelected ? Color.accentColor : Color.clear, lineWidth: 3)
            )
            
            // Title
            Text(video.prompt ?? video.fileName)
                .font(.caption)
                .lineLimit(2)
                .foregroundColor(.primary)
        }
        .frame(width: 160)
    }
    
    private func formatDuration(_ duration: Double) -> String {
        let minutes = Int(duration) / 60
        let seconds = Int(duration) % 60
        return String(format: "%d:%02d", minutes, seconds)
    }
}

// MARK: - Video List Row

struct VideoListRow: View {
    let video: VideoItem
    
    var body: some View {
        HStack(spacing: 12) {
            // Thumbnail
            ZStack {
                if let thumbnailURL = video.thumbnailURL,
                   let nsImage = NSImage(contentsOf: thumbnailURL) {
                    Image(nsImage: nsImage)
                        .resizable()
                        .aspectRatio(16/9, contentMode: .fill)
                        .frame(width: 80, height: 45)
                        .clipped()
                } else {
                    Rectangle()
                        .fill(Color.secondary.opacity(0.3))
                        .frame(width: 80, height: 45)
                        .overlay {
                            Image(systemName: "film")
                                .foregroundColor(.secondary)
                        }
                }
            }
            .cornerRadius(4)
            
            // Info
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    if video.favorite {
                        Image(systemName: "star.fill")
                            .foregroundColor(.yellow)
                            .font(.caption)
                    }
                    Text(video.prompt ?? video.fileName)
                        .lineLimit(1)
                }
                
                HStack(spacing: 8) {
                    if let author = video.author {
                        Text(author)
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    
                    Text(video.displayDuration)
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    Text(video.displayFileSize)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            
            Spacer()
            
            // Play count
            VStack(alignment: .trailing) {
                Text("\(video.playCount)회")
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                Text(video.savedAt, style: .date)
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
        }
        .padding(.vertical, 4)
    }
}

#Preview {
    LibraryBrowserView()
}
