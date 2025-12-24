//
//  MiniControlsView.swift
//  SkyloftWP
//
//  Floating mini controller panel with glass effect
//

import SwiftUI

struct MiniControlsView: View {
    @StateObject private var wallpaperManager = WallpaperManager.shared
    @StateObject private var configManager = ConfigurationManager.shared
    @StateObject private var playbackController = PlaybackController.shared
    
    @State private var isHovered = false
    
    var body: some View {
        HStack(spacing: 12) {
            // Previous
            ControlButton(icon: "backward.fill", action: { playbackController.previous() })
                .help(L("menu.previous"))
            
            // Play/Pause
            ControlButton(
                icon: wallpaperManager.isPaused ? "play.fill" : "pause.fill",
                action: { wallpaperManager.togglePlayPause() }
            )
            .help(L("menu.play") + "/" + L("menu.pause"))
            
            // Next
            ControlButton(icon: "forward.fill", action: { playbackController.next() })
                .help(L("menu.next"))
            
            Divider()
                .frame(height: 20)
            
            // Save
            ControlButton(icon: "square.and.arrow.down", action: {
                Task { await wallpaperManager.saveCurrentVideo() }
            })
            .help(L("menu.saveVideo"))
            
            // Mute
            ControlButton(
                icon: configManager.config.behavior.muteAudio ? "speaker.slash.fill" : "speaker.wave.2.fill",
                action: { configManager.toggleMute() }
            )
            .help(configManager.config.behavior.muteAudio ? L("menu.unmute") : L("menu.mute"))
            
            // Close
            ControlButton(icon: "xmark", size: 10, action: {
                AppDelegate.shared?.toggleControlsWindow()
            })
            .opacity(isHovered ? 1 : 0.5)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(.ultraThinMaterial)
                .shadow(color: .black.opacity(0.2), radius: 10, x: 0, y: 5)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .strokeBorder(Color.white.opacity(0.2), lineWidth: 0.5)
        )
        .onHover { hovering in
            withAnimation(.easeInOut(duration: 0.2)) {
                isHovered = hovering
            }
        }
    }
}

struct ControlButton: View {
    let icon: String
    var size: CGFloat = 14
    let action: () -> Void
    
    @State private var isPressed = false
    
    var body: some View {
        Button(action: action) {
            Image(systemName: icon)
                .font(.system(size: size, weight: .medium))
                .foregroundColor(.primary)
                .frame(width: 28, height: 28)
                .background(
                    Circle()
                        .fill(isPressed ? Color.primary.opacity(0.2) : Color.clear)
                )
                .contentShape(Circle())
        }
        .buttonStyle(.plain)
        .onHover { hovering in
            withAnimation(.easeInOut(duration: 0.15)) {
                isPressed = hovering
            }
        }
    }
}

#Preview {
    MiniControlsView()
        .padding()
        .background(Color.gray.opacity(0.5))
}



