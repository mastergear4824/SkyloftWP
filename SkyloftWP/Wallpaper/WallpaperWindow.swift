//
//  WallpaperWindow.swift
//  SkyloftWP
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
        // Set window level below desktop icons (lowest possible)
        level = NSWindow.Level(rawValue: Int(CGWindowLevelForKey(.desktopWindow)) - 1)
        
        // Configure behavior - 스크린세이버/잠금 진입 방해하지 않도록
        collectionBehavior = [
            .canJoinAllSpaces,      // Show on all spaces
            .stationary,            // Don't move with space changes
            .ignoresCycle,          // Don't show in Cmd+Tab
            .fullScreenAuxiliary,   // Don't interfere with fullscreen
            .transient              // 일시적 윈도우 (스크린세이버 방해 안함)
        ]
        
        // Window appearance
        isOpaque = false
        backgroundColor = .clear
        hasShadow = false
        ignoresMouseEvents = true  // Pass through mouse events
        
        // Prevent window from appearing in screenshots/recordings
        sharingType = .none
        
        // Disable animations to prevent crashes during sleep/wake
        animationBehavior = .none
        
        // ⚠️ 스크린세이버/잠금 진입 방해하지 않도록 추가 설정
        hidesOnDeactivate = false  // 앱 비활성화 시에도 표시
        
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
    
    /// Safely hide window without deallocation issues
    func safeHide() {
        orderOut(nil)
    }
    
    /// Safely show window
    func safeShow() {
        orderFrontRegardless()
    }
    
    /// Clean up before closing - call this before close()
    func prepareForClose() {
        // Remove all subviews first
        contentView?.subviews.forEach { subview in
            subview.removeFromSuperview()
        }
        // Hide window
        orderOut(nil)
    }
    
    // MARK: - Overrides
    
    override var canBecomeKey: Bool { false }
    override var canBecomeMain: Bool { false }
    
    override func constrainFrameRect(_ frameRect: NSRect, to screen: NSScreen?) -> NSRect {
        // Don't constrain - allow full screen coverage
        return frameRect
    }
}
