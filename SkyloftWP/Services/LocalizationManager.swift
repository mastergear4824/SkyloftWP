//
//  LocalizationManager.swift
//  SkyloftWP
//
//  Handles app localization and language switching
//

import Foundation
import SwiftUI

// MARK: - Language

enum AppLanguage: String, Codable, CaseIterable, Identifiable {
    case system = "system"
    case english = "en"
    case korean = "ko"
    case japanese = "ja"
    
    var id: String { rawValue }
    
    var displayName: String {
        switch self {
        case .system: return "System Default"  // 언어 변경 전에도 표시되어야 함
        case .english: return "English"
        case .korean: return "한국어"
        case .japanese: return "日本語"
        }
    }
    
    var localeIdentifier: String? {
        switch self {
        case .system: return nil
        case .english: return "en"
        case .korean: return "ko"
        case .japanese: return "ja"
        }
    }
}

// MARK: - Localization Manager

class LocalizationManager: ObservableObject {
    
    // MARK: - Singleton
    
    static let shared = LocalizationManager()
    
    // MARK: - Properties
    
    @Published var currentLanguage: AppLanguage = .system
    
    private var bundle: Bundle = .main
    
    // MARK: - Initialization
    
    private init() {
        loadLanguagePreference()
    }
    
    // MARK: - Public Methods
    
    func setLanguage(_ language: AppLanguage) {
        currentLanguage = language
        saveLanguagePreference()
        updateBundle()
        
        // Post notification for UI refresh
        NotificationCenter.default.post(name: .languageDidChange, object: language)
    }
    
    func localizedString(_ key: String) -> String {
        return bundle.localizedString(forKey: key, value: nil, table: nil)
    }
    
    func localizedString(_ key: String, comment: String) -> String {
        return bundle.localizedString(forKey: key, value: nil, table: nil)
    }
    
    // MARK: - Private Methods
    
    private func loadLanguagePreference() {
        if let savedLanguage = UserDefaults.standard.string(forKey: "AppLanguage"),
           let language = AppLanguage(rawValue: savedLanguage) {
            currentLanguage = language
        }
        updateBundle()
    }
    
    private func saveLanguagePreference() {
        UserDefaults.standard.set(currentLanguage.rawValue, forKey: "AppLanguage")
    }
    
    private func updateBundle() {
        let languageCode: String
        
        switch currentLanguage {
        case .system:
            // 시스템 언어 확인 (한국어, 일본어만 지원, 나머지는 영어)
            let systemLanguage = Locale.preferredLanguages.first?.prefix(2).description ?? "en"
            let supportedLanguages = ["ko", "ja"]
            languageCode = supportedLanguages.contains(systemLanguage) ? systemLanguage : "en"
        case .english:
            languageCode = "en"
        case .korean:
            languageCode = "ko"
        case .japanese:
            languageCode = "ja"
        }
        
        // Find the bundle for the language
        if let path = Bundle.main.path(forResource: languageCode, ofType: "lproj"),
           let langBundle = Bundle(path: path) {
            bundle = langBundle
        } else if let path = Bundle.main.path(forResource: "en", ofType: "lproj"),
                  let defaultBundle = Bundle(path: path) {
            // Fallback to English
            bundle = defaultBundle
        } else {
            bundle = .main
        }
        
        // 즉시 UI 갱신을 위해 objectWillChange 발송
        DispatchQueue.main.async { [weak self] in
            self?.objectWillChange.send()
        }
    }
}

// MARK: - Notification

extension Notification.Name {
    static let languageDidChange = Notification.Name("languageDidChange")
}

// MARK: - Convenience Function

/// Shorthand for localized string
func L(_ key: String) -> String {
    return LocalizationManager.shared.localizedString(key)
}

// MARK: - SwiftUI Text Extension

extension Text {
    init(localized key: String) {
        self.init(L(key))
    }
}

// MARK: - String Extension

extension String {
    var localized: String {
        return L(self)
    }
}

