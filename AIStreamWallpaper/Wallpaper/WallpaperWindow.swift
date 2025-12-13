//
//  WallpaperWindow.swift
//  AIStreamWallpaper
//
//  Desktop layer window for wallpaper display
//

import AppKit

class WallpaperWindow: NSWindow {
    
    // MARK: - Properties
    
    var targetScreen: NSScreen?
    
    // MARK: - Initialization
    
    convenience init(screen: NSScreen) {
        self.init(
            contentRect: screen.frame,
            styleMask: .borderless,
            backing: .buffered,
            defer: false
        )
        
        self.targetScreen = screen
        configureWindow(for: screen)
    }
    
    override init(
        contentRect: NSRect,
        styleMask style: NSWindow.StyleMask,
        backing backingStoreType: NSWindow.BackingStoreType,
        defer flag: Bool
    ) {
        super.init(contentRect: contentRect, styleMask: style, backing: backingStoreType, defer: flag)
    }
    
    // MARK: - Configuration
    
    private func configureWindow(for screen: NSScreen) {
        // Set window level below desktop icons
        level = NSWindow.Level(rawValue: Int(CGWindowLevelForKey(.desktopWindow)))
        
        // Configure behavior
        collectionBehavior = [
            .canJoinAllSpaces,      // Show on all spaces
            .stationary,            // Don't move with space changes
            .ignoresCycle,          // Don't show in Cmd+Tab
            .fullScreenAuxiliary    // Don't interfere with fullscreen
        ]
        
        // Window appearance
        isOpaque = false
        backgroundColor = .clear
        hasShadow = false
        ignoresMouseEvents = true  // Pass through mouse events
        
        // Prevent window from appearing in screenshots/recordings
        sharingType = .none
        
        // Set frame to cover entire screen
        setFrame(screen.frame, display: true)
        
        // Show window without activating app
        orderFrontRegardless()
    }
    
    // MARK: - Public Methods
    
    func updateForScreen(_ screen: NSScreen) {
        targetScreen = screen
        setFrame(screen.frame, display: true)
    }
    
    // MARK: - Overrides
    
    override var canBecomeKey: Bool { false }
    override var canBecomeMain: Bool { false }
    
    override func constrainFrameRect(_ frameRect: NSRect, to screen: NSScreen?) -> NSRect {
        // Don't constrain - allow full screen coverage
        return frameRect
    }
}
