//
//  MainWindowView.swift
//  SkyloftWP
//
//  통합 메인 윈도우 - 라이브러리와 설정을 하나로
//

import SwiftUI
import UniformTypeIdentifiers
import AVFoundation

enum MainWindowTab: String, CaseIterable {
    case library = "library"
    case streaming = "streaming"
    case display = "display"
    case general = "general"
    case about = "about"
    
    var icon: String {
        switch self {
        case .library: return "rectangle.stack.fill"
        case .streaming: return "antenna.radiowaves.left.and.right"
        case .display: return "sun.max.fill"
        case .general: return "gearshape.fill"
        case .about: return "info.circle.fill"
        }
    }
    
    var title: String {
        switch self {
        case .library: return L("main.library")
        case .streaming: return L("main.streaming")
        case .display: return L("main.display")
        case .general: return L("main.general")
        case .about: return L("general.about")
        }
    }
}

struct MainWindowView: View {
    @State private var selectedTab: MainWindowTab = .library
    @StateObject private var libraryManager = LibraryManager.shared
    @StateObject private var wallpaperManager = WallpaperManager.shared
    
    var body: some View {
        NavigationSplitView {
            // 사이드바
            List(selection: $selectedTab) {
                Section {
                    sidebarItem(.library)
                } header: {
                    Text(L("main.content"))
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                Section {
                    sidebarItem(.streaming)
                    sidebarItem(.display)
                    sidebarItem(.general)
                    sidebarItem(.about)
                } header: {
                    Text(L("main.settings"))
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            .listStyle(.sidebar)
            .frame(minWidth: 180)
        } detail: {
            // 상세 뷰
            detailView
                .frame(minWidth: 500, minHeight: 400)
        }
        .frame(minWidth: 750, minHeight: 500)
    }
    
    @ViewBuilder
    private func sidebarItem(_ tab: MainWindowTab) -> some View {
        Label {
            HStack {
                Text(tab.title)
                Spacer()
                if tab == .library {
                    Text("\(libraryManager.videos.count)")
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(Color.secondary.opacity(0.2))
                        .cornerRadius(4)
                }
                if tab == .streaming && wallpaperManager.isStreamingConnected {
                    Circle()
                        .fill(Color.green)
                        .frame(width: 6, height: 6)
                }
            }
        } icon: {
            Image(systemName: tab.icon)
        }
        .tag(tab)
    }
    
    @ViewBuilder
    private var detailView: some View {
        switch selectedTab {
        case .library:
            LibraryContentView()
        case .streaming:
            StreamingSettingsView()
        case .display:
            DisplaySettingsView()
        case .general:
            GeneralSettingsView()
        case .about:
            AboutSettingsView()
        }
    }
}

// MARK: - About Settings View (정보 뷰)

struct AboutSettingsView: View {
    @StateObject private var libraryManager = LibraryManager.shared
    @State private var showClearConfirmation = false
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                // 앱 정보
                appInfoSection
                
                Divider()
                
                // 라이브러리 정보
                libraryInfoSection
                
                Divider()
                
                // 관리
                managementSection
            }
            .padding(24)
        }
        .alert(L("general.clearLibraryConfirm"), isPresented: $showClearConfirmation) {
            Button(L("common.cancel"), role: .cancel) {}
            Button(L("general.clearLibrary"), role: .destructive) {
                libraryManager.clearAll()
            }
        } message: {
            Text(L("general.clearLibraryWarning"))
        }
    }
    
