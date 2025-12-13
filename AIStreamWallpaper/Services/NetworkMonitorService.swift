//
//  NetworkMonitorService.swift
//  AIStreamWallpaper
//
//  Monitors network connectivity and triggers fallback to cached playback
//

import Foundation
import Network
import Combine

class NetworkMonitorService: ObservableObject {
    
    // MARK: - Singleton
    
    static let shared = NetworkMonitorService()
    
    // MARK: - Published Properties
    
    @Published private(set) var isConnected = true
    @Published private(set) var connectionType: ConnectionType = .unknown
    
    enum ConnectionType {
        case wifi
        case cellular
        case ethernet
        case unknown
    }
    
    // MARK: - Properties
    
    private let monitor = NWPathMonitor()
    private let queue = DispatchQueue(label: "NetworkMonitor", qos: .utility)
    
    var onConnectionLost: (() -> Void)?
    var onConnectionRestored: (() -> Void)?
    
    // MARK: - Initialization
    
    private init() {
        startMonitoring()
    }
    
    deinit {
        stopMonitoring()
    }
    
    // MARK: - Monitoring
    
    func startMonitoring() {
        monitor.pathUpdateHandler = { [weak self] path in
            DispatchQueue.main.async {
                let wasConnected = self?.isConnected ?? true
                let isNowConnected = path.status == .satisfied
                
                self?.isConnected = isNowConnected
                self?.connectionType = self?.getConnectionType(path) ?? .unknown
                
                // Trigger callbacks on state change
                if wasConnected && !isNowConnected {
                    print("Network connection lost")
                    self?.onConnectionLost?()
                } else if !wasConnected && isNowConnected {
                    print("Network connection restored")
                    self?.onConnectionRestored?()
                }
            }
        }
        
        monitor.start(queue: queue)
    }
    
    func stopMonitoring() {
        monitor.cancel()
    }
    
    private func getConnectionType(_ path: NWPath) -> ConnectionType {
        if path.usesInterfaceType(.wifi) {
            return .wifi
        } else if path.usesInterfaceType(.cellular) {
            return .cellular
        } else if path.usesInterfaceType(.wiredEthernet) {
            return .ethernet
        }
        return .unknown
    }
}



