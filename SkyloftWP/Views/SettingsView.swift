//
//  SettingsView.swift
//  SkyloftWP
//
//  Application settings - Uses MainWindowView for unified UI
//

import SwiftUI

struct SettingsView: View {
    var body: some View {
        MainWindowView()
    }
}

// MARK: - Settings Section Container (공용)

struct SettingsSection<Content: View>: View {
    let title: String
    let content: Content
    
    init(_ title: String, @ViewBuilder content: () -> Content) {
        self.title = title
        self.content = content()
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(title)
                .font(.headline)
                .foregroundColor(.primary)
            
            VStack(alignment: .leading, spacing: 8) {
                content
            }
            .padding(12)
            .background(Color(NSColor.controlBackgroundColor))
            .cornerRadius(8)
        }
    }
}

// MARK: - Monitor Settings (재사용)

struct MonitorSettingsView: View {
    @StateObject private var monitorManager = MonitorManager.shared
    @StateObject private var configManager = ConfigurationManager.shared
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                SettingsSection(L("monitor.detected")) {
                    if monitorManager.monitors.isEmpty {
                        Text(L("monitor.notFound"))
                            .foregroundColor(.secondary)
                            .padding()
                    } else {
                        VStack(spacing: 8) {
                            ForEach(monitorManager.monitors) { monitor in
                                MonitorRow(monitor: monitor)
                            }
                        }
                    }
                }
                
                HStack {
                    Spacer()
                    Button(action: { monitorManager.updateMonitors() }) {
                        Label(L("monitor.refresh"), systemImage: "arrow.clockwise")
                    }
                    Spacer()
                }
            }
            .padding(20)
        }
    }
}

// MARK: - Monitor Row

struct MonitorRow: View {
    let monitor: Monitor
    
    var body: some View {
        HStack {
            Image(systemName: "display")
                .font(.title2)
                .foregroundColor(.secondary)
            
            VStack(alignment: .leading, spacing: 2) {
                HStack {
                    Text(monitor.name)
                        .font(.body)
                    if monitor.isPrimary {
                        Text(L("monitor.primary"))
                            .font(.caption)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Color.blue.opacity(0.2))
                            .cornerRadius(4)
                    }
                }
                Text("\(Int(monitor.frame.width)) × \(Int(monitor.frame.height))")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            // 모니터 활성화 상태 표시
            Circle()
                .fill(Color.green)
                .frame(width: 8, height: 8)
        }
        .padding(8)
        .background(Color(NSColor.controlBackgroundColor))
        .cornerRadius(6)
    }
}
