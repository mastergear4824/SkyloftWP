//
//  HotkeyManager.swift
//  SkyloftWP
//
//  Global keyboard shortcut handling with customizable shortcuts
//

import AppKit
import Carbon
import Combine

// MARK: - Hotkey Definition

struct HotkeyDefinition: Codable, Equatable {
    var keyCode: UInt16
    var modifiers: UInt  // NSEvent.ModifierFlags raw value
    
    var displayString: String {
        var parts: [String] = []
        let flags = NSEvent.ModifierFlags(rawValue: modifiers)
        
        if flags.contains(.control) { parts.append("⌃") }
        if flags.contains(.option) { parts.append("⌥") }
        if flags.contains(.shift) { parts.append("⇧") }
        if flags.contains(.command) { parts.append("⌘") }
        
        parts.append(keyCodeToString(keyCode))
        return parts.joined()
    }
    
    private func keyCodeToString(_ keyCode: UInt16) -> String {
        switch keyCode {
        case 0: return "A"
        case 1: return "S"
        case 2: return "D"
        case 3: return "F"
        case 4: return "H"
        case 5: return "G"
        case 6: return "Z"
        case 7: return "X"
        case 8: return "C"
        case 9: return "V"
        case 11: return "B"
        case 12: return "Q"
        case 13: return "W"
        case 14: return "E"
        case 15: return "R"
        case 16: return "Y"
        case 17: return "T"
        case 18: return "1"
        case 19: return "2"
        case 20: return "3"
        case 21: return "4"
        case 22: return "6"
        case 23: return "5"
        case 24: return "="
        case 25: return "9"
        case 26: return "7"
        case 27: return "-"
        case 28: return "8"
        case 29: return "0"
        case 30: return "]"
        case 31: return "O"
        case 32: return "U"
        case 33: return "["
        case 34: return "I"
        case 35: return "P"
        case 37: return "L"
        case 38: return "J"
        case 39: return "'"
        case 40: return "K"
        case 41: return ";"
        case 42: return "\\"
        case 43: return ","
        case 44: return "/"
        case 45: return "N"
        case 46: return "M"
        case 47: return "."
        case 49: return "Space"
        case 50: return "`"
        case 51: return "⌫"
        case 53: return "Esc"
        case 96: return "F5"
        case 97: return "F6"
        case 98: return "F7"
        case 99: return "F3"
        case 100: return "F8"
        case 101: return "F9"
        case 103: return "F11"
        case 105: return "F13"
        case 107: return "F14"
        case 109: return "F10"
        case 111: return "F12"
        case 113: return "F15"
        case 118: return "F4"
        case 119: return "End"
        case 120: return "F2"
        case 121: return "PgDn"
        case 122: return "F1"
        case 123: return "←"
        case 124: return "→"
        case 125: return "↓"
        case 126: return "↑"
        default: return "?"
        }
    }
    
    static func `default`(for action: HotkeyAction) -> HotkeyDefinition {
        let optCmd = NSEvent.ModifierFlags([.option, .command]).rawValue
        
        switch action {
        case .nextVideo: return HotkeyDefinition(keyCode: 124, modifiers: optCmd) // ⌥⌘→
        case .prevVideo: return HotkeyDefinition(keyCode: 123, modifiers: optCmd) // ⌥⌘←
        case .saveVideo: return HotkeyDefinition(keyCode: 1, modifiers: optCmd)   // ⌥⌘S
        case .toggleMute: return HotkeyDefinition(keyCode: 46, modifiers: optCmd) // ⌥⌘M
        case .togglePlayPause: return HotkeyDefinition(keyCode: 35, modifiers: optCmd) // ⌥⌘P
        case .openLibrary: return HotkeyDefinition(keyCode: 37, modifiers: optCmd) // ⌥⌘L
        case .copyPrompt: return HotkeyDefinition(keyCode: 8, modifiers: optCmd)  // ⌥⌘C
        case .showControls: return HotkeyDefinition(keyCode: 13, modifiers: optCmd) // ⌥⌘W
        }
    }
}

enum HotkeyAction: String, CaseIterable, Codable {
    case nextVideo
    case prevVideo
    case saveVideo
    case toggleMute
    case togglePlayPause
    case openLibrary
    case copyPrompt
    case showControls
    
    var localizedName: String {
        switch self {
        case .nextVideo: return L("shortcuts.nextVideo")
        case .prevVideo: return L("shortcuts.prevVideo")
        case .saveVideo: return L("shortcuts.saveVideo")
        case .toggleMute: return L("shortcuts.toggleMute")
        case .togglePlayPause: return L("shortcuts.playPause")
        case .openLibrary: return L("shortcuts.openLibrary")
        case .copyPrompt: return L("shortcuts.copyPrompt")
        case .showControls: return L("shortcuts.showControls")
        }
    }
}

// MARK: - Hotkey Configuration

struct HotkeyConfiguration: Codable {
    var hotkeys: [HotkeyAction: HotkeyDefinition]
    
    static var `default`: HotkeyConfiguration {
        var config = HotkeyConfiguration(hotkeys: [:])
        for action in HotkeyAction.allCases {
            config.hotkeys[action] = .default(for: action)
        }
        return config
    }
    
    func displayString(for action: HotkeyAction) -> String {
        hotkeys[action]?.displayString ?? HotkeyDefinition.default(for: action).displayString
    }
}

// MARK: - Hotkey Manager

class HotkeyManager: ObservableObject {
    
