//
//  GeneralSettingsView.swift
//  AIStreamWallpaper
//
//  일반 설정 (언어, 자동 시작, 반복 모드 등)
//

import SwiftUI
import ServiceManagement

struct GeneralSettingsView: View {
    @StateObject private var configManager = ConfigurationManager.shared
    @StateObject private var localizationManager = LocalizationManager.shared
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                // 언어 설정
                languageSection
                
                Divider()
                
                // 재생 설정
                playbackSection
                
                Divider()
                
                // 시작 설정
                startupSection
                
                Spacer()
            }
            .padding(24)
        }
    }
    
    // MARK: - Language Section
    
    private var languageSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Label(L("general.language"), systemImage: "globe")
                .font(.headline)
            
            VStack(alignment: .leading, spacing: 12) {
                Picker(L("general.selectLanguage"), selection: Binding(
                    get: { localizationManager.currentLanguage },
                    set: { localizationManager.setLanguage($0) }
                )) {
                    Text("System Default").tag(AppLanguage.system)
                    Text("English").tag(AppLanguage.english)
                    Text("한국어").tag(AppLanguage.korean)
                    Text("日本語").tag(AppLanguage.japanese)
                }
                .pickerStyle(.menu)
                .frame(maxWidth: 200)
            }
            .padding()
            .background(Color(NSColor.controlBackgroundColor))
            .cornerRadius(12)
        }
    }
    
    // MARK: - Playback Section
    
    private var playbackSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Label(L("general.playback"), systemImage: "play.rectangle")
                .font(.headline)
            
            VStack(alignment: .leading, spacing: 16) {
                // 음소거
                Toggle(isOn: Binding(
                    get: { configManager.config.behavior.muteAudio },
                    set: {
                        configManager.config.behavior.muteAudio = $0
                        configManager.save()
                    }
                )) {
                    HStack {
                        Image(systemName: "speaker.slash")
                            .foregroundColor(.secondary)
                        Text(L("general.mute"))
                    }
                }
            }
            .padding()
            .background(Color(NSColor.controlBackgroundColor))
            .cornerRadius(12)
        }
    }
    
    // MARK: - Startup Section
    
    private var startupSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Label(L("general.startup"), systemImage: "power")
                .font(.headline)
            
            VStack(alignment: .leading, spacing: 16) {
                Toggle(isOn: Binding(
                    get: { configManager.config.behavior.autoStart },
                    set: { newValue in
                        configManager.config.behavior.autoStart = newValue
                        configManager.save()
                        setLaunchAtLogin(newValue)
                    }
                )) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(L("general.launchAtLogin"))
                        Text(L("general.launchAtLoginInfo"))
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                
            }
            .padding()
            .background(Color(NSColor.controlBackgroundColor))
            .cornerRadius(12)
        }
    }
    
    // MARK: - Actions
    
    private func setLaunchAtLogin(_ enabled: Bool) {
        if #available(macOS 13.0, *) {
            do {
                if enabled {
                    try SMAppService.mainApp.register()
                } else {
                    try SMAppService.mainApp.unregister()
                }
            } catch {
                print("Failed to set launch at login: \(error)")
            }
        }
    }
}

