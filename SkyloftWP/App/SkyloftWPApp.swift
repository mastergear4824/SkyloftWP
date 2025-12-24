//
//  SkyloftWPApp.swift
//  SkyloftWP
//
//  Streaming Video Desktop Wallpaper Application
//

import SwiftUI
import AppKit

@main
struct SkyloftWPApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    
    var body: some Scene {
        // Menu bar icon and dropdown
        MenuBarExtra {
            MenuBarView()
        } label: {
            Image(systemName: "tv.fill")
        }
        .menuBarExtraStyle(.window)
    }
}
