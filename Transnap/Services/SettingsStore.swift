//
//  SettingsStore.swift
//  Transnap
//
//  Created by Codex on 2026/4/11.
//

import Carbon
import Combine
import Foundation

enum PreferredTargetLanguage: String, CaseIterable, Identifiable {
    case automatic
    case simplifiedChinese
    case english

    var id: String { rawValue }

    var title: String {
        switch self {
        case .automatic:
            return "跟随系统自动判断"
        case .simplifiedChinese:
            return "固定翻译成中文"
        case .english:
            return "固定翻译成英文"
        }
    }
}

@MainActor
final class SettingsStore: ObservableObject {
    static let minMenuBarPanelHeight: Double = 300
    static let maxMenuBarPanelHeight: Double = 560

    enum Appearance: String, CaseIterable, Identifiable {
        case system, light, dark
        var id: String { rawValue }
        var title: String {
            switch self {
            case .system: return "跟随系统"
            case .light: return "浅色模式"
            case .dark: return "深色模式"
            }
        }
    }

    @Published var downloadedLanguages: Set<String> {
        didSet { defaults.set(Array(downloadedLanguages), forKey: Keys.downloadedLanguages) }
    }

    @Published var appearance: Appearance {
        didSet { defaults.set(appearance.rawValue, forKey: Keys.appearance) }
    }

    @Published var appLanguage: String {
        didSet { defaults.set(appLanguage, forKey: Keys.appLanguage) }
    }

    @Published var launchAtLogin: Bool {
        didSet { defaults.set(launchAtLogin, forKey: Keys.launchAtLogin) }
    }

    @Published var historyLimit: Int {
        didSet { defaults.set(historyLimit, forKey: Keys.historyLimit) }
    }

    @Published var sourceLanguage: String {
        didSet { defaults.set(sourceLanguage, forKey: Keys.sourceLanguage) }
    }

    @Published var targetLanguage: String {
        didSet { defaults.set(targetLanguage, forKey: Keys.targetLanguage) }
    }

    @Published var preferredTargetLanguage: PreferredTargetLanguage {
        didSet {
            defaults.set(preferredTargetLanguage.rawValue, forKey: Keys.preferredTargetLanguage)
        }
    }

    @Published var shortcutKeyCode: UInt32 {
        didSet {
            defaults.set(Int(shortcutKeyCode), forKey: Keys.shortcutKeyCode)
        }
    }

    @Published var shortcutModifiers: UInt32 {
        didSet {
            defaults.set(Int(shortcutModifiers), forKey: Keys.shortcutModifiers)
        }
    }

    @Published var menuBarPanelHeight: Double {
        didSet {
            let clampedValue = Self.clampMenuBarPanelHeight(menuBarPanelHeight)
            if menuBarPanelHeight != clampedValue {
                menuBarPanelHeight = clampedValue
                return
            }

            defaults.set(clampedValue, forKey: Keys.menuBarPanelHeight)
        }
    }

    var shortcutDisplayString: String {
        ShortcutFormatter.string(forKeyCode: shortcutKeyCode, modifiers: shortcutModifiers)
    }

    private let defaults: UserDefaults

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        let defaultShortcutModifiers = Int(UInt32(shiftKey) | UInt32(optionKey))

        self.downloadedLanguages = Set(defaults.stringArray(forKey: Keys.downloadedLanguages) ?? ["zh-Hans", "en"])
        
        self.appearance = Appearance(rawValue: defaults.string(forKey: Keys.appearance) ?? "") ?? .system
        self.appLanguage = defaults.string(forKey: Keys.appLanguage) ?? "zh-Hans"
        self.launchAtLogin = defaults.bool(forKey: Keys.launchAtLogin)
        self.historyLimit = defaults.integer(forKey: Keys.historyLimit) == 0 ? 100 : defaults.integer(forKey: Keys.historyLimit)
        
        self.sourceLanguage = defaults.string(forKey: Keys.sourceLanguage) ?? "auto"
        self.targetLanguage = defaults.string(forKey: Keys.targetLanguage) ?? "auto"

        let preferredTargetRawValue = defaults.string(forKey: Keys.preferredTargetLanguage)
        self.preferredTargetLanguage = PreferredTargetLanguage(rawValue: preferredTargetRawValue ?? "") ?? .automatic

        let storedKeyCode = defaults.object(forKey: Keys.shortcutKeyCode) as? Int
        self.shortcutKeyCode = UInt32(storedKeyCode ?? kVK_ANSI_T)

        let storedModifiers = defaults.object(forKey: Keys.shortcutModifiers) as? Int
        self.shortcutModifiers = UInt32(storedModifiers ?? defaultShortcutModifiers)

        let storedMenuBarPanelHeight = defaults.object(forKey: Keys.menuBarPanelHeight) as? Double
        self.menuBarPanelHeight = Self.clampMenuBarPanelHeight(
            storedMenuBarPanelHeight ?? Self.minMenuBarPanelHeight
        )
    }

    func toggleLanguageDownload(_ lang: String) {
        if downloadedLanguages.contains(lang) {
            downloadedLanguages.remove(lang)
        } else {
            downloadedLanguages.insert(lang)
        }
    }

    func updateShortcut(keyCode: UInt32, modifiers: UInt32) {
        shortcutKeyCode = keyCode
        shortcutModifiers = modifiers
    }

    func clearAllHistory() {
        // Placeholder for clearing history
        print("Clearing all history...")
    }

    private static func clampMenuBarPanelHeight(_ value: Double) -> Double {
        min(max(value, minMenuBarPanelHeight), maxMenuBarPanelHeight)
    }
}

private enum Keys {
    static let downloadedLanguages = "settings.downloadedLanguages"
    static let appearance = "settings.appearance"
    static let appLanguage = "settings.appLanguage"
    static let launchAtLogin = "settings.launchAtLogin"
    static let historyLimit = "settings.historyLimit"
    static let sourceLanguage = "settings.sourceLanguage"
    static let targetLanguage = "settings.targetLanguage"
    static let preferredTargetLanguage = "settings.preferredTargetLanguage"
    static let shortcutKeyCode = "settings.shortcutKeyCode"
    static let shortcutModifiers = "settings.shortcutModifiers"
    static let menuBarPanelHeight = "settings.menuBarPanelHeight"
}
