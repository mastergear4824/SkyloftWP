//
//  VideoInterceptor.swift
//  AIStreamWallpaper
//
//  Intercepts video URLs from WebView for download
//

import Foundation
import WebKit

class VideoInterceptor: NSObject {
    
    // MARK: - Properties
    
    var onVideoDetected: ((URL, VideoMetadata) -> Void)?
    
    private var detectedVideos: Set<String> = []
    private let videoExtensions = ["mp4", "webm", "mov", "m4v", "avi", "mkv"]
    private let videoMimeTypes = ["video/mp4", "video/webm", "video/quicktime", "video/x-m4v"]
    
    // MARK: - Public Methods
    
    func isVideoURL(_ url: URL) -> Bool {
        let pathExtension = url.pathExtension.lowercased()
        if videoExtensions.contains(pathExtension) {
            return true
        }
        
        // Check URL path for video indicators
        let path = url.path.lowercased()
        return path.contains("/video/") || path.contains("/media/") || path.contains(".mp4") || path.contains(".webm")
    }
    
    func isVideoMimeType(_ mimeType: String) -> Bool {
        return videoMimeTypes.contains(mimeType.lowercased())
    }
    
    func handleDetectedVideo(url: URL, metadata: VideoMetadata?) {
        let urlString = url.absoluteString
        
        // Avoid duplicate detections
        guard !detectedVideos.contains(urlString) else { return }
        detectedVideos.insert(urlString)
        
        let finalMetadata = metadata ?? VideoMetadata(sourceUrl: urlString)
        
        print("Detected video: \(urlString)")
        onVideoDetected?(url, finalMetadata)
    }
    
    func reset() {
        detectedVideos.removeAll()
    }
}

// MARK: - WKURLSchemeHandler for custom scheme interception

class VideoSchemeHandler: NSObject, WKURLSchemeHandler {
    
    weak var interceptor: VideoInterceptor?
    
    func webView(_ webView: WKWebView, start urlSchemeTask: WKURLSchemeTask) {
        guard let url = urlSchemeTask.request.url else {
            urlSchemeTask.didFailWithError(NSError(domain: "VideoSchemeHandler", code: -1))
            return
        }
        
        // Convert custom scheme back to https
        var components = URLComponents(url: url, resolvingAgainstBaseURL: false)
        components?.scheme = "https"
        
        guard let httpsURL = components?.url else {
            urlSchemeTask.didFailWithError(NSError(domain: "VideoSchemeHandler", code: -2))
            return
        }
        
        // Check if this is a video URL
        if interceptor?.isVideoURL(httpsURL) == true {
            let metadata = VideoMetadata(sourceUrl: httpsURL.absoluteString)
            interceptor?.handleDetectedVideo(url: httpsURL, metadata: metadata)
        }
        
        // Forward the request
        let task = URLSession.shared.dataTask(with: httpsURL) { data, response, error in
            if let error = error {
                urlSchemeTask.didFailWithError(error)
                return
            }
            
            if let response = response {
                urlSchemeTask.didReceive(response)
            }
            
            if let data = data {
                urlSchemeTask.didReceive(data)
            }
            
            urlSchemeTask.didFinish()
        }
        task.resume()
    }
    
    func webView(_ webView: WKWebView, stop urlSchemeTask: WKURLSchemeTask) {
        // Handle cancellation if needed
    }
}

// MARK: - Network Request Monitor

class NetworkMonitor {
    
    static let shared = NetworkMonitor()
    
    var onVideoURLDetected: ((URL) -> Void)?
    
    private var observation: NSKeyValueObservation?
    
    func startMonitoring(webView: WKWebView) {
        // Monitor webView URL changes
        observation = webView.observe(\.url, options: [.new]) { [weak self] webView, change in
            if let url = change.newValue as? URL {
                self?.checkURL(url)
            }
        }
    }
    
    func stopMonitoring() {
        observation?.invalidate()
        observation = nil
    }
    
    private func checkURL(_ url: URL) {
        let videoExtensions = ["mp4", "webm", "mov", "m4v"]
        if videoExtensions.contains(url.pathExtension.lowercased()) {
            onVideoURLDetected?(url)
        }
    }
}



