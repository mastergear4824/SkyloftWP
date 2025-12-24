//
//  MonitorManager.swift
//  SkyloftWP
//
//  Multi-monitor detection and management
//

import AppKit
import Combine

class MonitorManager: ObservableObject {
    
    // MARK: - Singleton
    
    static let shared = MonitorManager()
    
    // MARK: - Published Properties
    
    @Published var monitors: [Monitor] = []
    @Published var primaryMonitor: Monitor?
    
    // MARK: - Private Properties
    
    private var displayObserver: Any?
    private var cancellables = Set<AnyCancellable>()
    
    // MARK: - Initialization
    
    private init() {
        updateMonitors()
        setupDisplayObserver()
    }
    
    deinit {
        if let observer = displayObserver {
            NotificationCenter.default.removeObserver(observer)
        }
    }
    
    // MARK: - Public Methods
    
    func updateMonitors() {
        monitors = NSScreen.screens.enumerated().map { index, screen in
            Monitor(
                id: screen.deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? CGDirectDisplayID ?? CGDirectDisplayID(index),
                name: screen.localizedName,
                frame: screen.frame,
                isPrimary: screen == NSScreen.main,
                isBuiltIn: screen.deviceDescription[NSDeviceDescriptionKey("NSDeviceIsScreen")] != nil
            )
        }
        
        primaryMonitor = monitors.first { $0.isPrimary }
        
        print("Detected \(monitors.count) monitor(s)")
    }
    
    func screen(for monitor: Monitor) -> NSScreen? {
        NSScreen.screens.first { screen in
            let displayId = screen.deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? CGDirectDisplayID
            return displayId == monitor.id
        }
    }
    
    func monitor(for screen: NSScreen) -> Monitor? {
        let displayId = screen.deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? CGDirectDisplayID
        return monitors.first { $0.id == displayId }
    }
    
    // MARK: - Private Methods
    
    private func setupDisplayObserver() {
        displayObserver = NotificationCenter.default.addObserver(
            forName: NSApplication.didChangeScreenParametersNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.updateMonitors()
        }
    }
}

// MARK: - Monitor Model

struct Monitor: Identifiable, Equatable {
    let id: CGDirectDisplayID
    let name: String
    let frame: NSRect
    let isPrimary: Bool
    let isBuiltIn: Bool
    
    var displayName: String {
        if isPrimary {
            return "\(name) (Primary)"
        }
        return name
    }
    
    var resolution: String {
        "\(Int(frame.width)) x \(Int(frame.height))"
    }
}