    private var appInfoSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(spacing: 16) {
                Image(nsImage: NSApp.applicationIconImage)
                    .resizable()
                    .frame(width: 64, height: 64)
                
                VStack(alignment: .leading, spacing: 4) {
                    Text("Skyloft WP")
                        .font(.title2.bold())
                    
                    Text(L("general.version") + " " + (Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0"))
                        .font(.body)
                        .foregroundColor(.secondary)
                    
                    Text(L("about.description"))
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
            }
            .padding()
            .background(Color(NSColor.controlBackgroundColor))
            .cornerRadius(12)
            
            // 제작자 정보
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Text(L("about.developer"))
                        .foregroundColor(.secondary)
                    Spacer()
                    Text("Mastergear (Keunjin Kim)")
                        .fontWeight(.medium)
                }
                
                Divider()
                
                HStack {
                    Text(L("about.contact"))
                        .foregroundColor(.secondary)
                    Spacer()
                    Link("Facebook", destination: URL(string: "https://www.facebook.com/keunjinkim00")!)
                        .foregroundColor(.accentColor)
                }
            }
            .padding()
            .background(Color(NSColor.controlBackgroundColor))
            .cornerRadius(12)
            
            // 후원 섹션
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Image(systemName: "cup.and.saucer.fill")
                        .foregroundColor(.yellow)
                    Text(L("about.support"))
                        .fontWeight(.medium)
                }
                
                Text(L("about.supportDescription"))
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                Divider()
                
                Link(destination: URL(string: "https://www.buymeacoffee.com/keunjin.kim")!) {
                    HStack {
                        AsyncImage(url: URL(string: "https://img.buymeacoffee.com/button-api/?text=Buy%20me%20a%20coffee&emoji=&slug=keunjin.kim&button_colour=FFDD00&font_colour=000000&font_family=Cookie&outline_colour=000000&coffee_colour=ffffff")) { phase in
                            switch phase {
                            case .success(let image):
                                image
                                    .resizable()
                                    .aspectRatio(contentMode: .fit)
                                    .frame(height: 40)
                            case .failure(_):
                                buyMeCoffeeTextView
                            case .empty:
                                buyMeCoffeeTextView
                            @unknown default:
                                buyMeCoffeeTextView
                            }
                        }
                        Spacer()
                        Image(systemName: "arrow.up.right.square")
                            .foregroundColor(.secondary)
                    }
                }
                .buttonStyle(.plain)
            }
            .padding()
            .background(Color(NSColor.controlBackgroundColor))
            .cornerRadius(12)
        }
    }
    
    private var buyMeCoffeeTextView: some View {
        HStack {
            Image(systemName: "heart.fill")
                .foregroundColor(.pink)
            Text("Buy Me a Coffee")
                .fontWeight(.medium)
        }
    }
    
    private var libraryInfoSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Label(L("general.librarySize"), systemImage: "folder.fill")
                .font(.headline)
            
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Text(L("general.storageUsed"))
                    Spacer()
                    Text(libraryManager.totalStorageUsed)
                        .font(.title3.bold())
                        .foregroundColor(.accentColor)
                }
                
                HStack {
                    Text(L("about.hiddenVideos"))
                    Spacer()
                    Text("\(libraryManager.dislikedCount)")
                        .foregroundColor(.secondary)
                }
            }
            .padding()
            .background(Color(NSColor.controlBackgroundColor))
            .cornerRadius(12)
        }
    }
    
    private var managementSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Label(L("about.management"), systemImage: "wrench.fill")
                .font(.headline)
            
            VStack(alignment: .leading, spacing: 12) {
                Button(action: { libraryManager.clearDisliked() }) {
                    HStack {
                        Image(systemName: "eye")
                        Text(L("about.restoreHidden"))
                        Spacer()
                    }
                }
                .buttonStyle(.plain)
                .disabled(libraryManager.dislikedCount == 0)
                
                Divider()
                
                Button(role: .destructive, action: { showClearConfirmation = true }) {
                    HStack {
                        Image(systemName: "trash")
                        Text(L("general.clearLibrary"))
                        Spacer()
                    }
                }
                .buttonStyle(.plain)
            }
            .padding()
            .background(Color(NSColor.controlBackgroundColor))
            .cornerRadius(12)
        }
    }
}

// MARK: - Library Content View (라이브러리 전용 뷰)

struct LibraryContentView: View {
    @StateObject private var libraryManager = LibraryManager.shared
    @StateObject private var playbackController = PlaybackController.shared
    @StateObject private var wallpaperManager = WallpaperManager.shared
    
    @State private var selectedVideo: VideoItem?
    @State private var isDropTargeted = false
    @State private var importProgress: String?
    
