//
//  SchedulerService.swift
//  SkyloftWP
//
//  Handles scheduling, battery monitoring, and fullscreen detection
//

import Foundation
import AppKit
import IOKit.ps
import Combine

class SchedulerService: ObservableObject {
    
    // MARK: - Singleton
    
    static let shared = SchedulerService()
    
    // MARK: - Published Properties
    
    @Published var shouldPause = false
    @Published var pauseReason: PauseReason?
    @Published var isLowPowerMode = false  // 🔋 저전력 모드 상태
    
    // MARK: - Properties
    
    private let configManager = ConfigurationManager.shared
    private let wallpaperManager = WallpaperManager.shared
    
    private var scheduleTimer: Timer?
    private var batteryMonitor: Timer?
    private var fullscreenObserver: Any?
    private var cancellables = Set<AnyCancellable>()
    
    // MARK: - Initialization
    
    private init() {
        setupObservers()
        startMonitoring()
    }
    
    deinit {
        stopMonitoring()
    }
    
    // MARK: - Setup
    
    private func setupObservers() {
        configManager.$config
            .receive(on: DispatchQueue.main)
            .sink { [weak self] config in
                self?.handleConfigChange(config)
            }
            .store(in: &cancellables)
    }
    
    // MARK: - Monitoring
    
    // 통합 시스템 타이머 (배터리 + 스케줄을 하나로)
    private var systemTimer: Timer?
    private var lastScheduleCheck: Date = .distantPast
    
    func startMonitoring() {
        startSystemMonitoring()  // 배터리 + 스케줄 통합
        startFullscreenMonitoring()
    }
    
    func stopMonitoring() {
        systemTimer?.invalidate()
        systemTimer = nil
        
        scheduleTimer?.invalidate()
        scheduleTimer = nil
        
        batteryMonitor?.invalidate()
        batteryMonitor = nil
        
        if let observer = fullscreenObserver {
            NSWorkspace.shared.notificationCenter.removeObserver(observer)
        }
    }
    
    // MARK: - 통합 시스템 모니터링 (배터리 30초 + 스케줄 60초를 하나로)
    
    private func startSystemMonitoring() {
        // 30초마다 실행 (배터리 체크 주기)
        systemTimer = Timer.scheduledTimer(withTimeInterval: 30, repeats: true) { [weak self] _ in
            guard let self = self else { return }
            
            // 배터리 체크 (매번)
            self.checkBattery()
            
            // 스케줄 체크 (60초마다 - 마지막 체크로부터 55초 이상 경과 시)
            if Date().timeIntervalSince(self.lastScheduleCheck) >= 55 {
                self.checkSchedule()
                self.lastScheduleCheck = Date()
            }
        }
        
        // 초기 체크
        checkBattery()
        checkSchedule()
        lastScheduleCheck = Date()
    }
    
    // MARK: - Schedule Monitoring (Legacy - 통합 타이머로 대체됨)
    
    private func startScheduleMonitoring() {
        // 이제 startSystemMonitoring()에서 통합 처리됨
        // 기존 코드는 호환성을 위해 유지
        scheduleTimer = Timer.scheduledTimer(withTimeInterval: 60, repeats: true) { [weak self] _ in
            self?.checkSchedule()
        }
        
        // Initial check
        checkSchedule()
    }
    
    private func checkSchedule() {
        let config = configManager.config.schedule
        
        guard config.enabled else {
            if pauseReason == .outsideSchedule {
                shouldPause = false
                pauseReason = nil
            }
            return
        }
        
        let isWithinSchedule = isCurrentTimeWithinSchedule(
            start: config.activeHours.start,
            end: config.activeHours.end
        )
        
        if !isWithinSchedule {
            shouldPause = true
            pauseReason = .outsideSchedule
        } else if pauseReason == .outsideSchedule {
            shouldPause = false
            pauseReason = nil
        }
    }
    
    private func isCurrentTimeWithinSchedule(start: String, end: String) -> Bool {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm"
        
        guard let startTime = formatter.date(from: start),
              let endTime = formatter.date(from: end) else {
            return true  // Default to always active if parsing fails
        }
        
        let now = Date()
        let calendar = Calendar.current
        
        let currentMinutes = calendar.component(.hour, from: now) * 60 + calendar.component(.minute, from: now)
        let startMinutes = calendar.component(.hour, from: startTime) * 60 + calendar.component(.minute, from: startTime)
        let endMinutes = calendar.component(.hour, from: endTime) * 60 + calendar.component(.minute, from: endTime)
        
        if startMinutes <= endMinutes {
            return currentMinutes >= startMinutes && currentMinutes < endMinutes
        } else {
            // Schedule spans midnight
            return currentMinutes >= startMinutes || currentMinutes < endMinutes
        }
    }
    
    // MARK: - Battery Monitoring (Legacy - 통합 타이머로 대체됨)
    
