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
    static let defaultMenuBarPanelHeight: Double = 440
    static let minMenuBarPanelHeight: Double = 400
    static let maxMenuBarPanelHeight: Double = 640

    enum LaunchAtLoginState: Equatable {
        case enabled
        case disabled
        case requiresApproval
        case unavailable(String)

        var message: String {
            switch self {
            case .enabled:
                return "已开启，系统登录后会自动启动。"
            case .disabled:
                return "已关闭，需要时可手动启动。"
            case .requiresApproval:
                return "系统需要你在“登录项”里批准一次。"
            case let .unavailable(message):
                return message
            }
        }
    }

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

    @Published var doubleCopyTranslationEnabled: Bool {
        didSet {
            defaults.set(doubleCopyTranslationEnabled, forKey: Keys.doubleCopyTranslationEnabled)
        }
    }

    @Published var hasCompletedWelcomeFlow: Bool {
        didSet {
            defaults.set(hasCompletedWelcomeFlow, forKey: Keys.hasCompletedWelcomeFlow)
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

    @Published private(set) var launchAtLoginState: LaunchAtLoginState = .disabled

    var shortcutDisplayString: String {
        ShortcutFormatter.string(forKeyCode: shortcutKeyCode, modifiers: shortcutModifiers)
    }

    private let defaults: UserDefaults

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        let defaultShortcutModifiers = Int(UInt32(shiftKey) | UInt32(optionKey))

        self.downloadedLanguages = Set(defaults.stringArray(forKey: Keys.downloadedLanguages) ?? ["zh-Hans", "en"])

        self.appearance = Appearance(rawValue: defaults.string(forKey: Keys.appearance) ?? "") ?? .system
        self.launchAtLogin = defaults.bool(forKey: Keys.launchAtLogin)
        self.historyLimit = defaults.integer(forKey: Keys.historyLimit) == 0 ? 50 : defaults.integer(forKey: Keys.historyLimit)

        self.sourceLanguage = defaults.string(forKey: Keys.sourceLanguage) ?? "auto"
        self.targetLanguage = defaults.string(forKey: Keys.targetLanguage) ?? "auto"

        let preferredTargetRawValue = defaults.string(forKey: Keys.preferredTargetLanguage)
        self.preferredTargetLanguage = PreferredTargetLanguage(rawValue: preferredTargetRawValue ?? "") ?? .automatic

        let storedKeyCode = defaults.object(forKey: Keys.shortcutKeyCode) as? Int
        self.shortcutKeyCode = UInt32(storedKeyCode ?? kVK_ANSI_T)

        let storedModifiers = defaults.object(forKey: Keys.shortcutModifiers) as? Int
        self.shortcutModifiers = UInt32(storedModifiers ?? defaultShortcutModifiers)

        self.doubleCopyTranslationEnabled = defaults.bool(forKey: Keys.doubleCopyTranslationEnabled)
        self.hasCompletedWelcomeFlow = defaults.bool(forKey: Keys.hasCompletedWelcomeFlow)

        let storedMenuBarPanelHeight = defaults.object(forKey: Keys.menuBarPanelHeight) as? Double
        self.menuBarPanelHeight = Self.clampMenuBarPanelHeight(
            storedMenuBarPanelHeight ?? Self.defaultMenuBarPanelHeight
        )
    }

    func updateShortcut(keyCode: UInt32, modifiers: UInt32) {
        shortcutKeyCode = keyCode
        shortcutModifiers = modifiers
    }

    func updateLaunchAtLoginState(_ state: LaunchAtLoginState) {
        launchAtLoginState = state
    }

    private static func clampMenuBarPanelHeight(_ value: Double) -> Double {
        min(max(value, minMenuBarPanelHeight), maxMenuBarPanelHeight)
    }
}

private enum Keys {
    static let downloadedLanguages = "settings.downloadedLanguages"
    static let appearance = "settings.appearance"
    static let launchAtLogin = "settings.launchAtLogin"
    static let historyLimit = "settings.historyLimit"
    static let sourceLanguage = "settings.sourceLanguage"
    static let targetLanguage = "settings.targetLanguage"
    static let preferredTargetLanguage = "settings.preferredTargetLanguage"
    static let shortcutKeyCode = "settings.shortcutKeyCode"
    static let shortcutModifiers = "settings.shortcutModifiers"
    static let doubleCopyTranslationEnabled = "settings.doubleCopyTranslationEnabled"
    static let hasCompletedWelcomeFlow = "settings.hasCompletedWelcomeFlow"
    static let menuBarPanelHeight = "settings.menuBarPanelHeight"
}
