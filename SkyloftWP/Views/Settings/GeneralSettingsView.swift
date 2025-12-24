//
//  GeneralSettingsView.swift
//  SkyloftWP
//
//  일반 설정 (언어, 자동 시작, 반복 모드 등)
//

import SwiftUI

struct GeneralSettingsView: View {
    @StateObject private var configManager = ConfigurationManager.shared
    @StateObject private var localizationManager = LocalizationManager.shared
    @StateObject private var screenSaverManager = ScreenSaverManager.shared
    
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
                
                Divider()
                
                // 스크린세이버 설정
                screenSaverSection
                
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
                        // Use unified setAutoStart method
                        configManager.setAutoStart(newValue)
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
    
    // MARK: - Screen Saver Section
    
    private var screenSaverSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Label(L("general.screenSaver"), systemImage: "sparkles.tv")
                .font(.headline)
            
            VStack(alignment: .leading, spacing: 16) {
                // 상태 표시
                HStack {
                    Circle()
                        .fill(screenSaverManager.isInstalled ? Color.green : Color.gray)
                        .frame(width: 10, height: 10)
                    
                    Text(screenSaverManager.isInstalled ? L("general.screenSaverInstalled") : L("general.screenSaverNotInstalled"))
                        .foregroundColor(screenSaverManager.isInstalled ? .green : .secondary)
                    
                    Spacer()
                }
                
                Text(L("general.screenSaverDesc"))
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                // 에러 메시지
                if let error = screenSaverManager.installError {
                    HStack {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .foregroundColor(.orange)
                        Text(error)
                            .font(.caption)
                            .foregroundColor(.orange)
                    }
                }
                
                Divider()
                
                // 버튼들
                HStack(spacing: 12) {
                    if screenSaverManager.isInstalled {
                        Button(action: {
                            screenSaverManager.uninstall()
                        }) {
                            Label(L("general.screenSaverUninstall"), systemImage: "trash")
                        }
                        .buttonStyle(.bordered)
                        
                        Button(action: {
                            screenSaverManager.openScreenSaverSettings()
                        }) {
                            Label(L("general.screenSaverOpenSettings"), systemImage: "gear")
                        }
                        .buttonStyle(.borderedProminent)
                    } else {
                        Button(action: {
                            screenSaverManager.install()
                        }) {
                            Label(L("general.screenSaverInstall"), systemImage: "arrow.down.circle")
                        }
                        .buttonStyle(.borderedProminent)
                    }
                }
                
                // 안내 문구
                if screenSaverManager.isInstalled {
                    Text(L("general.screenSaverTip"))
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            .padding()
            .background(Color(NSColor.controlBackgroundColor))
            .cornerRadius(12)
        }
    }
}

