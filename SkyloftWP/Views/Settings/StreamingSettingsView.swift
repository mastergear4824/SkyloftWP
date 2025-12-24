//
//  StreamingSettingsView.swift
//  SkyloftWP
//
//  스트리밍 연결 설정
//

import SwiftUI
import WebKit
import Photos

struct StreamingSettingsView: View {
    @StateObject private var configManager = ConfigurationManager.shared
    @StateObject private var wallpaperManager = WallpaperManager.shared
    
    @State private var newSourceURL = ""
    @State private var newSourceFetchMode: VideoSource.FetchMode = .streaming
    @State private var showAddSource = false
    @State private var isLoadingTitle = false
    @State private var loadedTitle = ""
    @State private var loadError: String?
    @State private var photosAccessStatus: PHAuthorizationStatus = .notDetermined
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                // 면책 조항 (상단에 배치)
                disclaimerSection
                
                // 연결 상태
                connectionStatusSection
                
                // 소스 설정
                sourceSection
                
                // 자동 저장 설정
                autoSaveSection
            }
            .padding(20)
        }
    }
    
    // MARK: - Connection Status
    
    private var connectionStatusSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Label(L("streaming.connectionStatus"), systemImage: "antenna.radiowaves.left.and.right")
                .font(.subheadline)
                .fontWeight(.semibold)
            
            HStack(spacing: 12) {
                HStack(spacing: 6) {
                    Circle()
                        .fill(wallpaperManager.isStreamingConnected ? Color.green : Color.gray)
                        .frame(width: 8, height: 8)
                    
                    Text(wallpaperManager.isStreamingConnected ? L("streaming.connected") : L("streaming.disconnected"))
                        .font(.caption)
                        .foregroundColor(wallpaperManager.isStreamingConnected ? .green : .secondary)
                }
                
                Spacer()
                
                Button(action: { wallpaperManager.toggleStreamingConnection() }) {
                    Label(
                        wallpaperManager.isStreamingConnected ? L("streaming.disconnect") : L("streaming.connect"),
                        systemImage: wallpaperManager.isStreamingConnected ? "stop.fill" : "play.fill"
                    )
                    .font(.caption)
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.small)
                .tint(wallpaperManager.isStreamingConnected ? .red : .green)
                .disabled(!configManager.config.streaming.hasValidSource)
            }
            .padding(12)
            .background(Color(NSColor.controlBackgroundColor))
            .cornerRadius(8)
        }
    }
    
    // MARK: - Source Section
    
    private var sourceSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Label(L("streaming.source"), systemImage: "link")
                .font(.subheadline)
                .fontWeight(.semibold)
            
            VStack(alignment: .leading, spacing: 8) {
                // Photos Library 소스 (항상 표시)
                photosLibrarySourceView
                
                // 구분선
                if !configManager.config.streaming.sources.isEmpty || showAddSource {
                    Divider()
                    
                    Text(L("streaming.customSources"))
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                // 사용자 추가 소스 목록
                ForEach(configManager.config.streaming.sources.filter { !$0.isPhotosLibrary }) { source in
                    SourceRowView(
                        source: source,
                        isSelected: configManager.config.streaming.selectedSourceId == source.id,
                        onSelect: { selectSource(source) },
                        onRemove: { removeSource(source) }
                    )
                }
                
                // 소스 추가 UI
                if showAddSource {
                    addSourceView
                } else {
                    Button(action: { showAddSource = true }) {
                        Label(L("streaming.add"), systemImage: "plus.circle")
                            .font(.caption)
                    }
                    .buttonStyle(.plain)
                    .foregroundColor(.blue)
                }
            }
            .padding(12)
            .background(Color(NSColor.controlBackgroundColor))
            .cornerRadius(8)
        }
    }
    
    // MARK: - Photos Library Source View
    
    private var photosLibrarySourceView: some View {
        let isSelected = configManager.config.streaming.selectedSourceId == VideoSource.photosLibrary.id
        
        return HStack(spacing: 8) {
            Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                .foregroundColor(isSelected ? .blue : .secondary)
                .font(.caption)
            
            VStack(alignment: .leading, spacing: 1) {
                HStack(spacing: 4) {
                    Image(systemName: "photo.on.rectangle.angled")
                        .foregroundColor(.purple)
                        .font(.caption)
                    Text(L("streaming.photosLibrary"))
                        .font(.callout)
                    
                    Text(L("streaming.builtIn"))
                        .font(.caption2)
                        .foregroundColor(.white)
                        .padding(.horizontal, 4)
                        .padding(.vertical, 1)
                        .background(Color.purple.opacity(0.7))
                        .cornerRadius(3)
                }
                
                Text(L("streaming.photosLibraryDesc"))
                    .font(.caption2)
                    .foregroundColor(.secondary)
                
                // 권한 상태 표시
                if photosAccessStatus == .denied || photosAccessStatus == .restricted {
                    HStack(spacing: 4) {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .foregroundColor(.orange)
                            .font(.caption2)
                        Text(L("streaming.photosAccessRequired"))
                            .font(.caption2)
                            .foregroundColor(.orange)
                        
                        Button(L("streaming.grantAccess")) {
                            openPhotosSettings()
                        }
                        .font(.caption2)
                        .buttonStyle(.plain)
                        .foregroundColor(.blue)
                    }
                }
            }
            
            Spacer()
        }
        .padding(10)
        .background(isSelected ? Color.blue.opacity(0.1) : Color.clear)
        .cornerRadius(6)
        .contentShape(Rectangle())
        .onTapGesture {
            selectPhotosLibrary()
        }
        .onAppear {
            checkPhotosAccess()
        }
    }
    
    // MARK: - Add Source View
    
    private var addSourceView: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Add New Source")
                .font(.headline)
            
            // URL 입력
            HStack {
                TextField("https://example.com/videos", text: $newSourceURL)
                    .textFieldStyle(.roundedBorder)
                    .onSubmit {
                        fetchTitle()
                    }
                
                if isLoadingTitle {
                    ProgressView()
                        .scaleEffect(0.7)
                } else {
                    Button("Fetch") {
                        fetchTitle()
                    }
                    .disabled(newSourceURL.isEmpty)
                }
            }
            
            // 로드된 제목 표시
            if !loadedTitle.isEmpty {
                HStack {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(.green)
                    Text(loadedTitle)
                        .font(.caption)
                        .foregroundColor(.primary)
                }
            }
            
            // 에러 표시
            if let error = loadError {
                HStack {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundColor(.orange)
                    Text(error)
                        .font(.caption)
                        .foregroundColor(.orange)
                }
            }
            
            Divider()
            
            // 수집 방식 선택
            VStack(alignment: .leading, spacing: 8) {
                Text("Fetch Mode")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                
                ForEach(VideoSource.FetchMode.allCases, id: \.self) { mode in
                    HStack {
                        Image(systemName: newSourceFetchMode == mode ? "checkmark.circle.fill" : "circle")
                            .foregroundColor(newSourceFetchMode == mode ? .blue : .secondary)
                        
                        VStack(alignment: .leading, spacing: 2) {
                            Text(mode.displayName)
                                .font(.body)
                            Text(mode.description)
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        
                        Spacer()
                    }
                    .padding(8)
                    .background(newSourceFetchMode == mode ? Color.blue.opacity(0.1) : Color.clear)
                    .cornerRadius(6)
                    .contentShape(Rectangle())
                    .onTapGesture {
                        newSourceFetchMode = mode
                    }
                }
            }
            
            Divider()
            
            // 버튼들
            HStack {
                Button("Add Source") {
                    addSource()
                }
                .buttonStyle(.borderedProminent)
                .disabled(newSourceURL.isEmpty)
                
                Button("Cancel") {
                    cancelAddSource()
                }
                .buttonStyle(.bordered)
            }
        }
        .padding()
        .background(Color.blue.opacity(0.05))
        .cornerRadius(8)
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(Color.blue.opacity(0.3), lineWidth: 1)
        )
    }
    
    // MARK: - Auto Save Section
    
    private var autoSaveSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Label(L("streaming.autoSave"), systemImage: "square.and.arrow.down")
                .font(.subheadline)
                .fontWeight(.semibold)
            
            VStack(alignment: .leading, spacing: 10) {
                // 자동 저장 활성화 토글
                Toggle(isOn: Binding(
                    get: { configManager.config.streaming.autoSaveEnabled },
                    set: {
                        configManager.config.streaming.autoSaveEnabled = $0
                        configManager.save()
                    }
                )) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(L("streaming.autoSaveEnabled"))
                            .font(.callout)
                        Text(L("streaming.autoSaveEnabledInfo"))
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }
                }
                .controlSize(.small)
                
                // 최대 영상 수 (자동 저장 활성화 시에만 표시)
                if configManager.config.streaming.autoSaveEnabled {
                    Divider()
                    
                    HStack {
                        Text(L("streaming.maxVideos"))
                            .font(.callout)
                        
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
                                .font(.callout)
                                .fontWeight(.medium)
                                .frame(width: 30)
                        }
                        .controlSize(.small)
                    }
                    
                    Text(L("streaming.autoSaveInfo"))
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
            }
            .padding(12)
            .background(Color(NSColor.controlBackgroundColor))
            .cornerRadius(8)
        }
    }
    
    // MARK: - Disclaimer Section
    
    private var disclaimerSection: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 6) {
                Image(systemName: "exclamationmark.triangle.fill")
                    .foregroundColor(.orange)
                Text(L("streaming.disclaimerTitle"))
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .foregroundColor(.orange)
            }
            
            Text(L("streaming.disclaimer"))
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.orange.opacity(0.1))
        .cornerRadius(8)
    }
    
    // MARK: - Actions
    
    private func fetchTitle() {
        guard !newSourceURL.isEmpty else { return }
        
        var urlString = newSourceURL.trimmingCharacters(in: .whitespacesAndNewlines)
        if !urlString.hasPrefix("http://") && !urlString.hasPrefix("https://") {
            urlString = "https://" + urlString
        }
        
        guard let url = URL(string: urlString) else {
            loadError = "Invalid URL"
            return
        }
        
        newSourceURL = urlString
        isLoadingTitle = true
        loadError = nil
        loadedTitle = ""
        
        // 웹페이지 제목 가져오기
        Task {
            do {
                let (data, _) = try await URLSession.shared.data(from: url)
                if let html = String(data: data, encoding: .utf8) {
                    // <title> 태그 추출
                    if let titleRange = html.range(of: "<title>"),
                       let endRange = html.range(of: "</title>") {
                        let title = String(html[titleRange.upperBound..<endRange.lowerBound])
                            .trimmingCharacters(in: .whitespacesAndNewlines)
                            .replacingOccurrences(of: "\n", with: " ")
                        
                        await MainActor.run {
                            loadedTitle = title.isEmpty ? url.host ?? "Unknown" : title
                            isLoadingTitle = false
                        }
                    } else {
                        await MainActor.run {
                            loadedTitle = url.host ?? "Unknown"
                            isLoadingTitle = false
                        }
                    }
                } else {
                    await MainActor.run {
                        loadedTitle = url.host ?? "Unknown"
                        isLoadingTitle = false
                    }
                }
            } catch {
                await MainActor.run {
                    loadedTitle = url.host ?? "Unknown"
                    loadError = "Could not fetch title, using hostname"
                    isLoadingTitle = false
                }
            }
        }
    }
    
    // MARK: - Photos Library Actions
    
    private func checkPhotosAccess() {
        photosAccessStatus = PHPhotoLibrary.authorizationStatus(for: .readWrite)
    }
    
    private func selectPhotosLibrary() {
        // 권한 확인
        PHPhotoLibrary.requestAuthorization(for: .readWrite) { status in
            DispatchQueue.main.async {
                self.photosAccessStatus = status
                
                switch status {
                case .authorized, .limited:
                    // 권한 있으면 Photos Library 선택
                    configManager.config.streaming.selectedSourceId = VideoSource.photosLibrary.id
                    configManager.save()
                    
                    // 스트리밍 연결 중이면 재연결
                    if wallpaperManager.isStreamingConnected {
                        wallpaperManager.toggleStreamingConnection()
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                            wallpaperManager.toggleStreamingConnection()
                        }
                    }
                case .denied, .restricted:
                    // 권한 없으면 설정으로 안내
                    showPhotosAccessAlert()
                case .notDetermined:
                    break
                @unknown default:
                    break
                }
            }
        }
    }
    
    private func showPhotosAccessAlert() {
        let alert = NSAlert()
        alert.messageText = "Photos Access Required"
        alert.informativeText = "Please allow access to your Photos library in System Settings > Privacy & Security > Photos."
        alert.alertStyle = .warning
        alert.addButton(withTitle: "Open Settings")
        alert.addButton(withTitle: "Cancel")
        
        if alert.runModal() == .alertFirstButtonReturn {
            openPhotosSettings()
        }
    }
    
    private func openPhotosSettings() {
        if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Photos") {
            NSWorkspace.shared.open(url)
        }
    }
    
    // MARK: - Source Actions
    
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
        guard !newSourceURL.isEmpty else { return }
        
        var urlString = newSourceURL.trimmingCharacters(in: .whitespacesAndNewlines)
        if !urlString.hasPrefix("http://") && !urlString.hasPrefix("https://") {
            urlString = "https://" + urlString
        }
        
        let title = loadedTitle.isEmpty ? (URL(string: urlString)?.host ?? "Unknown") : loadedTitle
        
        let newSource = VideoSource(
            id: UUID().uuidString,
            name: title,
            url: urlString,
            isBuiltIn: false,
            description: nil,
            fetchMode: newSourceFetchMode
        )
        
        configManager.config.streaming.sources.append(newSource)
        
        // 첫 번째 소스면 자동 선택
        if configManager.config.streaming.sources.count == 1 {
            configManager.config.streaming.selectedSourceId = newSource.id
        }
        
        configManager.save()
        cancelAddSource()
    }
    
    private func cancelAddSource() {
        newSourceURL = ""
        newSourceFetchMode = .streaming
        loadedTitle = ""
        loadError = nil
        showAddSource = false
    }
    
    private func removeSource(_ source: VideoSource) {
        configManager.config.streaming.sources.removeAll { $0.id == source.id }
        
        // 삭제된 소스가 선택되어 있었다면 첫 번째 소스로 변경
        if configManager.config.streaming.selectedSourceId == source.id {
            configManager.config.streaming.selectedSourceId = configManager.config.streaming.sources.first?.id ?? ""
        }
        
        // 연결 끊기
        if wallpaperManager.isStreamingConnected && configManager.config.streaming.sources.isEmpty {
            wallpaperManager.toggleStreamingConnection()
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
                HStack(spacing: 6) {
                    Text(source.name)
                        .font(.body)
                    
                    // 수집 방식 배지
                    Text(source.fetchMode == .streaming ? "Streaming" : "Polling")
                        .font(.caption2)
                        .foregroundColor(.white)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(source.fetchMode == .streaming ? Color.green.opacity(0.7) : Color.orange.opacity(0.7))
                        .cornerRadius(4)
                }
                
                Text(source.url)
                    .font(.caption2)
                    .foregroundColor(.secondary)
                    .lineLimit(1)
            }
            
            Spacer()
            
            Button(action: onRemove) {
                Image(systemName: "xmark.circle.fill")
                    .foregroundColor(.secondary)
            }
            .buttonStyle(.plain)
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
