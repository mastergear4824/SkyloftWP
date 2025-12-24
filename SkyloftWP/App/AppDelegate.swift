//
//  AppDelegate.swift
//  SkyloftWP
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
    
    // State tracking
    private var isRecoveringFromSleep = false
    private var wasPlayingBeforeSleep = false
    private var isSessionActive = true  // 세션이 활성화 상태인지 (잠금되면 false)
    private var displayChangeWorkItem: DispatchWorkItem?
    
    // MARK: - Lifecycle
    
    func applicationDidFinishLaunching(_ notification: Notification) {
        AppDelegate.shared = self
        setupApplication()
        setupManagers()
        setupSystemObservers()
        startWallpaper()
        
        print("🚀 [App] Launched successfully")
    }
    
    func applicationWillTerminate(_ notification: Notification) {
        wallpaperManager?.stop()
        configManager?.save()
        print("👋 [App] Terminating")
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
    
    // MARK: - System Observers
    
    private func setupSystemObservers() {
        let workspace = NSWorkspace.shared
        let notificationCenter = workspace.notificationCenter
        let defaultCenter = NotificationCenter.default
        
        // Screen sleep/wake
        defaultCenter.addObserver(
            self,
            selector: #selector(handleScreenDidSleep),
            name: NSWorkspace.screensDidSleepNotification,
            object: nil
        )
        
        defaultCenter.addObserver(
            self,
            selector: #selector(handleScreenDidWake),
            name: NSWorkspace.screensDidWakeNotification,
            object: nil
        )
        
        // System sleep/wake
        notificationCenter.addObserver(
            self,
            selector: #selector(handleSystemWillSleep),
            name: NSWorkspace.willSleepNotification,
            object: nil
        )
        
        notificationCenter.addObserver(
            self,
            selector: #selector(handleSystemDidWake),
            name: NSWorkspace.didWakeNotification,
            object: nil
        )
        
        // Session events (login/logout)
        notificationCenter.addObserver(
            self,
            selector: #selector(handleSessionDidBecomeActive),
            name: NSWorkspace.sessionDidBecomeActiveNotification,
            object: nil
        )
        
        notificationCenter.addObserver(
            self,
            selector: #selector(handleSessionDidResignActive),
            name: NSWorkspace.sessionDidResignActiveNotification,
            object: nil
        )
        
        // 🔒 Screen lock/unlock (DistributedNotification - 화면 잠금 정확히 감지)
        DistributedNotificationCenter.default().addObserver(
            self,
            selector: #selector(handleScreenLocked),
            name: NSNotification.Name("com.apple.screenIsLocked"),
            object: nil
        )
        
        DistributedNotificationCenter.default().addObserver(
            self,
            selector: #selector(handleScreenUnlocked),
            name: NSNotification.Name("com.apple.screenIsUnlocked"),
            object: nil
        )
        
        // 🖥️ Screen saver start/stop (스크린세이버 진입 시 정지)
        DistributedNotificationCenter.default().addObserver(
            self,
            selector: #selector(handleScreenSaverStarted),
            name: NSNotification.Name("com.apple.screensaver.didstart"),
            object: nil
        )
        
        DistributedNotificationCenter.default().addObserver(
            self,
            selector: #selector(handleScreenSaverStopped),
            name: NSNotification.Name("com.apple.screensaver.didstop"),
            object: nil
        )
        
        // Display configuration changes
        defaultCenter.addObserver(
            self,
            selector: #selector(handleDisplayConfigurationChange),
            name: NSApplication.didChangeScreenParametersNotification,
            object: nil
        )
        
        print("✅ [Observers] System observers registered")
    }
    
    // MARK: - System Event Handlers
    
    @objc private func handleScreenDidSleep(_ notification: Notification) {
        print("😴 [System] Screen did sleep")
        guard !isRecoveringFromSleep else {
            print("😴 [System] Ignoring - already recovering")
            return
        }
        wasPlayingBeforeSleep = wallpaperManager?.isPlaying ?? false
        isSessionActive = false
        wallpaperManager?.pause()
        wallpaperManager?.hideWindows()  // 윈도우 숨기기
    }
    
    @objc private func handleScreenDidWake(_ notification: Notification) {
        print("☀️ [System] Screen did wake")
        // 세션이 활성화되지 않았으면 (잠금 상태) 무시
        guard isSessionActive else {
            print("☀️ [System] Ignoring - session not active (locked)")
            return
        }
        // 이미 복구 중이면 무시
        guard !isRecoveringFromSleep else {
            print("☀️ [System] Ignoring - already recovering")
            return
        }
        
        isRecoveringFromSleep = true
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) { [weak self] in
            self?.recoverFromSleep()
        }
    }
    
    @objc private func handleSystemWillSleep(_ notification: Notification) {
        print("😴 [System] System will sleep")
        wasPlayingBeforeSleep = wallpaperManager?.isPlaying ?? false
        wallpaperManager?.pause()
        wallpaperManager?.hideWindows()  // 윈도우 숨기기
    }
    
    @objc private func handleSystemDidWake(_ notification: Notification) {
        print("☀️ [System] System did wake")
        // 세션이 활성화되지 않았으면 (잠금 상태) 무시
        guard isSessionActive else {
            print("☀️ [System] Ignoring - session not active (locked)")
            return
        }
        // 이미 복구 중이면 무시
        guard !isRecoveringFromSleep else {
            print("☀️ [System] Ignoring - already recovering")
            return
        }
        
        isRecoveringFromSleep = true
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) { [weak self] in
            self?.recoverFromSleep()
        }
    }
    
    @objc private func handleSessionDidBecomeActive(_ notification: Notification) {
        print("🔓 [System] Session became active (user logged in or unlocked)")
        isSessionActive = true
        
        // 이미 복구 중이면 무시
        guard !isRecoveringFromSleep else {
            print("🔓 [System] Ignoring - already recovering")
            return
        }
        
        isRecoveringFromSleep = true
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) { [weak self] in
            self?.recoverFromSleep()
        }
    }
    
    @objc private func handleSessionDidResignActive(_ notification: Notification) {
        print("🔒 [System] Session resigned active (user logging out)")
        wasPlayingBeforeSleep = wallpaperManager?.isPlaying ?? false
        isSessionActive = false
        
        // Pause playback and hide windows (don't destroy)
        wallpaperManager?.pause()
        wallpaperManager?.hideWindows()
    }
    
    // MARK: - Screen Lock/Unlock (DistributedNotification)
    
    @objc private func handleScreenLocked(_ notification: Notification) {
        print("🔐 [System] Screen LOCKED - stopping playback completely")
        wasPlayingBeforeSleep = wallpaperManager?.isPlaying ?? false
        isSessionActive = false
        isRecoveringFromSleep = false
        
        // ⚠️ 잠금 시 항상 완전 정지 (스크린세이버/잠금 진입 방해 방지)
        wallpaperManager?.pause()
        wallpaperManager?.hideWindows()
    }
    
    @objc private func handleScreenSaverStarted(_ notification: Notification) {
        print("🖥️ [System] Screen Saver STARTED - pausing wallpaper")
        wasPlayingBeforeSleep = wallpaperManager?.isPlaying ?? false
        
        // 스크린세이버 시작 시 배경화면 정지 및 숨기기
        wallpaperManager?.pause()
        wallpaperManager?.hideWindows()
    }
    
    @objc private func handleScreenSaverStopped(_ notification: Notification) {
        print("🖥️ [System] Screen Saver STOPPED - resuming wallpaper")
        
        // 세션이 활성 상태일 때만 복구
        guard isSessionActive else {
            print("🖥️ [System] Session not active, skip resume")
            return
        }
        
        wallpaperManager?.showWindows()
        if wasPlayingBeforeSleep {
            wallpaperManager?.resume()
        }
    }
    
    @objc private func handleScreenUnlocked(_ notification: Notification) {
        print("🔓 [System] Screen UNLOCKED")
        isSessionActive = true
        
        // 이미 복구 중이면 무시
        guard !isRecoveringFromSleep else {
            print("🔓 [System] Ignoring - already recovering")
            return
        }
        
        isRecoveringFromSleep = true
        
        // 잠금 해제 후 잠시 대기하고 복구
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) { [weak self] in
            self?.recoverFromSleep()
        }
    }
    
    @objc private func handleDisplayConfigurationChange(_ notification: Notification) {
        print("🖥️ [System] Display configuration changed")
        
        // Don't recreate windows during recovery or when session is inactive (locked)
        guard !isRecoveringFromSleep else {
            print("🖥️ [System] Skipping - already recovering from sleep")
            return
        }
        
        guard isSessionActive else {
            print("🖥️ [System] Skipping - session not active (locked)")
            return
        }
        
        // Cancel any pending display change work
        displayChangeWorkItem?.cancel()
        
        // Debounce display changes with cancellable work item
        let workItem = DispatchWorkItem { [weak self] in
            guard let self = self else { return }
            guard !self.isRecoveringFromSleep, self.isSessionActive else { return }
            self.wallpaperManager?.handleDisplayChange()
        }
        displayChangeWorkItem = workItem
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5, execute: workItem)
    }
    
    // MARK: - Recovery
    
    private func recoverFromSleep() {
        guard isRecoveringFromSleep else { return }
        guard isSessionActive else {
            print("🔄 [Recovery] Cancelled - session not active")
            isRecoveringFromSleep = false
            return
        }
        isRecoveringFromSleep = false
        
        print("🔄 [Recovery] Starting recovery...")
        
        // Show windows first (don't recreate)
        wallpaperManager?.showWindows()
        
        // Resume playback if was playing before
        if wasPlayingBeforeSleep {
            wallpaperManager?.resume()
            print("▶️ [Recovery] Resumed playback")
        }
        
        print("✅ [Recovery] Complete")
    }
    
    // MARK: - Hotkeys
    
    private func setupHotkeys() {
        guard let hotkey = hotkeyManager else { return }
        
        hotkey.onAction = { [weak self] action, displayID in
            DispatchQueue.main.async {
                self?.handleHotkeyAction(action, displayID: displayID)
            }
        }
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
        window.title = "Skyloft WP"
        window.styleMask = [.titled, .closable, .miniaturizable]  // .resizable 제거 - 크기 고정
        window.setContentSize(NSSize(width: 1024, height: 768))
        window.minSize = NSSize(width: 1024, height: 768)
        window.maxSize = NSSize(width: 1024, height: 768)  // 최대 크기도 고정
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
