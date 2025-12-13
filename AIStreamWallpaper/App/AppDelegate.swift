//
//  AppDelegate.swift
//  AIStreamWallpaper
//
//  Application lifecycle and wallpaper management
//

import AppKit
import Combine
import SwiftUI

class AppDelegate: NSObject, NSApplicationDelegate {
    
    // MARK: - Properties
    
    static var shared: AppDelegate?
    
    private var wallpaperManager: WallpaperManager?
    private var configManager: ConfigurationManager?
    private var libraryManager: LibraryManager?
    private var playbackController: PlaybackController?
    private var hotkeyManager: HotkeyManager?
    private var cancellables = Set<AnyCancellable>()
    
    // Window references
    private var settingsWindow: NSWindow?
    private var libraryWindow: NSWindow?
    private var controlsWindow: NSWindow?
    
    // MARK: - Lifecycle
    
    func applicationDidFinishLaunching(_ notification: Notification) {
        AppDelegate.shared = self
        setupApplication()
        setupManagers()
        setupEnergyObservers()
        startWallpaper()
    }
    
    private func setupEnergyObservers() {
        // Pause when screen sleeps
        NotificationCenter.default.addObserver(
            forName: NSWorkspace.screensDidSleepNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.wallpaperManager?.pause()
        }
        
        // Resume when screen wakes
        NotificationCenter.default.addObserver(
            forName: NSWorkspace.screensDidWakeNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.wallpaperManager?.resume()
        }
        
        // Pause when system sleeps
        NSWorkspace.shared.notificationCenter.addObserver(
            forName: NSWorkspace.willSleepNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.wallpaperManager?.pause()
        }
    }
    
    func applicationWillTerminate(_ notification: Notification) {
        wallpaperManager?.stop()
        configManager?.save()
    }
    
    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        return true
    }
    
    // MARK: - Setup
    
    private func setupApplication() {
        // Hide dock icon - menu bar app only
        NSApp.setActivationPolicy(.accessory)
    }
    
    private func setupManagers() {
        // Initialize configuration
        configManager = ConfigurationManager.shared
        
        // Initialize library
        libraryManager = LibraryManager.shared
        
        // Initialize playback controller
        playbackController = PlaybackController.shared
        
        // Initialize wallpaper manager
        wallpaperManager = WallpaperManager.shared
        
        // Initialize hotkey manager
        hotkeyManager = HotkeyManager.shared
        setupHotkeys()
    }
    
    private func setupHotkeys() {
        guard let hotkey = hotkeyManager else { return }
        
        hotkey.onAction = { [weak self] action, displayID in
            DispatchQueue.main.async {
                self?.handleHotkeyAction(action, displayID: displayID)
            }
        }
        
        // Don't auto-request - user can enable in settings if needed
    }
    
    private func handleHotkeyAction(_ action: HotkeyAction, displayID: CGDirectDisplayID?) {
        switch action {
        case .nextVideo:
            if let displayID = displayID {
                wallpaperManager?.nextVideo(on: displayID)
            } else {
                playbackController?.next()
            }
            
        case .prevVideo:
            if let displayID = displayID {
                wallpaperManager?.previousVideo(on: displayID)
            } else {
                playbackController?.previous()
            }
            
        case .saveVideo:
            Task { @MainActor in
                if let displayID = displayID {
                    await wallpaperManager?.saveCurrentVideo(from: displayID)
                } else {
                    await wallpaperManager?.saveCurrentVideo()
                }
            }
            
        case .toggleMute:
            configManager?.toggleMute()
            
        case .togglePlayPause:
            if let displayID = displayID {
                wallpaperManager?.togglePlayPause(on: displayID)
            } else {
                wallpaperManager?.togglePlayPause()
            }
            
        case .openLibrary:
            openLibraryWindow()
            
        case .copyPrompt:
            if let displayID = displayID {
                wallpaperManager?.copyCurrentPrompt(from: displayID)
            } else {
                wallpaperManager?.copyCurrentPrompt()
            }
            
        case .showControls:
            toggleControlsWindow()
        }
    }
    
    private func startWallpaper() {
        guard let config = configManager?.config else { return }
        
        if config.behavior.autoStart {
            wallpaperManager?.start()
        }
    }
    
    // MARK: - Window Management
    
    private var mainWindow: NSWindow?
    
    func openMainWindow() {
        // 기존 윈도우가 있으면 활성화
        if let window = mainWindow {
            window.makeKeyAndOrderFront(nil)
            NSApp.activate(ignoringOtherApps: true)
            return
        }
        
        // 새 메인 윈도우 생성 (라이브러리 + 설정 통합)
        let mainView = MainWindowView()
        let hostingController = NSHostingController(rootView: mainView)
        
        let window = NSWindow(contentViewController: hostingController)
        window.title = "AI Stream Wallpaper"
        window.styleMask = [.titled, .closable, .resizable, .miniaturizable]
        window.setContentSize(NSSize(width: 1024, height: 768))
        window.minSize = NSSize(width: 1024, height: 768)
        window.center()
        window.isReleasedWhenClosed = false
        
        // 윈도우 닫힘 감지
        NotificationCenter.default.addObserver(
            forName: NSWindow.willCloseNotification,
            object: window,
            queue: .main
        ) { [weak self] _ in
            self?.mainWindow = nil
        }
        
        mainWindow = window
        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }
    
    func openSettingsWindow() {
        openMainWindow()
    }
    
    func openLibraryWindow() {
        openMainWindow()
    }
    
    func closeLibraryWindow() {
        libraryWindow?.close()
        libraryWindow = nil
    }
    
    var isLibraryWindowOpen: Bool {
        return libraryWindow != nil && libraryWindow!.isVisible
    }
    
    func toggleControlsWindow() {
        if let window = controlsWindow, window.isVisible {
            window.close()
            controlsWindow = nil
        } else {
            showControlsWindow()
        }
    }
    
    func showControlsWindow() {
        if let window = controlsWindow {
            window.makeKeyAndOrderFront(nil)
            return
        }
        
        let controlsView = MiniControlsView()
        let hostingController = NSHostingController(rootView: controlsView)
        
        let window = NSPanel(contentViewController: hostingController)
        window.title = ""
        window.styleMask = [.borderless, .nonactivatingPanel]
        window.isFloatingPanel = true
        window.level = .floating
        window.isOpaque = false
        window.backgroundColor = .clear
        window.hasShadow = true
        window.setContentSize(NSSize(width: 200, height: 60))
        window.isReleasedWhenClosed = false
        
        // Position in bottom right corner
        if let screen = NSScreen.main {
            let screenFrame = screen.visibleFrame
            let windowFrame = window.frame
            let x = screenFrame.maxX - windowFrame.width - 20
            let y = screenFrame.minY + 20
            window.setFrameOrigin(NSPoint(x: x, y: y))
        }
        
        // Track window close
        NotificationCenter.default.addObserver(
            forName: NSWindow.willCloseNotification,
            object: window,
            queue: .main
        ) { [weak self] _ in
            self?.controlsWindow = nil
        }
        
        controlsWindow = window
        window.orderFront(nil)
    }
}

// MARK: - Notification Names

extension Notification.Name {
    static let wallpaperDidStart = Notification.Name("wallpaperDidStart")
    static let wallpaperDidStop = Notification.Name("wallpaperDidStop")
    static let videoDidSave = Notification.Name("videoDidSave")
    static let playbackModeDidChange = Notification.Name("playbackModeDidChange")
    static let libraryDidUpdate = Notification.Name("libraryDidUpdate")
}
