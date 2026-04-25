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

struct TranslationLanguageOption: Identifiable, Hashable {
    let identifier: String
    let title: String

    var id: String { identifier }
}

enum TranslationLanguageOptions {
    static let automaticIdentifier = "auto"
    static let defaultPrimaryAutoDetectionLanguage = "zh-Hans"
    static let defaultSecondaryAutoDetectionLanguage = "en"

    static let all: [TranslationLanguageOption] = [
        TranslationLanguageOption(identifier: automaticIdentifier, title: "自动检测"),
        TranslationLanguageOption(identifier: "zh-Hans", title: "简体中文"),
        TranslationLanguageOption(identifier: "en", title: "英语"),
        TranslationLanguageOption(identifier: "ja", title: "日语"),
        TranslationLanguageOption(identifier: "ko", title: "韩语"),
        TranslationLanguageOption(identifier: "fr", title: "法语"),
        TranslationLanguageOption(identifier: "de", title: "德语"),
    ]

    static let autoDetectionCandidates: [TranslationLanguageOption] = all.filter {
        $0.identifier != automaticIdentifier
    }

    static func title(for identifier: String) -> String {
        all.first(where: { $0.identifier == identifier })?.title ?? identifier
    }

    static func normalizedAutoDetectionLanguage(_ identifier: String?, fallback: String) -> String {
        guard let identifier,
              autoDetectionCandidates.contains(where: { $0.identifier == identifier }) else {
            return fallback
        }

        return identifier
    }

