//
//  StreamingSettingsView.swift
//  AIStreamWallpaper
//
//  스트리밍 연결 설정
//

import SwiftUI

struct StreamingSettingsView: View {
    @StateObject private var configManager = ConfigurationManager.shared
    @StateObject private var wallpaperManager = WallpaperManager.shared
    
    @State private var newSourceName = ""
    @State private var newSourceURL = ""
    @State private var showAddSource = false
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                // 연결 상태
                connectionStatusSection
                
                Divider()
                
                // 소스 설정
                sourceSection
                
                Divider()
                
                // 자동 저장 설정
                autoSaveSection
            }
            .padding(24)
        }
    }
    
    // MARK: - Connection Status
    
    private var connectionStatusSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Label(L("streaming.connectionStatus"), systemImage: "antenna.radiowaves.left.and.right")
                .font(.headline)
            
            HStack(spacing: 16) {
                // 상태 인디케이터
                HStack(spacing: 8) {
                    Circle()
                        .fill(wallpaperManager.isStreamingConnected ? Color.green : Color.gray)
                        .frame(width: 10, height: 10)
                    
                    Text(wallpaperManager.isStreamingConnected ? L("streaming.connected") : L("streaming.disconnected"))
                        .foregroundColor(wallpaperManager.isStreamingConnected ? .green : .secondary)
                }
                
                Spacer()
                
                // 연결 토글 버튼
                Button(action: { wallpaperManager.toggleStreamingConnection() }) {
                    Label(
                        wallpaperManager.isStreamingConnected ? L("streaming.disconnect") : L("streaming.connect"),
                        systemImage: wallpaperManager.isStreamingConnected ? "stop.fill" : "play.fill"
                    )
                }
                .buttonStyle(.borderedProminent)
                .tint(wallpaperManager.isStreamingConnected ? .red : .green)
            }
            .padding()
            .background(Color(NSColor.controlBackgroundColor))
            .cornerRadius(12)
        }
    }
    
    // MARK: - Source Section
    
    private var sourceSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Label(L("streaming.source"), systemImage: "link")
                .font(.headline)
            
            VStack(alignment: .leading, spacing: 12) {
                ForEach(configManager.config.streaming.sources) { source in
                    SourceRowView(
                        source: source,
                        isSelected: configManager.config.streaming.selectedSourceId == source.id,
                        onSelect: { selectSource(source) },
                        onRemove: { removeSource(source) }
                    )
                }
                
                // 소스 추가
                if showAddSource {
                    VStack(spacing: 8) {
                        TextField(L("streaming.sourceName"), text: $newSourceName)
                            .textFieldStyle(.roundedBorder)
                        
                        TextField(L("streaming.sourceURL"), text: $newSourceURL)
                            .textFieldStyle(.roundedBorder)
                        
                        HStack {
                            Button(L("common.add")) {
                                addSource()
                            }
                            .disabled(newSourceName.isEmpty || newSourceURL.isEmpty)
                            
                            Button(L("common.cancel")) {
                                showAddSource = false
                                newSourceName = ""
                                newSourceURL = ""
                            }
                        }
                    }
                    .padding()
                    .background(Color.secondary.opacity(0.1))
                    .cornerRadius(8)
                } else {
                    Button(action: { showAddSource = true }) {
                        Label(L("streaming.add"), systemImage: "plus.circle")
                    }
                    .buttonStyle(.plain)
                    .foregroundColor(.blue)
                }
            }
            .padding()
            .background(Color(NSColor.controlBackgroundColor))
            .cornerRadius(12)
        }
    }
    
    // MARK: - Auto Save Section
    
    private var autoSaveSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Label(L("streaming.autoSave"), systemImage: "square.and.arrow.down")
                .font(.headline)
            
            VStack(alignment: .leading, spacing: 16) {
                // 자동 저장 활성화 토글
                Toggle(isOn: Binding(
                    get: { configManager.config.streaming.autoSaveEnabled },
                    set: {
                        configManager.config.streaming.autoSaveEnabled = $0
                        configManager.save()
                    }
                )) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(L("streaming.autoSaveEnabled"))
                        Text(L("streaming.autoSaveEnabledInfo"))
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                
                // 최대 영상 수 (자동 저장 활성화 시에만 표시)
                if configManager.config.streaming.autoSaveEnabled {
                    Divider()
                    
                    HStack {
                        Text(L("streaming.maxVideos"))
                        
                        Spacer()
                        
                        Stepper(
                            value: Binding(
                                get: { configManager.config.streaming.autoSaveCount },
                                set: {
                                    configManager.config.streaming.autoSaveCount = $0
                                    configManager.save()
                                }
                            ),
                            in: 3...50
                        ) {
                            Text("\(configManager.config.streaming.autoSaveCount)")
                                .font(.headline)
                                .frame(width: 40)
                        }
                    }
                    
                    Text(L("streaming.autoSaveInfo"))
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            .padding()
            .background(Color(NSColor.controlBackgroundColor))
            .cornerRadius(12)
        }
    }
    
    // MARK: - Actions
    
    private func selectSource(_ source: VideoSource) {
        configManager.config.streaming.selectedSourceId = source.id
        configManager.save()
        
        // 스트리밍 연결 중이면 재연결
        if wallpaperManager.isStreamingConnected {
            wallpaperManager.toggleStreamingConnection()
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                wallpaperManager.toggleStreamingConnection()
            }
        }
    }
    
    private func addSource() {
        guard !newSourceName.isEmpty, !newSourceURL.isEmpty else { return }
        
        var url = newSourceURL
        if !url.hasPrefix("http://") && !url.hasPrefix("https://") {
            url = "https://" + url
        }
        
        let newSource = VideoSource(id: UUID().uuidString, name: newSourceName, url: url, isBuiltIn: false)
        configManager.config.streaming.sources.append(newSource)
        configManager.save()
        
        newSourceName = ""
        newSourceURL = ""
        showAddSource = false
    }
    
    private func removeSource(_ source: VideoSource) {
        guard !source.isBuiltIn else { return }
        
        configManager.config.streaming.sources.removeAll { $0.id == source.id }
        
        // 삭제된 소스가 선택되어 있었다면 기본으로
        if configManager.config.streaming.selectedSourceId == source.id {
            configManager.config.streaming.selectedSourceId = VideoSource.midjourneyTV.id
        }
        
        configManager.save()
    }
}

// MARK: - Source Row View

struct SourceRowView: View {
    let source: VideoSource
    let isSelected: Bool
    let onSelect: () -> Void
    let onRemove: () -> Void
    
    var body: some View {
        HStack {
            Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                .foregroundColor(isSelected ? .blue : .secondary)
            
            VStack(alignment: .leading, spacing: 2) {
                Text(source.name)
                    .font(.body)
                Text(source.url)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            if source.isBuiltIn {
                Text(L("streaming.default"))
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 2)
                    .background(Color.secondary.opacity(0.2))
                    .cornerRadius(4)
            } else {
                Button(action: onRemove) {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundColor(.secondary)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(12)
        .background(isSelected ? Color.blue.opacity(0.1) : Color.clear)
        .cornerRadius(8)
        .contentShape(Rectangle())
        .onTapGesture {
            onSelect()
        }
    }
}
