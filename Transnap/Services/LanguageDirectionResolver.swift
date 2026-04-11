//
//  LanguageDirectionResolver.swift
//  Transnap
//
//  Created by Codex on 2026/4/10.
//

import Foundation
import NaturalLanguage

struct TranslationDirection {
    let source: Locale.Language?
    let target: Locale.Language
    let detectedSourceIdentifier: String
    let targetIdentifier: String
}

enum LanguageDirectionResolver {
    private static let chineseCodes = ["zh", "zh-Hans", "zh-Hant"]
    private static let englishCode = "en"

    static func resolve(for text: String, preferredTargetLanguage: PreferredTargetLanguage) -> TranslationDirection? {
        let recognizer = NLLanguageRecognizer()
        recognizer.processString(text)

        guard let detected = recognizer.dominantLanguage else {
            return fallbackDirection(preferredTargetLanguage: preferredTargetLanguage)
        }

        let detectedIdentifier = detected.rawValue
        let systemIdentifier = Locale.preferredLanguages.first ?? Locale.current.language.languageCode?.identifier ?? englishCode

        let source = Locale.Language(identifier: detectedIdentifier)
        let targetIdentifier: String

        switch preferredTargetLanguage {
        case .simplifiedChinese:
            targetIdentifier = "zh-Hans"
        case .english:
            targetIdentifier = englishCode
        case .automatic:
            if isChinese(systemIdentifier) {
                targetIdentifier = isChinese(detectedIdentifier) ? englishCode : "zh-Hans"
            } else {
                targetIdentifier = isEnglish(detectedIdentifier) ? "zh-Hans" : englishCode
            }
        }

        return TranslationDirection(
            source: source,
            target: Locale.Language(identifier: targetIdentifier),
            detectedSourceIdentifier: detectedIdentifier,
            targetIdentifier: targetIdentifier
        )
    }

    static func displayName(for identifier: String) -> String {
        Locale.current.localizedString(forIdentifier: identifier) ?? identifier
    }

    private static func fallbackDirection(preferredTargetLanguage: PreferredTargetLanguage) -> TranslationDirection {
        let systemIdentifier = Locale.preferredLanguages.first ?? englishCode
        let targetIdentifier: String

        switch preferredTargetLanguage {
        case .simplifiedChinese:
            targetIdentifier = "zh-Hans"
        case .english:
            targetIdentifier = englishCode
        case .automatic:
            targetIdentifier = isChinese(systemIdentifier) ? englishCode : "zh-Hans"
        }

        return TranslationDirection(
            source: nil,
            target: Locale.Language(identifier: targetIdentifier),
            detectedSourceIdentifier: "und",
            targetIdentifier: targetIdentifier
        )
    }

    private static func isChinese(_ identifier: String) -> Bool {
        chineseCodes.contains { identifier.hasPrefix($0) }
    }

    private static func isEnglish(_ identifier: String) -> Bool {
        identifier.hasPrefix(englishCode)
    }
}
