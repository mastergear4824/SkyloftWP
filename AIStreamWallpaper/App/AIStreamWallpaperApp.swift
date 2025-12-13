//
//  AIStreamWallpaperApp.swift
//  AIStreamWallpaper
//
//  Midjourney TV Desktop Wallpaper Application
//

import SwiftUI
import AppKit

@main
struct AIStreamWallpaperApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    
    var body: some Scene {
        // 메뉴바 전용 앱 - 윈도우는 AppDelegate에서 직접 관리
        MenuBarExtra {
            MenuBarView()
        } label: {
            Image(systemName: "tv.fill")
        }
        .menuBarExtraStyle(.window)
    }
}
