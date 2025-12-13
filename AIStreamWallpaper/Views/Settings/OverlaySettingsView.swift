//
//  OverlaySettingsView.swift
//  AIStreamWallpaper
//
//  디스플레이 오버레이 설정 (투명도, 밝기, 채도, 블러)
//

import SwiftUI

struct DisplaySettingsView: View {
    @StateObject private var configManager = ConfigurationManager.shared
    @StateObject private var wallpaperManager = WallpaperManager.shared
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                // 프리셋
                presetsSection
                
                Divider()
                
                // 슬라이더들
                slidersSection
                
                Spacer()
            }
            .padding(24)
        }
    }
    
    // MARK: - Sliders Section
    
    private var slidersSection: some View {
        VStack(alignment: .leading, spacing: 20) {
            Label(L("display.adjustments"), systemImage: "slider.horizontal.3")
                .font(.headline)
            
            VStack(spacing: 20) {
                // 투명도
                SliderRowDouble(
                    icon: "square.fill.on.square.fill",
                    title: L("display.transparency"),
                    value: $configManager.config.overlay.opacity,
                    range: 0.1...1.0,
                    format: "%.0f%%",
                    multiplier: 100
                )
                
                // 밝기
                SliderRowDouble(
                    icon: "sun.max.fill",
                    title: L("display.brightness"),
                    value: $configManager.config.overlay.brightness,
                    range: -0.5...0.5,
                    format: "%+.0f%%",
                    multiplier: 100
                )
                
                // 채도
                SliderRowDouble(
                    icon: "drop.fill",
                    title: L("display.saturation"),
                    value: $configManager.config.overlay.saturation,
                    range: 0...2.0,
                    format: "%.0f%%",
                    multiplier: 100
                )
                
                // 블러
                SliderRowDouble(
                    icon: "aqi.medium",
                    title: L("display.blur"),
                    value: $configManager.config.overlay.blur,
                    range: 0...20,
                    format: "%.0f",
                    multiplier: 1
                )
            }
            .padding()
            .background(Color(NSColor.controlBackgroundColor))
            .cornerRadius(12)
            .onChange(of: configManager.config.overlay) { _ in
                configManager.save()
                wallpaperManager.applyOverlaySettings()
            }
        }
    }
    
    // MARK: - Presets Section
    
    private var presetsSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Label(L("display.presets"), systemImage: "sparkles")
                .font(.headline)
            
            LazyVGrid(columns: [
                GridItem(.adaptive(minimum: 100, maximum: 130), spacing: 10)
            ], spacing: 10) {
                PresetButton(title: L("display.preset.default"), icon: "circle") {
                    applyPreset(opacity: 1.0, brightness: 0, saturation: 1.0, blur: 0)
                }
                
                PresetButton(title: L("display.preset.subtle"), icon: "circle.lefthalf.filled") {
                    applyPreset(opacity: 1.0, brightness: -0.15, saturation: 0.85, blur: 0)
                }
                
                PresetButton(title: L("display.preset.dim"), icon: "moon.fill") {
                    applyPreset(opacity: 1.0, brightness: -0.3, saturation: 0.7, blur: 0)
                }
                
                PresetButton(title: L("display.preset.ambient"), icon: "waveform") {
                    applyPreset(opacity: 1.0, brightness: -0.2, saturation: 0.6, blur: 3)
                }
                
                PresetButton(title: L("display.preset.focus"), icon: "eye.slash") {
                    applyPreset(opacity: 1.0, brightness: -0.4, saturation: 0.4, blur: 5)
                }
                
                PresetButton(title: L("display.preset.vivid"), icon: "sparkle") {
                    applyPreset(opacity: 1.0, brightness: 0.1, saturation: 1.5, blur: 0)
                }
                
                // 추가 프리셋
                PresetButton(title: L("display.preset.cinema"), icon: "film") {
                    applyPreset(opacity: 1.0, brightness: -0.35, saturation: 0.8, blur: 1)
                }
                
                PresetButton(title: L("display.preset.neon"), icon: "lightbulb.fill") {
                    applyPreset(opacity: 1.0, brightness: 0.05, saturation: 1.8, blur: 0)
                }
                
                PresetButton(title: L("display.preset.dreamy"), icon: "cloud.fill") {
                    applyPreset(opacity: 1.0, brightness: -0.1, saturation: 0.75, blur: 4)
                }
                
                PresetButton(title: L("display.preset.night"), icon: "moon.stars.fill") {
                    applyPreset(opacity: 1.0, brightness: -0.45, saturation: 0.5, blur: 0)
                }
                
                PresetButton(title: L("display.preset.warm"), icon: "sun.horizon.fill") {
                    applyPreset(opacity: 1.0, brightness: 0.05, saturation: 1.2, blur: 0)
                }
                
                PresetButton(title: L("display.preset.retro"), icon: "camera.filters") {
                    applyPreset(opacity: 1.0, brightness: -0.1, saturation: 0.6, blur: 0)
                }
                
                PresetButton(title: L("display.preset.cool"), icon: "snowflake") {
                    applyPreset(opacity: 1.0, brightness: -0.05, saturation: 0.9, blur: 0)
                }
                
                PresetButton(title: L("display.preset.soft"), icon: "wind") {
                    applyPreset(opacity: 1.0, brightness: 0, saturation: 0.9, blur: 2)
                }
            }
        }
    }
    
    private func applyPreset(opacity: Double, brightness: Double, saturation: Double, blur: Double) {
        withAnimation(.easeInOut(duration: 0.3)) {
            configManager.config.overlay.opacity = opacity
            configManager.config.overlay.brightness = brightness
            configManager.config.overlay.saturation = saturation
            configManager.config.overlay.blur = blur
        }
        configManager.save()
        wallpaperManager.applyOverlaySettings()
    }
}

// MARK: - Slider Row (Double)

struct SliderRowDouble: View {
    let icon: String
    let title: String
    @Binding var value: Double
    let range: ClosedRange<Double>
    let format: String
    let multiplier: Double
    
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .foregroundColor(.secondary)
                .frame(width: 24)
            
            Text(title)
                .frame(width: 100, alignment: .leading)
                .lineLimit(1)
            
            Slider(value: $value, in: range)
                .frame(maxWidth: .infinity)
            
            Text(String(format: format, value * multiplier))
                .font(.caption.monospacedDigit())
                .foregroundColor(.secondary)
                .frame(width: 50, alignment: .trailing)
        }
    }
}

// MARK: - Preset Button

struct PresetButton: View {
    let title: String
    let icon: String
    let action: () -> Void
    
    @State private var isHovering = false
    
    var body: some View {
        Button(action: action) {
            VStack(spacing: 8) {
                Image(systemName: icon)
                    .font(.title2)
                
                Text(title)
                    .font(.caption)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 12)
            .background(isHovering ? Color.blue.opacity(0.1) : Color(NSColor.controlBackgroundColor))
            .cornerRadius(8)
        }
        .buttonStyle(.plain)
        .onHover { isHovering = $0 }
    }
}

#Preview {
    DisplaySettingsView()
}