    private func startBatteryMonitoring() {
        // 이제 startSystemMonitoring()에서 통합 처리됨
        // 기존 코드는 호환성을 위해 유지
        batteryMonitor = Timer.scheduledTimer(withTimeInterval: 30, repeats: true) { [weak self] _ in
            self?.checkBattery()
        }
        
        // Initial check
        checkBattery()
    }
    
    private func checkBattery() {
        let isOnBattery = !isPluggedIn()
        
        // 🔋 저전력 모드 상태 업데이트 및 알림
        let wasLowPower = isLowPowerMode
        isLowPowerMode = isOnBattery
        
        if isLowPowerMode != wasLowPower {
            NotificationCenter.default.post(name: .lowPowerModeDidChange, object: isLowPowerMode)
            print("🔋 [Energy] Low power mode: \(isLowPowerMode ? "ON" : "OFF")")
        }
        
        guard configManager.config.schedule.pauseOnBattery else {
            if pauseReason == .batteryMode {
                shouldPause = false
                pauseReason = nil
            }
            return
        }
        
        if isOnBattery {
            shouldPause = true
            pauseReason = .batteryMode
        } else if pauseReason == .batteryMode {
            shouldPause = false
            pauseReason = nil
        }
    }
    
    private func isPluggedIn() -> Bool {
        let snapshot = IOPSCopyPowerSourcesInfo().takeRetainedValue()
        let sources = IOPSCopyPowerSourcesList(snapshot).takeRetainedValue() as [CFTypeRef]
        
        for source in sources {
            if let description = IOPSGetPowerSourceDescription(snapshot, source).takeUnretainedValue() as? [String: Any] {
                if let powerSource = description[kIOPSPowerSourceStateKey] as? String {
                    return powerSource == kIOPSACPowerValue
                }
            }
        }
        
        // Assume plugged in if we can't determine (desktop Mac)
        return true
    }
    
    // MARK: - Fullscreen Monitoring
    
    private func startFullscreenMonitoring() {
        fullscreenObserver = NSWorkspace.shared.notificationCenter.addObserver(
            forName: NSWorkspace.activeSpaceDidChangeNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.checkFullscreen()
        }
        
        // Also check when active app changes
        NSWorkspace.shared.notificationCenter.addObserver(
            forName: NSWorkspace.didActivateApplicationNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.checkFullscreen()
        }
        
        // Initial check
        checkFullscreen()
    }
    
    private func checkFullscreen() {
        guard configManager.config.schedule.pauseOnFullscreen else {
            if pauseReason == .fullscreenApp {
                shouldPause = false
                pauseReason = nil
            }
            return
        }
        
        let hasFullscreenApp = isAnyAppFullscreen()
        
        if hasFullscreenApp {
            shouldPause = true
            pauseReason = .fullscreenApp
        } else if pauseReason == .fullscreenApp {
            shouldPause = false
            pauseReason = nil
        }
    }
    
    private func isAnyAppFullscreen() -> Bool {
        // Check if any window is in fullscreen mode
        let options: CGWindowListOption = [.optionOnScreenOnly, .excludeDesktopElements]
        
        guard let windowList = CGWindowListCopyWindowInfo(options, kCGNullWindowID) as? [[String: Any]] else {
            return false
        }
        
        for window in windowList {
            // Check if window covers full screen
            if let bounds = window[kCGWindowBounds as String] as? [String: CGFloat],
               let ownerName = window[kCGWindowOwnerName as String] as? String {
                
                // Skip our own app and Finder
                if ownerName == "SkyloftWP" || ownerName == "SkyloftWP" || ownerName == "Finder" || ownerName == "Dock" {
                    continue
                }
                
                // Check if window is approximately full screen size
                if let screen = NSScreen.main {
                    let windowWidth = bounds["Width"] ?? 0
                    let windowHeight = bounds["Height"] ?? 0
                    
                    let screenFrame = screen.frame
                    let isFullWidth = windowWidth >= screenFrame.width * 0.95
                    let isFullHeight = windowHeight >= screenFrame.height * 0.95
                    
                    if isFullWidth && isFullHeight {
                        return true
                    }
                }
            }
        }
        
        return false
    }
    
    // MARK: - Config Changes
    
    private func handleConfigChange(_ config: AppConfiguration) {
        // Re-check all conditions when config changes
        checkSchedule()
        checkBattery()
        checkFullscreen()
    }
}

// MARK: - Pause Reason

enum PauseReason: String {
    case outsideSchedule = "스케줄 시간 외"
    case batteryMode = "배터리 모드"
    case fullscreenApp = "전체화면 앱 실행 중"
    case userPaused = "사용자가 일시정지"
    
    var icon: String {
        switch self {
        case .outsideSchedule: return "clock"
        case .batteryMode: return "battery.25"
        case .fullscreenApp: return "rectangle.fill"
        case .userPaused: return "pause.fill"
        }
    }
}