    // MARK: - Singleton
    
    static let shared = HotkeyManager()
    
    // MARK: - Properties
    
    private var globalMonitor: Any?
    private var localMonitor: Any?
    
    @Published var isEnabled = true
    @Published var configuration: HotkeyConfiguration
    @Published var isCapturing = false
    @Published var capturingAction: HotkeyAction?
    
    // MARK: - Callbacks
    
    var onAction: ((HotkeyAction, CGDirectDisplayID?) -> Void)?
    
    // MARK: - Initialization
    
    private init() {
        configuration = Self.loadConfiguration() ?? .default
        setupMonitors()
    }
    
    deinit {
        removeMonitors()
    }
    
    // MARK: - Configuration Persistence
    
    private static func loadConfiguration() -> HotkeyConfiguration? {
        guard let data = UserDefaults.standard.data(forKey: "HotkeyConfiguration") else { return nil }
        return try? JSONDecoder().decode(HotkeyConfiguration.self, from: data)
    }
    
    func saveConfiguration() {
        if let data = try? JSONEncoder().encode(configuration) {
            UserDefaults.standard.set(data, forKey: "HotkeyConfiguration")
        }
    }
    
    // MARK: - Setup
    
    func setupMonitors() {
        removeMonitors()
        
        guard isEnabled else { return }
        
        // Only setup global monitor if we have permission
        // This avoids the system prompt and saves CPU if not needed
        if Self.hasAccessibilityPermission {
            globalMonitor = NSEvent.addGlobalMonitorForEvents(matching: .keyDown) { [weak self] event in
                self?.handleKeyEvent(event)
            }
            print("Global hotkey monitor installed")
        }
        
        // Local monitor (always works, no permission needed)
        localMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            if self?.handleKeyEvent(event) == true {
                return nil
            }
            return event
        }
    }
    
    func removeMonitors() {
        if let monitor = globalMonitor {
            NSEvent.removeMonitor(monitor)
            globalMonitor = nil
        }
        if let monitor = localMonitor {
            NSEvent.removeMonitor(monitor)
            localMonitor = nil
        }
    }
    
    func setEnabled(_ enabled: Bool) {
        isEnabled = enabled
        if enabled {
            setupMonitors()
        } else {
            removeMonitors()
        }
    }
    
    // MARK: - Shortcut Capture
    
    func startCapturing(for action: HotkeyAction) {
        isCapturing = true
        capturingAction = action
    }
    
    func captureShortcut(from event: NSEvent) -> Bool {
        guard isCapturing, let action = capturingAction else { return false }
        
        // Require at least one modifier
        let modifiers = event.modifierFlags.intersection([.command, .option, .control, .shift])
        guard !modifiers.isEmpty else { return false }
        
        // Don't capture modifier-only presses
        let keyCode = event.keyCode
        guard keyCode != 55 && keyCode != 54 && keyCode != 58 && keyCode != 61 && keyCode != 59 && keyCode != 56 && keyCode != 60 && keyCode != 62 else {
            return false
        }
        
        let newHotkey = HotkeyDefinition(keyCode: keyCode, modifiers: modifiers.rawValue)
        configuration.hotkeys[action] = newHotkey
        saveConfiguration()
        
        isCapturing = false
        capturingAction = nil
        
        return true
    }
    
    func cancelCapture() {
        isCapturing = false
        capturingAction = nil
    }
    
    func resetToDefault(for action: HotkeyAction) {
        configuration.hotkeys[action] = .default(for: action)
        saveConfiguration()
    }
    
    func resetAllToDefault() {
        configuration = .default
        saveConfiguration()
    }
    
    // MARK: - Key Event Handling
    
    @discardableResult
    private func handleKeyEvent(_ event: NSEvent) -> Bool {
        // Quick exit if no modifiers (most key events)
        let modifiers = event.modifierFlags.intersection([.command, .option, .control, .shift])
        guard !modifiers.isEmpty else { return false }
        
        // Check if capturing
        if isCapturing {
            return captureShortcut(from: event)
        }
        
        let keyCode = event.keyCode
        let modifiersRaw = modifiers.rawValue
        
        // Find matching action using lazy evaluation
        if let action = configuration.hotkeys.first(where: { 
            $0.value.keyCode == keyCode && $0.value.modifiers == modifiersRaw 
        })?.key {
            // Get display under mouse cursor only when needed
            let displayID = getDisplayUnderMouse()
            onAction?(action, displayID)
            return true
        }
        
        return false
    }
    
    // MARK: - Mouse Position Detection
    
    private func getDisplayUnderMouse() -> CGDirectDisplayID? {
        let mouseLocation = NSEvent.mouseLocation
        
        // Convert to screen coordinates and find the display
        for screen in NSScreen.screens {
            if screen.frame.contains(mouseLocation) {
                // Get the display ID for this screen
                if let displayID = screen.deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? CGDirectDisplayID {
                    return displayID
                }
            }
        }
        
        return CGMainDisplayID()
    }
}

// MARK: - Accessibility Permission

extension HotkeyManager {
    
    /// Check permission WITHOUT showing prompt
    static var hasAccessibilityPermission: Bool {
        // This should never trigger a prompt
        return AXIsProcessTrusted()
    }
    
    /// Explicitly request permission - only call when user clicks button
    static func requestAccessibilityPermission() {
        let options: [String: Any] = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true]
        _ = AXIsProcessTrustedWithOptions(options as CFDictionary)
    }
}
