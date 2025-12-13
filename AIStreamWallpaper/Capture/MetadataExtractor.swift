//
//  MetadataExtractor.swift
//  AIStreamWallpaper
//
//  Extracts metadata from Midjourney TV page
//

import Foundation
import WebKit

class MetadataExtractor {
    
    // MARK: - Singleton
    
    static let shared = MetadataExtractor()
    
    // MARK: - Properties
    
    private var cachedMetadata: VideoMetadata?
    
    // MARK: - Public Methods
    
    /// Extracts metadata from the current page using JavaScript
    func extractMetadata(from webView: WKWebView, completion: @escaping (VideoMetadata?) -> Void) {
        let script = """
        (function() {
            // Try to extract prompt
            let prompt = null;
            let author = null;
            let jobId = null;
            
            // Look for prompt in various elements
            const promptSelectors = [
                '[class*="prompt"]',
                '[data-prompt]',
                '.description',
                '.caption'
            ];
            
            for (const selector of promptSelectors) {
                const element = document.querySelector(selector);
                if (element && element.textContent.trim()) {
                    prompt = element.textContent.trim();
                    break;
                }
            }
            
            // Look for author/username
            const authorSelectors = [
                '[class*="author"]',
                '[class*="username"]',
                '[class*="creator"]',
                'a[href*="/u/"]'
            ];
            
            for (const selector of authorSelectors) {
                const element = document.querySelector(selector);
                if (element && element.textContent.trim()) {
                    author = element.textContent.trim();
                    break;
                }
            }
            
            // Try to extract job ID from URL or page content
            const urlMatch = window.location.href.match(/jobs\\/([a-f0-9-]+)/);
            if (urlMatch) {
                jobId = urlMatch[1];
            }
            
            // Also check links on the page
            const links = document.querySelectorAll('a[href*="jobs"]');
            for (const link of links) {
                const match = link.href.match(/jobs\\/([a-f0-9-]+)/);
                if (match) {
                    jobId = match[1];
                    break;
                }
            }
            
            // Get current video source
            let videoSrc = null;
            const video = document.querySelector('video');
            if (video) {
                videoSrc = video.src || video.currentSrc;
            }
            
            return {
                prompt: prompt,
                author: author,
                jobId: jobId,
                videoSrc: videoSrc,
                pageUrl: window.location.href
            };
        })();
        """
        
        webView.evaluateJavaScript(script) { [weak self] result, error in
            guard let dict = result as? [String: Any] else {
                completion(nil)
                return
            }
            
            let metadata = VideoMetadata(
                sourceUrl: dict["videoSrc"] as? String ?? dict["pageUrl"] as? String ?? "",
                prompt: dict["prompt"] as? String,
                author: dict["author"] as? String,
                midjourneyJobId: dict["jobId"] as? String
            )
            
            self?.cachedMetadata = metadata
            completion(metadata)
        }
    }
    
    /// Extracts metadata from a Midjourney job URL
    func extractFromJobURL(_ url: URL) -> (jobId: String?, index: Int?) {
        // Pattern: https://midjourney.com/jobs/{job-id}?index={index}
        let path = url.path
        let components = path.components(separatedBy: "/")
        
        var jobId: String?
        if let jobsIndex = components.firstIndex(of: "jobs"),
           jobsIndex + 1 < components.count {
            jobId = components[jobsIndex + 1]
        }
        
        var index: Int?
        if let queryItems = URLComponents(url: url, resolvingAgainstBaseURL: false)?.queryItems {
            if let indexString = queryItems.first(where: { $0.name == "index" })?.value {
                index = Int(indexString)
            }
        }
        
        return (jobId, index)
    }
    
    /// Cleans and formats a prompt string
    func cleanPrompt(_ prompt: String) -> String {
        var cleaned = prompt
        
        // Remove common prefixes
        let prefixes = ["Prompt:", "prompt:", "--", "—"]
        for prefix in prefixes {
            if cleaned.hasPrefix(prefix) {
                cleaned = String(cleaned.dropFirst(prefix.count))
            }
        }
        
        // Trim whitespace
        cleaned = cleaned.trimmingCharacters(in: .whitespacesAndNewlines)
        
        // Limit length
        if cleaned.count > 500 {
            cleaned = String(cleaned.prefix(500)) + "..."
        }
        
        return cleaned
    }
    
    /// Gets cached metadata
    func getCachedMetadata() -> VideoMetadata? {
        return cachedMetadata
    }
    
    /// Clears cached metadata
    func clearCache() {
        cachedMetadata = nil
    }
}



