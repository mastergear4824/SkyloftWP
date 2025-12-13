//
//  MainWindowView.swift
//  AIStreamWallpaper
//
//  통합 메인 윈도우 - 라이브러리와 설정을 하나로
//

import SwiftUI

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
                    Text("AI Stream Wallpaper")
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
                    Link("mastergear@aiclude.com", destination: URL(string: "mailto:mastergear@aiclude.com")!)
                        .foregroundColor(.accentColor)
                }
            }
            .padding()
            .background(Color(NSColor.controlBackgroundColor))
            .cornerRadius(12)
        }
    }
    
    private var libraryInfoSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Label(L("general.librarySize"), systemImage: "folder.fill")
                .font(.headline)
            
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Text(L("library.videos"))
                    Spacer()
                    Text("\(libraryManager.videos.count)")
                        .font(.title3.bold())
                        .foregroundColor(.accentColor)
                }
                
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
    
    // 최신순으로 정렬된 비디오 목록
    private var sortedVideos: [VideoItem] {
        libraryManager.videos.sorted { $0.savedAt > $1.savedAt }
    }
    
    var body: some View {
        VStack(spacing: 0) {
            // 비디오 그리드
            if sortedVideos.isEmpty {
                emptyState
            } else {
                ScrollView {
                    LazyVGrid(columns: [
                        GridItem(.adaptive(minimum: 200, maximum: 250), spacing: 16)
                    ], spacing: 16) {
                        ForEach(sortedVideos) { video in
                            VideoCard(
                                video: video,
                                isPlaying: playbackController.currentVideo?.id == video.id,
                                onPlay: { playVideo(video) },
                                onDelete: { deleteVideo(video) }
                            )
                        }
                    }
                    .padding()
                }
            }
            
            Divider()
            
            // 하단 상태바
            HStack {
                Text("\(sortedVideos.count) " + L("library.videos"))
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                Spacer()
                
                if let current = playbackController.currentVideo {
                    HStack(spacing: 4) {
                        Image(systemName: "play.fill")
                            .foregroundColor(.green)
                        Text(current.prompt ?? current.fileName)
                            .font(.caption)
                            .lineLimit(1)
                    }
                }
            }
            .padding(.horizontal)
            .padding(.vertical, 8)
            .background(Color(NSColor.windowBackgroundColor))
        }
    }
    
    private var emptyState: some View {
        VStack(spacing: 16) {
            Image(systemName: "film.stack")
                .font(.system(size: 48))
                .foregroundColor(.secondary)
            
            Text(L("library.empty"))
                .font(.headline)
            
            Text(L("library.emptyTip"))
                .font(.caption)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
            
            if !wallpaperManager.isStreamingConnected {
                Button(action: { wallpaperManager.toggleStreamingConnection() }) {
                    Label(L("library.enableStreaming"), systemImage: "antenna.radiowaves.left.and.right")
                }
                .buttonStyle(.borderedProminent)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    
    private func playVideo(_ video: VideoItem) {
        playbackController.play(video: video)
    }
    
    private func deleteVideo(_ video: VideoItem) {
        libraryManager.delete(video)
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
    
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // 썸네일
            ZStack {
                if let thumbnailPath = video.thumbnailPath,
                   let image = NSImage(contentsOfFile: thumbnailPath) {
                    Image(nsImage: image)
                        .resizable()
                        .aspectRatio(16/9, contentMode: .fill)
                } else {
                    Rectangle()
                        .fill(Color.gray.opacity(0.3))
                        .aspectRatio(16/9, contentMode: .fill)
                        .overlay(
                            Image(systemName: "film")
                                .font(.largeTitle)
                                .foregroundColor(.secondary)
                        )
                }
                
                // 재생 중 표시
                if isPlaying {
                    Rectangle()
                        .fill(Color.green.opacity(0.3))
                    
                    Image(systemName: "play.fill")
                        .font(.title)
                        .foregroundColor(.white)
                }
                
                // 호버 오버레이
                if isHovering && !isPlaying {
                    Rectangle()
                        .fill(Color.black.opacity(0.5))
                    
                    Button(action: onPlay) {
                        Image(systemName: "play.fill")
                            .font(.title)
                            .foregroundColor(.white)
                    }
                    .buttonStyle(.plain)
                }
            }
            .frame(height: 120)
            .clipped()
            .cornerRadius(8)
            
            // 정보
            VStack(alignment: .leading, spacing: 4) {
                Text(video.prompt ?? video.fileName)
                    .font(.caption)
                    .lineLimit(2)
                    .foregroundColor(.primary)
                
                Text(video.savedAt.formatted(date: .abbreviated, time: .shortened))
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
            .padding(.horizontal, 4)
            .padding(.vertical, 8)
        }
        .background(Color(NSColor.controlBackgroundColor))
        .cornerRadius(10)
        .shadow(color: isPlaying ? .green.opacity(0.3) : .black.opacity(0.1), radius: isPlaying ? 8 : 4)
        .onHover { isHovering = $0 }
        .contextMenu {
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
            
            // 미드저니에서 열기
            if midjourneyJobURL != nil {
                Button(action: openInMidjourney) {
                    Label(L("library.openInMidjourney"), systemImage: "safari")
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
    
    // Midjourney job URL 추출
    private var midjourneyJobURL: URL? {
        guard let sourceUrl = video.sourceUrl else { return nil }
        
        // URL 형식: https://cdn.midjourney.com/video/{UUID}/0.mp4
        // 변환: https://www.midjourney.com/jobs/{UUID}
        if let url = URL(string: sourceUrl),
           let uuidIndex = url.pathComponents.firstIndex(of: "video"),
           uuidIndex + 1 < url.pathComponents.count {
            let uuid = url.pathComponents[uuidIndex + 1]
            return URL(string: "https://www.midjourney.com/jobs/\(uuid)")
        }
        return nil
    }
    
    private func copyPrompt() {
        if let prompt = video.prompt {
            NSPasteboard.general.clearContents()
            NSPasteboard.general.setString(prompt, forType: .string)
        }
    }
    
    private func openInMidjourney() {
        if let url = midjourneyJobURL {
            NSWorkspace.shared.open(url)
        }
    }
    
    private func showInFinder() {
        let url = URL(fileURLWithPath: video.localPath)
        NSWorkspace.shared.activateFileViewerSelecting([url])
    }
    
    private func dislikeVideo() {
        libraryManager.dislike(video)
    }
}

#Preview {
    MainWindowView()
}

