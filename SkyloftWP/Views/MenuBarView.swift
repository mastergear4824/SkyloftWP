//
//  MenuBarView.swift
//  SkyloftWP
//
//  Menu bar dropdown UI - 심플하게 정리됨
//

import SwiftUI

struct MenuBarView: View {
    @StateObject private var configManager = ConfigurationManager.shared
    @StateObject private var wallpaperManager = WallpaperManager.shared
    @StateObject private var playbackController = PlaybackController.shared
    @StateObject private var libraryManager = LibraryManager.shared
    @StateObject private var localization = LocalizationManager.shared
    
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Header
            headerSection
            
            Divider()
                .padding(.vertical, 4)
            
            // Playback controls
            playbackControls
            
            Divider()
                .padding(.vertical, 4)
            
            // Streaming section
            streamingSection
            
            Divider()
                .padding(.vertical, 4)
            
            // App controls
            appControls
        }
        .padding(12)
        .frame(width: 260)
    }
    
    // MARK: - Header Section
    
    private var headerSection: some View {
        HStack {
            Image(systemName: "play.rectangle.fill")
                .font(.title2)
                .foregroundColor(.accentColor)
            
            VStack(alignment: .leading, spacing: 2) {
                Text("Skyloft WP")
                    .font(.headline)
                
                if let currentVideo = playbackController.currentVideo {
                    Text(currentVideo.prompt ?? currentVideo.fileName)
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .lineLimit(1)
                } else {
                    Text(L("menu.noVideo"))
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            
            Spacer()
            
            Circle()
                .fill(wallpaperManager.isPlaying ? Color.green : Color.gray)
                .frame(width: 8, height: 8)
        }
    }
    
    // MARK: - Playback Controls
    
    private var playbackControls: some View {
        VStack(spacing: 8) {
            // Controls
            HStack(spacing: 16) {
                Button(action: { playbackController.previous() }) {
                    Image(systemName: "backward.fill")
                        .font(.title3)
                }
                .buttonStyle(.plain)
                
                Button(action: { wallpaperManager.togglePlayPause() }) {
                    Image(systemName: wallpaperManager.isPaused ? "play.fill" : "pause.fill")
                        .font(.title2)
                }
                .buttonStyle(.plain)
                
                Button(action: { playbackController.next() }) {
                    Image(systemName: "forward.fill")
                        .font(.title3)
                }
                .buttonStyle(.plain)
            }
            .padding(.vertical, 4)
            
            Text("\(libraryManager.videos.count) " + L("menu.videosInLibrary"))
                .font(.caption)
                .foregroundColor(.secondary)
            
            Divider()
            
            // 음소거
            Button(action: { configManager.toggleMute() }) {
                HStack {
                    Image(systemName: configManager.config.behavior.muteAudio ? "speaker.slash.fill" : "speaker.wave.2.fill")
                        .frame(width: 20)
                    Text(configManager.config.behavior.muteAudio ? L("menu.unmute") : L("menu.mute"))
                    Spacer()
                }
            }
            .buttonStyle(.plain)
            
            // 현재 영상 숨기기
            if playbackController.currentVideo != nil {
                Button(action: { hideCurrentVideo() }) {
                    HStack {
                        Image(systemName: "hand.thumbsdown.fill")
                            .frame(width: 20)
                        Text(L("menu.hideCurrentVideo"))
                        Spacer()
                    }
                }
                .buttonStyle(.plain)
            }
        }
    }
    
    private func hideCurrentVideo() {
        guard let video = playbackController.currentVideo else { return }
        libraryManager.dislike(video)
        playbackController.next()  // 다음 영상으로
    }
    
    // MARK: - Streaming Section
    
    private var streamingSection: some View {
        VStack(spacing: 8) {
            // 스트리밍 연결 토글
            Button(action: { wallpaperManager.toggleStreamingConnection() }) {
                HStack {
                    Image(systemName: "antenna.radiowaves.left.and.right")
                        .frame(width: 20)
                        .foregroundColor(wallpaperManager.isStreamingConnected ? .green : .primary)
                    Text(L("menu.streamingConnection"))
                    Spacer()
                    
                    if wallpaperManager.isStreamingConnected {
                        HStack(spacing: 4) {
                            Circle()
                                .fill(Color.green)
                                .frame(width: 6, height: 6)
                            Text(L("menu.connected"))
                                .font(.caption)
                                .foregroundColor(.green)
                        }
                    } else {
                        Text(L("menu.disconnected"))
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
            }
            .buttonStyle(.plain)
            
            // 자동 저장 설정
            HStack {
                Text(L("menu.autoSaveCount"))
                    .font(.caption)
                    .foregroundColor(.secondary)
                Spacer()
                Text("\(configManager.config.streaming.autoSaveCount) " + L("menu.videos"))
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
    }
    
    // MARK: - App Controls
    
    private var appControls: some View {
        VStack(spacing: 8) {
            // 설정
            Button(action: { openSettings() }) {
                HStack {
                    Image(systemName: "gearshape.fill")
                        .frame(width: 20)
                    Text(L("menu.settings"))
                    Spacer()
                }
            }
            .buttonStyle(.plain)
            
            // 로그인 시 실행
            Button(action: { configManager.setAutoStart(!configManager.config.behavior.autoStart) }) {
                HStack {
                    Image(systemName: "power")
                        .frame(width: 20)
                    Text(L("menu.launchAtLogin"))
                    Spacer()
                    if configManager.config.behavior.autoStart {
                        Image(systemName: "checkmark")
                            .foregroundColor(.accentColor)
                    }
                }
            }
            .buttonStyle(.plain)
            
            Divider()
            
            // 종료
            Button(action: { NSApp.terminate(nil) }) {
                HStack {
                    Image(systemName: "xmark.circle.fill")
                        .frame(width: 20)
                    Text(L("menu.quit"))
                    Spacer()
                }
            }
            .buttonStyle(.plain)
        }
    }
    
    // MARK: - Actions
    
    private func openSettings() {
        AppDelegate.shared?.openMainWindow()
    }
}

#Preview {
    MenuBarView()
}
