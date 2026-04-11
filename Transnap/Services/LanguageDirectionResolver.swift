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

    static func resolve(for text: String, sourceLanguage: String, targetLanguage: String, preferredTargetLanguage: PreferredTargetLanguage) -> TranslationDirection? {
        let recognizer = NLLanguageRecognizer()
        recognizer.processString(text)

        let detected = recognizer.dominantLanguage
        let detectedIdentifier = detected?.rawValue ?? "und"
        let systemIdentifier = Locale.preferredLanguages.first ?? Locale.current.language.languageCode?.identifier ?? englishCode

        let finalSourceIdentifier: String
        if sourceLanguage == "auto" {
            finalSourceIdentifier = detectedIdentifier
        } else {
            finalSourceIdentifier = sourceLanguage
        }

        let finalTargetIdentifier: String
        if targetLanguage == "auto" {
            // Apply existing automatic logic if target is auto
            switch preferredTargetLanguage {
            case .simplifiedChinese:
                finalTargetIdentifier = "zh-Hans"
            case .english:
                finalTargetIdentifier = englishCode
            case .automatic:
                if isChinese(systemIdentifier) {
                    finalTargetIdentifier = isChinese(finalSourceIdentifier) ? englishCode : "zh-Hans"
                } else {
                    finalTargetIdentifier = isEnglish(finalSourceIdentifier) ? "zh-Hans" : englishCode
                }
            }
        } else {
            finalTargetIdentifier = targetLanguage
        }

        return TranslationDirection(
            source: finalSourceIdentifier == "und" ? nil : Locale.Language(identifier: finalSourceIdentifier),
            target: Locale.Language(identifier: finalTargetIdentifier),
            detectedSourceIdentifier: finalSourceIdentifier,
            targetIdentifier: finalTargetIdentifier
        )
    }

    static func displayName(for identifier: String) -> String {
        Locale.current.localizedString(forIdentifier: identifier) ?? identifier
    }

    private static func fallbackDirection(sourceLanguage: String, targetLanguage: String, preferredTargetLanguage: PreferredTargetLanguage) -> TranslationDirection {
        let systemIdentifier = Locale.preferredLanguages.first ?? englishCode
        
        let finalSourceIdentifier = sourceLanguage == "auto" ? "und" : sourceLanguage
        let finalTargetIdentifier: String
        
        if targetLanguage == "auto" {
            switch preferredTargetLanguage {
            case .simplifiedChinese:
                finalTargetIdentifier = "zh-Hans"
            case .english:
                finalTargetIdentifier = englishCode
            case .automatic:
                finalTargetIdentifier = isChinese(systemIdentifier) ? englishCode : "zh-Hans"
            }
        } else {
            finalTargetIdentifier = targetLanguage
        }

        return TranslationDirection(
            source: finalSourceIdentifier == "und" ? nil : Locale.Language(identifier: finalSourceIdentifier),
            target: Locale.Language(identifier: finalTargetIdentifier),
            detectedSourceIdentifier: finalSourceIdentifier,
            targetIdentifier: finalTargetIdentifier
        )
    }

    private static func isChinese(_ identifier: String) -> Bool {
        chineseCodes.contains { identifier.hasPrefix($0) }
    }

    private static func isEnglish(_ identifier: String) -> Bool {
        identifier.hasPrefix(englishCode)
    }
}
