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

    func updateShortcut(keyCode: UInt32, modifiers: UInt32) {
        shortcutKeyCode = keyCode
        shortcutModifiers = modifiers
    }

    private static func clampMenuBarPanelHeight(_ value: Double) -> Double {
        min(max(value, minMenuBarPanelHeight), maxMenuBarPanelHeight)
    }
}

private enum Keys {
    static let preferredTargetLanguage = "settings.preferredTargetLanguage"
    static let shortcutKeyCode = "settings.shortcutKeyCode"
    static let shortcutModifiers = "settings.shortcutModifiers"
    static let menuBarPanelHeight = "settings.menuBarPanelHeight"
}
