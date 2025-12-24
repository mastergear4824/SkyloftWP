//
//  ShortcutSettingsView.swift
//  SkyloftWP
//
//  단축키 설정
//

import SwiftUI
import Carbon

struct ShortcutSettingsView: View {
    @StateObject private var configManager = ConfigurationManager.shared
    
    @State private var showingPermissionAlert = false
    
    private var hasPermission: Bool {
        HotkeyManager.hasAccessibilityPermission
    }
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                // 권한 상태
                permissionSection
                
                Divider()
                
                // 단축키 목록
                shortcutsSection
                
                Divider()
                
                // 팁
                tipSection
            }
            .padding(24)
        }
        .alert(L("shortcuts.permissionRequired"), isPresented: $showingPermissionAlert) {
            Button(L("shortcuts.openSettings")) {
                NSWorkspace.shared.open(URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility")!)
            }
            Button(L("common.cancel"), role: .cancel) {}
        } message: {
            Text(L("shortcuts.permissionMessage"))
        }
    }
    
    // MARK: - Permission Section
    
    private var permissionSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Label(L("shortcuts.accessibilityPermission"), systemImage: "hand.raised.fill")
                .font(.headline)
            
            HStack(spacing: 16) {
                HStack(spacing: 8) {
                    Image(systemName: hasPermission ? "checkmark.circle.fill" : "exclamationmark.triangle.fill")
                        .foregroundColor(hasPermission ? .green : .orange)
                    
                    Text(hasPermission ? L("shortcuts.permissionGranted") : L("shortcuts.permissionNotGranted"))
                        .foregroundColor(hasPermission ? .green : .orange)
                }
                
                Spacer()
                
                if !hasPermission {
                    Button(L("shortcuts.grantPermission")) {
                        showingPermissionAlert = true
                    }
                    .buttonStyle(.borderedProminent)
                }
            }
            .padding()
            .background(Color(NSColor.controlBackgroundColor))
            .cornerRadius(12)
            
            if !hasPermission {
                Text(L("shortcuts.permissionInfo"))
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
    }
    
    // MARK: - Shortcuts Section
    
    private var shortcutsSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Label(L("shortcuts.globalShortcuts"), systemImage: "keyboard")
                .font(.headline)
            
            VStack(spacing: 0) {
                ShortcutRowSimple(
                    icon: "forward.fill",
                    title: L("shortcuts.nextVideo"),
                    shortcut: configManager.config.shortcuts.nextVideo
                )
                Divider()
                
                ShortcutRowSimple(
                    icon: "backward.fill",
                    title: L("shortcuts.previousVideo"),
                    shortcut: configManager.config.shortcuts.prevVideo
                )
                Divider()
                
                ShortcutRowSimple(
                    icon: "playpause.fill",
                    title: L("shortcuts.togglePlayPause"),
                    shortcut: configManager.config.shortcuts.togglePlayPause
                )
                Divider()
                
                ShortcutRowSimple(
                    icon: "square.and.arrow.down",
                    title: L("shortcuts.saveVideo"),
                    shortcut: configManager.config.shortcuts.saveVideo
                )
                Divider()
                
                ShortcutRowSimple(
                    icon: "doc.on.clipboard",
                    title: L("shortcuts.copyPrompt"),
                    shortcut: configManager.config.shortcuts.copyPrompt
                )
                Divider()
                
                ShortcutRowSimple(
                    icon: "rectangle.on.rectangle",
                    title: L("shortcuts.showControls"),
                    shortcut: configManager.config.shortcuts.showControls
                )
            }
            .padding()
            .background(Color(NSColor.controlBackgroundColor))
            .cornerRadius(12)
        }
    }
    
    // MARK: - Tip Section
    
    private var tipSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(L("shortcuts.tip"))
                .font(.caption)
                .foregroundColor(.secondary)
            
            Text(L("shortcuts.multiMonitorTip"))
                .font(.caption)
                .foregroundColor(.secondary)
        }
    }
}

// MARK: - Shortcut Row Simple

struct ShortcutRowSimple: View {
    let icon: String
    let title: String
    let shortcut: String
    
    var body: some View {
        HStack {
            Image(systemName: icon)
                .foregroundColor(.secondary)
                .frame(width: 24)
            
            Text(title)
                .frame(maxWidth: .infinity, alignment: .leading)
            
            Text(shortcut)
                .font(.system(.body, design: .monospaced))
                .foregroundColor(.secondary)
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(Color.secondary.opacity(0.2))
                .cornerRadius(4)
        }
        .padding(.vertical, 8)
    }
}