    // 오래된 순으로 정렬된 비디오 목록 (재생 순서와 일치)
    private var sortedVideos: [VideoItem] {
        libraryManager.videos  // 이미 LibraryManager에서 오래된 순으로 정렬됨
    }
    
    var body: some View {
        VStack(spacing: 0) {
            // 상단 툴바
            HStack(spacing: 12) {
                Button(action: addVideos) {
                    Label("Add Videos", systemImage: "plus.circle.fill")
                }
                .buttonStyle(.borderedProminent)
                
                Spacer()
                
                Text("\(sortedVideos.count) videos")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            .padding(.horizontal)
            .padding(.vertical, 10)
            .background(Color(NSColor.windowBackgroundColor))
            
            Divider()
            
            // 비디오 그리드
            if sortedVideos.isEmpty {
                emptyState
            } else {
                ScrollView {
                    LazyVGrid(columns: [
                        GridItem(.flexible(), spacing: 8),
                        GridItem(.flexible(), spacing: 8),
                        GridItem(.flexible(), spacing: 8)
                    ], spacing: 8) {
                        ForEach(sortedVideos) { video in
                            VideoCard(
                                video: video,
                                isPlaying: playbackController.currentVideo?.id == video.id,
                                onPlay: { playVideo(video) },
                                onDelete: { deleteVideo(video) }
                            )
                            .id(video.id)  // 고유 ID로 재사용 방지
                        }
                    }
                    .padding(8)
                }
                .onAppear {
                    libraryManager.loadLibrary()
                }
            }
            
            Divider()
            
            // 하단 상태바
            HStack {
                if let current = playbackController.currentVideo {
                    HStack(spacing: 4) {
                        Image(systemName: "play.fill")
                            .foregroundColor(.green)
                        Text(current.prompt ?? current.fileName)
                            .font(.caption)
                            .lineLimit(1)
                    }
                }
                
                Spacer()
            }
            .padding(.horizontal)
            .padding(.vertical, 8)
            .background(Color(NSColor.windowBackgroundColor))
        }
        // 드래그 앤 드롭
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
    
    private var emptyState: some View {
        VStack(spacing: 16) {
            Image(systemName: "film.stack")
                .font(.system(size: 48))
                .foregroundColor(.secondary)
            
            Text(L("library.empty"))
                .font(.headline)
            
            Text("Add videos or enable streaming to get started")
                .font(.caption)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
            
            HStack(spacing: 16) {
                Button(action: addVideos) {
                    Label("Add Videos", systemImage: "plus.circle.fill")
                }
                .buttonStyle(.borderedProminent)
                
                if !wallpaperManager.isStreamingConnected {
                    Button(action: { wallpaperManager.toggleStreamingConnection() }) {
                        Label("Enable Streaming", systemImage: "antenna.radiowaves.left.and.right")
                    }
                    .buttonStyle(.bordered)
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    
    // MARK: - Actions
    
    private func playVideo(_ video: VideoItem) {
        playbackController.play(video: video)
    }
    
    private func deleteVideo(_ video: VideoItem) {
        libraryManager.delete(video)
    }
    
    private func addVideos() {
        let panel = NSOpenPanel()
        panel.canChooseFiles = true
        panel.canChooseDirectories = true
        panel.allowsMultipleSelection = true
        panel.allowedContentTypes = [.movie, .video, .mpeg4Movie, .quickTimeMovie, .folder]
        panel.message = "Select video files or folders"
        
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
                try? await Task.sleep(nanoseconds: 100_000_000)
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
            provider.loadItem(forTypeIdentifier: UTType.fileURL.identifier, options: nil) { item, _ in
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
}

// MARK: - Video Card

struct VideoCard: View {
    let video: VideoItem
    let isPlaying: Bool
    let onPlay: () -> Void
    let onDelete: () -> Void
    
    @StateObject private var libraryManager = LibraryManager.shared
    @State private var isHovering = false
    @State private var thumbnailImage: NSImage?
    @State private var isGeneratingThumbnail = false
    
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // 썸네일 (16:9)
            thumbnailView
                .aspectRatio(16/9, contentMode: .fit)
                .clipped()
                .cornerRadius(6)
            
            // 정보
            VStack(alignment: .leading, spacing: 2) {
                Text(video.prompt ?? video.fileName)
                    .font(.caption)
                    .lineLimit(1)
                    .foregroundColor(.primary)
                
                Text(video.savedAt.formatted(date: .abbreviated, time: .shortened))
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
            .padding(6)
        }
        .background(Color(NSColor.controlBackgroundColor))
        .cornerRadius(8)
        .shadow(color: isPlaying ? .green.opacity(0.3) : .black.opacity(0.1), radius: isPlaying ? 6 : 2)
        .onHover { isHovering = $0 }
        .contextMenu { contextMenuItems }
        .onAppear { loadThumbnailForVideo() }
    }
    
    private func loadThumbnailForVideo() {
        // 매번 새로 로드 (캐시 문제 방지)
        thumbnailImage = nil
        if let path = video.thumbnailPath {
            thumbnailImage = NSImage(contentsOfFile: path)
        }
        if thumbnailImage == nil {
            generateThumbnailIfNeeded()
        }
    }
    
    @ViewBuilder
    private var thumbnailView: some View {
        ZStack {
            Rectangle().fill(Color.gray.opacity(0.3))
            
            if let image = thumbnailImage {
                Image(nsImage: image)
                    .resizable()
                    .scaledToFill()
            } else if isGeneratingThumbnail {
                ProgressView().scaleEffect(0.8)
            } else {
                Image(systemName: "film")
                    .font(.title)
                    .foregroundColor(.secondary)
            }
            
            // 재생 중 표시
            if isPlaying {
                Color.green.opacity(0.3)
                Image(systemName: "play.fill").font(.title).foregroundColor(.white)
            }
            
            // 호버 오버레이
            if isHovering && !isPlaying {
                Color.black.opacity(0.5)
                Button(action: onPlay) {
                    Image(systemName: "play.fill").font(.title).foregroundColor(.white)
                }
                .buttonStyle(.plain)
            }
        }
    }
    
    // MARK: - Context Menu
    
    private var contextMenuItems: some View {
        Group {
            // 배경화면으로 설정
            Button(action: onPlay) {
                Label(L("library.setAsWallpaper"), systemImage: "play.fill")
            }
            
            // 프롬프트 복사
            if video.prompt != nil {
                Button(action: copyPrompt) {
                    Label(L("library.copyPrompt"), systemImage: "doc.on.clipboard")
                }
            }
            
            Divider()
            
            // Finder에서 보기
            Button(action: showInFinder) {
                Label(L("library.showInFinder"), systemImage: "folder")
            }
            
            Divider()
            
            // 싫어요 (숨김 처리)
            Button(action: dislikeVideo) {
                Label(L("library.dislike"), systemImage: "hand.thumbsdown")
            }
            
            // 삭제
            Button(role: .destructive, action: onDelete) {
                Label(L("library.delete"), systemImage: "trash")
            }
        }
    }
    
    private func copyPrompt() {
        if let prompt = video.prompt {
            NSPasteboard.general.clearContents()
            NSPasteboard.general.setString(prompt, forType: .string)
        }
    }
    
    private func showInFinder() {
        let url = URL(fileURLWithPath: video.localPath)
        NSWorkspace.shared.activateFileViewerSelecting([url])
    }
    
    private func dislikeVideo() {
        libraryManager.dislike(video)
    }
    
    private func generateThumbnailIfNeeded() {
        guard video.thumbnailPath == nil else { return }
        guard !isGeneratingThumbnail else { return }
        
        isGeneratingThumbnail = true
        
        Task {
            do {
                let videoURL = URL(fileURLWithPath: video.localPath)
                let thumbnailPath = try await ThumbnailGenerator.shared.generateThumbnail(
                    for: videoURL,
                    videoId: video.id
                )
                
                await MainActor.run {
                    LibraryManager.shared.updateVideoMetadata(
                        videoId: video.id,
                        duration: video.duration ?? 0,
                        resolution: video.resolution ?? "Unknown",
                        thumbnailPath: thumbnailPath
                    )
                    
                    if let image = NSImage(contentsOfFile: thumbnailPath) {
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

#Preview {
    MainWindowView()
}