    static func fallbackAutoDetectionLanguage(excluding identifier: String) -> String {
        autoDetectionCandidates.first(where: { $0.identifier != identifier })?.identifier
            ?? defaultSecondaryAutoDetectionLanguage
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
                return "已开启，登录 Mac 后会自动打开。"
            case .disabled:
                return "已关闭，你可以随时手动打开。"
            case .requiresApproval:
                return "还需要你去系统“登录项”里确认一次。"
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

    @Published var primaryAutoDetectionLanguage: String {
        didSet {
            let normalizedValue = TranslationLanguageOptions.normalizedAutoDetectionLanguage(
                primaryAutoDetectionLanguage,
                fallback: TranslationLanguageOptions.defaultPrimaryAutoDetectionLanguage
            )
            if primaryAutoDetectionLanguage != normalizedValue {
                primaryAutoDetectionLanguage = normalizedValue
                return
            }

            if primaryAutoDetectionLanguage == secondaryAutoDetectionLanguage {
                secondaryAutoDetectionLanguage = TranslationLanguageOptions.fallbackAutoDetectionLanguage(
                    excluding: primaryAutoDetectionLanguage
                )
            }

            defaults.set(primaryAutoDetectionLanguage, forKey: Keys.primaryAutoDetectionLanguage)
        }
    }

    @Published var secondaryAutoDetectionLanguage: String {
        didSet {
            let normalizedValue = TranslationLanguageOptions.normalizedAutoDetectionLanguage(
                secondaryAutoDetectionLanguage,
                fallback: TranslationLanguageOptions.defaultSecondaryAutoDetectionLanguage
            )
            if secondaryAutoDetectionLanguage != normalizedValue {
                secondaryAutoDetectionLanguage = normalizedValue
                return
            }

            if secondaryAutoDetectionLanguage == primaryAutoDetectionLanguage {
                primaryAutoDetectionLanguage = TranslationLanguageOptions.fallbackAutoDetectionLanguage(
                    excluding: secondaryAutoDetectionLanguage
                )
            }

            defaults.set(secondaryAutoDetectionLanguage, forKey: Keys.secondaryAutoDetectionLanguage)
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

    @Published var hasCompletedWelcomeFlow: Bool {
        didSet {
            defaults.set(hasCompletedWelcomeFlow, forKey: Keys.hasCompletedWelcomeFlow)
            if hasCompletedWelcomeFlow {
                defaults.set(currentBuildNumber, forKey: Keys.lastCompletedWelcomeBuild)
            } else {
                defaults.removeObject(forKey: Keys.lastCompletedWelcomeBuild)
            }
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

    var autoDetectionLanguageIdentifiers: [String] {
        [primaryAutoDetectionLanguage, secondaryAutoDetectionLanguage]
    }

    private let defaults: UserDefaults
    private let currentBuildNumber: String

    init(defaults: UserDefaults = .standard, appBuild: String? = nil) {
        self.defaults = defaults
        self.currentBuildNumber = appBuild ?? Self.resolveCurrentBuildNumber()
        let defaultShortcutKeyCode = Int(kVK_ANSI_T)
        let oldDefaultShortcutModifiers = Int(UInt32(shiftKey) | UInt32(optionKey))
        let defaultShortcutModifiers = Int(UInt32(shiftKey) | UInt32(controlKey))

        self.downloadedLanguages = Set(defaults.stringArray(forKey: Keys.downloadedLanguages) ?? ["zh-Hans", "en"])

        self.appearance = Appearance(rawValue: defaults.string(forKey: Keys.appearance) ?? "") ?? .system
        self.launchAtLogin = defaults.bool(forKey: Keys.launchAtLogin)
        self.historyLimit = defaults.integer(forKey: Keys.historyLimit) == 0 ? 50 : defaults.integer(forKey: Keys.historyLimit)

        self.sourceLanguage = defaults.string(forKey: Keys.sourceLanguage) ?? "auto"
        self.targetLanguage = defaults.string(forKey: Keys.targetLanguage) ?? "auto"

        let preferredTargetRawValue = defaults.string(forKey: Keys.preferredTargetLanguage)
        self.preferredTargetLanguage = PreferredTargetLanguage(rawValue: preferredTargetRawValue ?? "") ?? .automatic

        let storedPrimaryAutoDetectionLanguage = TranslationLanguageOptions.normalizedAutoDetectionLanguage(
            defaults.string(forKey: Keys.primaryAutoDetectionLanguage),
            fallback: TranslationLanguageOptions.defaultPrimaryAutoDetectionLanguage
        )
        var storedSecondaryAutoDetectionLanguage = TranslationLanguageOptions.normalizedAutoDetectionLanguage(
            defaults.string(forKey: Keys.secondaryAutoDetectionLanguage),
            fallback: TranslationLanguageOptions.defaultSecondaryAutoDetectionLanguage
        )
        if storedPrimaryAutoDetectionLanguage == storedSecondaryAutoDetectionLanguage {
            storedSecondaryAutoDetectionLanguage = TranslationLanguageOptions.fallbackAutoDetectionLanguage(
                excluding: storedPrimaryAutoDetectionLanguage
            )
        }
        self.primaryAutoDetectionLanguage = storedPrimaryAutoDetectionLanguage
        self.secondaryAutoDetectionLanguage = storedSecondaryAutoDetectionLanguage

        let storedKeyCode = defaults.object(forKey: Keys.shortcutKeyCode) as? Int
        let storedModifiers = defaults.object(forKey: Keys.shortcutModifiers) as? Int
        let shouldMigrateOldDefaultShortcut =
            storedKeyCode == defaultShortcutKeyCode &&
            storedModifiers == oldDefaultShortcutModifiers
        let resolvedShortcutKeyCode = shouldMigrateOldDefaultShortcut
            ? defaultShortcutKeyCode
            : (storedKeyCode ?? defaultShortcutKeyCode)
        let resolvedShortcutModifiers = shouldMigrateOldDefaultShortcut
            ? defaultShortcutModifiers
            : (storedModifiers ?? defaultShortcutModifiers)
        self.shortcutKeyCode = UInt32(resolvedShortcutKeyCode)
        self.shortcutModifiers = UInt32(resolvedShortcutModifiers)

        if shouldMigrateOldDefaultShortcut {
            defaults.set(resolvedShortcutKeyCode, forKey: Keys.shortcutKeyCode)
            defaults.set(resolvedShortcutModifiers, forKey: Keys.shortcutModifiers)
        }

        let hasCompletedWelcomeFlow = defaults.bool(forKey: Keys.hasCompletedWelcomeFlow)
        let lastCompletedWelcomeBuild = defaults.string(forKey: Keys.lastCompletedWelcomeBuild)
        let shouldMigrateWelcomeBuild = hasCompletedWelcomeFlow && lastCompletedWelcomeBuild == nil
        let shouldShowWelcomeForCurrentBuild: Bool

        if shouldMigrateWelcomeBuild {
            defaults.set(currentBuildNumber, forKey: Keys.lastCompletedWelcomeBuild)
            shouldShowWelcomeForCurrentBuild = false
        } else {
            shouldShowWelcomeForCurrentBuild =
                hasCompletedWelcomeFlow == false || lastCompletedWelcomeBuild != currentBuildNumber
        }

        self.hasCompletedWelcomeFlow = !shouldShowWelcomeForCurrentBuild

        if shouldShowWelcomeForCurrentBuild {
            defaults.set(false, forKey: Keys.hasCompletedWelcomeFlow)
        }

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

    private static func resolveCurrentBuildNumber(bundle: Bundle = .main) -> String {
        bundle.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? "1"
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
    static let primaryAutoDetectionLanguage = "settings.primaryAutoDetectionLanguage"
    static let secondaryAutoDetectionLanguage = "settings.secondaryAutoDetectionLanguage"
    static let shortcutKeyCode = "settings.shortcutKeyCode"
    static let shortcutModifiers = "settings.shortcutModifiers"
    static let hasCompletedWelcomeFlow = "settings.hasCompletedWelcomeFlow"
    static let lastCompletedWelcomeBuild = "settings.lastCompletedWelcomeBuild"
    static let menuBarPanelHeight = "settings.menuBarPanelHeight"
}
