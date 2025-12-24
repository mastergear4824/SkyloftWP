//
//  ScreenSaverManager.swift
//  SkyloftWP
//
//  Manages screen saver installation and removal
//

import Foundation
import AppKit

class ScreenSaverManager: ObservableObject {
    
    static let shared = ScreenSaverManager()
    
    @Published var isInstalled: Bool = false
    @Published var installError: String?
    
    private let saverName = "SkyloftWPSaver.saver"
    
    private var userScreenSaversPath: URL {
        FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent("Library/Screen Savers")
    }
    
    private var installedSaverPath: URL {
        userScreenSaversPath.appendingPathComponent(saverName)
    }
    
    private init() {
        checkInstallationStatus()
    }
    
    // MARK: - Status Check
    
    func checkInstallationStatus() {
        isInstalled = FileManager.default.fileExists(atPath: installedSaverPath.path)
        print("📺 [ScreenSaver] Installation status: \(isInstalled ? "Installed" : "Not installed")")
    }
    
    // MARK: - Installation
    
    func install() {
        installError = nil
        
        // 앱 번들 내의 스크린세이버 찾기
        guard let bundledSaverURL = Bundle.main.url(forResource: "SkyloftWPSaver", withExtension: "saver", subdirectory: "ScreenSaver") else {
            // 빌드된 스크린세이버가 없으면 빌드 필요
            installError = "Screen saver bundle not found. Please rebuild the app."
            print("📺 [ScreenSaver] Error: Bundle not found in app resources")
            return
        }
        
        do {
            // Screen Savers 폴더가 없으면 생성
            if !FileManager.default.fileExists(atPath: userScreenSaversPath.path) {
                try FileManager.default.createDirectory(at: userScreenSaversPath, withIntermediateDirectories: true)
            }
            
            // 기존 설치 제거
            if FileManager.default.fileExists(atPath: installedSaverPath.path) {
                try FileManager.default.removeItem(at: installedSaverPath)
            }
            
            // 새로 복사
            try FileManager.default.copyItem(at: bundledSaverURL, to: installedSaverPath)
            
            isInstalled = true
            installError = nil
            
            print("📺 [ScreenSaver] ✅ Installed successfully to: \(installedSaverPath.path)")
            
        } catch {
            installError = "Installation failed: \(error.localizedDescription)"
            print("📺 [ScreenSaver] ❌ Installation error: \(error)")
        }
    }
    
    func uninstall() {
        installError = nil
        
        guard FileManager.default.fileExists(atPath: installedSaverPath.path) else {
            isInstalled = false
            return
        }
        
        do {
            try FileManager.default.removeItem(at: installedSaverPath)
            isInstalled = false
            installError = nil
            
            print("📺 [ScreenSaver] ✅ Uninstalled successfully")
            
        } catch {
            installError = "Uninstallation failed: \(error.localizedDescription)"
            print("📺 [ScreenSaver] ❌ Uninstallation error: \(error)")
        }
    }
    
    // MARK: - System Settings
    
    func openScreenSaverSettings() {
        // 시스템 환경설정 > 화면 보호기 열기
        if #available(macOS 13.0, *) {
            // macOS Ventura+ 새로운 시스템 설정
            // 먼저 직접 URL 시도
            let urls = [
                "x-apple.systempreferences:com.apple.ScreenSaver-Settings.extension",
                "x-apple.systempreferences:com.apple.Lock-Screen-Settings.extension",
                "x-apple.systempreferences:com.apple.Wallpaper-Settings.extension"
            ]
            
            for urlString in urls {
                if let url = URL(string: urlString), NSWorkspace.shared.open(url) {
                    return
                }
            }
            
            // 직접 실행으로 폴백
            let task = Process()
            task.executableURL = URL(fileURLWithPath: "/usr/bin/open")
            task.arguments = ["-b", "com.apple.systempreferences", "/System/Library/PreferencePanes/DesktopScreenEffectsPref.prefPane"]
            try? task.run()
            
        } else {
            // macOS Monterey 이하
            if let url = URL(string: "x-apple.systempreferences:com.apple.preference.desktopscreeneffect") {
                NSWorkspace.shared.open(url)
            }
        }
    }
}

