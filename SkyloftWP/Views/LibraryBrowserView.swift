//
//  LibraryBrowserView.swift
//  SkyloftWP
//
//  Video library browser window
//

import SwiftUI
import UniformTypeIdentifiers

struct LibraryBrowserView: View {
    @StateObject private var libraryManager = LibraryManager.shared
    @StateObject private var playbackController = PlaybackController.shared
    
    @State private var searchText = ""
    @State private var viewMode: ViewMode = .grid
    @State private var sortOption: VideoSortOption = .savedAtDesc
    @State private var showFavoritesOnly = false
    @State private var selectedVideo: VideoItem?
    @State private var showingDeleteConfirmation = false
    @State private var isDropTargeted = false
    @State private var importProgress: String?
    
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
        // 파일이 존재하는 것만 필터링
        var videos = libraryManager.videos.filter { 
            FileManager.default.fileExists(atPath: $0.localPath) 
        }
        
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
        // 드래그 앤 드롭 지원
        .onDrop(of: [.fileURL, .movie, .video], isTargeted: $isDropTargeted) { providers in
            handleDrop(providers: providers)
            return true
        }
        .overlay {
            if isDropTargeted {
                ZStack {
                    Color.accentColor.opacity(0.2)
                    VStack(spacing: 12) {
                        Image(systemName: "square.and.arrow.down")
                            .font(.system(size: 48))
                        Text("Drop videos here")
                            .font(.title2)
                    }
                    .foregroundColor(.accentColor)
                }
                .cornerRadius(12)
                .padding()
            }
            
            if let progress = importProgress {
                VStack {
                    ProgressView()
                    Text(progress)
                        .font(.caption)
                }
                .padding()
                .background(.regularMaterial)
                .cornerRadius(8)
            }
        }
    }
    
    // MARK: - Toolbar
    
    private var toolbar: some View {
        HStack(spacing: 12) {
            // Add video button (prominent)
            Button(action: { addLocalVideo() }) {
                Label("Add Videos", systemImage: "plus.circle.fill")
            }
            .buttonStyle(.borderedProminent)
            .help("Add videos from files or folders")
            
            Divider()
                .frame(height: 20)
            
            // Search
            HStack {
                Image(systemName: "magnifyingglass")
                    .foregroundColor(.secondary)
                TextField("Search...", text: $searchText)
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
            .frame(maxWidth: 200)
            
            Spacer()
            
            // Favorites filter
            Button(action: { showFavoritesOnly.toggle() }) {
                Image(systemName: showFavoritesOnly ? "star.fill" : "star")
                    .foregroundColor(showFavoritesOnly ? .yellow : .secondary)
            }
            .buttonStyle(.plain)
            .help("Show favorites only")
            
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
        }
        .padding()
    }
    
    // MARK: - Grid View
    
    private var gridView: some View {
        ScrollView {
            LazyVGrid(columns: [
                GridItem(.adaptive(minimum: 180, maximum: 220), spacing: 20)
            ], alignment: .leading, spacing: 20) {
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
            .padding(20)
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
            
            Text(searchText.isEmpty ? "Library is empty" : "No results found")
                .font(.title2)
                .foregroundColor(.secondary)
            
            if searchText.isEmpty {
                Text("Add videos from your computer or\nsave videos from streaming mode")
                    .multilineTextAlignment(.center)
                    .foregroundColor(.secondary)
                
                HStack(spacing: 16) {
                    Button {
                        addLocalVideo()
                    } label: {
                        Label("Add Videos", systemImage: "plus.circle.fill")
                    }
                    .buttonStyle(.borderedProminent)
                    
                    Button {
                        addFromFolder()
                    } label: {
                        Label("Add Folder", systemImage: "folder.badge.plus")
                    }
                    .buttonStyle(.bordered)
                }
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
        panel.canChooseDirectories = true
        panel.allowsMultipleSelection = true
        panel.allowedContentTypes = [.movie, .video, .mpeg4Movie, .quickTimeMovie, .folder]
        panel.message = "Select video files or a folder containing videos"
        
        if panel.runModal() == .OK {
            importURLs(panel.urls)
        }
    }
    
    private func addFromFolder() {
        let panel = NSOpenPanel()
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.allowsMultipleSelection = true
        panel.message = "Select folders containing videos"
        
        if panel.runModal() == .OK {
            importURLs(panel.urls)
        }
    }
    
    private func importURLs(_ urls: [URL]) {
        var videoURLs: [URL] = []
        
        for url in urls {
            var isDirectory: ObjCBool = false
            if FileManager.default.fileExists(atPath: url.path, isDirectory: &isDirectory) {
                if isDirectory.boolValue {
                    // 폴더인 경우 내부 비디오 파일 수집
                    if let enumerator = FileManager.default.enumerator(
                        at: url,
                        includingPropertiesForKeys: [.isRegularFileKey],
                        options: [.skipsHiddenFiles]
                    ) {
                        for case let fileURL as URL in enumerator {
                            if isVideoFile(fileURL) {
                                videoURLs.append(fileURL)
                            }
                        }
                    }
                } else if isVideoFile(url) {
                    videoURLs.append(url)
                }
            }
        }
        
        guard !videoURLs.isEmpty else { return }
        
        importProgress = "Importing \(videoURLs.count) videos..."
        
        Task {
            for (index, url) in videoURLs.enumerated() {
                await MainActor.run {
                    importProgress = "Importing \(index + 1)/\(videoURLs.count)..."
                }
                libraryManager.importVideo(from: url)
                try? await Task.sleep(nanoseconds: 100_000_000) // 0.1초 딜레이
            }
            await MainActor.run {
                importProgress = nil
            }
        }
    }
    
    private func isVideoFile(_ url: URL) -> Bool {
        let videoExtensions = ["mp4", "mov", "m4v", "avi", "mkv", "webm"]
        return videoExtensions.contains(url.pathExtension.lowercased())
    }
    
    private func handleDrop(providers: [NSItemProvider]) {
        var urls: [URL] = []
        let group = DispatchGroup()
        
        for provider in providers {
            group.enter()
            provider.loadItem(forTypeIdentifier: UTType.fileURL.identifier, options: nil) { item, error in
                defer { group.leave() }
                
                if let data = item as? Data,
                   let url = URL(dataRepresentation: data, relativeTo: nil) {
                    urls.append(url)
                } else if let url = item as? URL {
                    urls.append(url)
                }
            }
        }
        
        group.notify(queue: .main) {
            self.importURLs(urls)
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
    
    @State private var thumbnailImage: NSImage?
    @State private var isGeneratingThumbnail = false
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Thumbnail
            GeometryReader { geometry in
                ZStack {
                    if let image = thumbnailImage {
                        Image(nsImage: image)
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                            .frame(width: geometry.size.width, height: geometry.size.width * 9 / 16)
                            .clipped()
                    } else if let thumbnailURL = video.thumbnailURL,
                              let nsImage = NSImage(contentsOf: thumbnailURL) {
                        Image(nsImage: nsImage)
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                            .frame(width: geometry.size.width, height: geometry.size.width * 9 / 16)
                            .clipped()
                            .onAppear {
                                thumbnailImage = nsImage
                            }
                    } else {
                        Rectangle()
                            .fill(Color.secondary.opacity(0.3))
                            .frame(width: geometry.size.width, height: geometry.size.width * 9 / 16)
                            .overlay {
                                if isGeneratingThumbnail {
                                    ProgressView()
                                        .scaleEffect(0.8)
                                } else {
                                    Image(systemName: "film")
                                        .font(.largeTitle)
                                        .foregroundColor(.secondary)
                                }
                            }
                            .onAppear {
                                generateThumbnailIfNeeded()
                            }
                    }
                    
                    // Play icon overlay
                    Image(systemName: "play.circle.fill")
                        .font(.system(size: 32))
                        .foregroundColor(.white.opacity(0.8))
                        .shadow(radius: 2)
                    
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
                .frame(width: geometry.size.width, height: geometry.size.width * 9 / 16)
            }
            .aspectRatio(16/9, contentMode: .fit)
            .cornerRadius(8)
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(isSelected ? Color.accentColor : Color.clear, lineWidth: 3)
            )
            
            // Info
            VStack(alignment: .leading, spacing: 2) {
                Text(video.prompt ?? video.fileName)
                    .font(.caption)
                    .fontWeight(.medium)
                    .lineLimit(2)
                    .foregroundColor(.primary)
                
                Text(video.savedAt, style: .date)
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
        }
    }
    
    private func formatDuration(_ duration: Double) -> String {
        let minutes = Int(duration) / 60
        let seconds = Int(duration) % 60
        return String(format: "%d:%02d", minutes, seconds)
    }
    
    private func generateThumbnailIfNeeded() {
        guard video.thumbnailPath == nil || video.thumbnailURL == nil else { return }
        guard !isGeneratingThumbnail else { return }
        
        isGeneratingThumbnail = true
        
        Task {
            do {
                let videoURL = URL(fileURLWithPath: video.localPath)
                let thumbnailPath = try await ThumbnailGenerator.shared.generateThumbnail(
                    for: videoURL,
                    videoId: video.id
                )
                
                // Update library
                await MainActor.run {
                    LibraryManager.shared.updateVideoMetadata(
                        videoId: video.id,
                        duration: video.duration ?? 0,
                        resolution: video.resolution ?? "Unknown",
                        thumbnailPath: thumbnailPath
                    )
                    
                    // Load thumbnail
                    let fileURL = URL(fileURLWithPath: thumbnailPath)
                    if let image = NSImage(contentsOf: fileURL) {
                        thumbnailImage = image
                    }
                    isGeneratingThumbnail = false
                }
            } catch {
                await MainActor.run {
                    isGeneratingThumbnail = false
                }
                print("Failed to generate thumbnail: \(error)")
            }
        }
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
