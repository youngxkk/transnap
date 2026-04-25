//
//  TransnapTests.swift
//  TransnapTests
//
//  Created by deepsea on 2026/4/10.
//

import Foundation
import SwiftData
import XCTest
@testable import Transnap

@MainActor
final class TransnapTests: XCTestCase {
    func testWelcomeFlowStaysCompletedForSameBuild() {
        let suiteName = "TransnapTests.sameBuild.\(UUID().uuidString)"
        let defaults = makeDefaultsSuite(named: suiteName)

        let firstLaunchStore = SettingsStore(defaults: defaults, appBuild: "12")
        firstLaunchStore.hasCompletedWelcomeFlow = true

        let secondLaunchStore = SettingsStore(defaults: defaults, appBuild: "12")

        XCTAssertTrue(secondLaunchStore.hasCompletedWelcomeFlow)
    }

    func testWelcomeFlowResetsWhenBuildChanges() {
        let suiteName = "TransnapTests.newBuild.\(UUID().uuidString)"
        let defaults = makeDefaultsSuite(named: suiteName)

        let firstLaunchStore = SettingsStore(defaults: defaults, appBuild: "12")
        firstLaunchStore.hasCompletedWelcomeFlow = true

        let secondLaunchStore = SettingsStore(defaults: defaults, appBuild: "13")

        XCTAssertFalse(secondLaunchStore.hasCompletedWelcomeFlow)
    }

    func testMenuBarControllerCreatesStatusItemForMenuBarMode() throws {
        let settingsStore = makeSettingsStore()
        settingsStore.hasCompletedWelcomeFlow = true

        let container = try makeInMemoryContainer()
        let viewModel = TransnapViewModel(
            modelContext: container.mainContext,
            settingsStore: settingsStore
        )
        let windowCoordinator = WindowCoordinator(
            viewModel: viewModel,
            settingsStore: settingsStore,
            modelContainer: container
        )

        let controller = MenuBarController(
            viewModel: viewModel,
            settingsStore: settingsStore,
            windowCoordinator: windowCoordinator,
            modelContainer: container,
            showsWelcomeOnLaunch: false
        )

        XCTAssertTrue(controller.debugHasStatusItemButton)
        XCTAssertFalse(controller.debugIsPopoverShown)
    }

    func testLanguageDirectionResolverDetectsSourceOnlyWhenBothLanguagesAreAutomatic() {
        let direction = LanguageDirectionResolver.resolve(
            for: "This is a simple English sentence for language detection.",
            sourceLanguage: "auto",
            targetLanguage: "auto",
            automaticLanguageIdentifiers: ["zh-Hans", "en"]
        )

        XCTAssertEqual(direction?.detectedSourceIdentifier, "en")
        XCTAssertEqual(direction?.source?.minimalIdentifier, "en")
        XCTAssertEqual(direction?.targetIdentifier, "zh-Hans")
    }

    func testLanguageDirectionResolverDetectsSourceWhenUserChoosesTargetLanguage() {
        let direction = LanguageDirectionResolver.resolve(
            for: "This is a simple English sentence for language detection.",
            sourceLanguage: "auto",
            targetLanguage: "zh-Hans",
            automaticLanguageIdentifiers: ["zh-Hans", "en"]
        )

        XCTAssertEqual(direction?.detectedSourceIdentifier, "en")
        XCTAssertEqual(direction?.source?.minimalIdentifier, "en")
        XCTAssertEqual(direction?.targetIdentifier, "zh-Hans")
    }

    func testLanguageDirectionResolverTreatsShortASCIITextAsEnglishInAutomaticMode() {
        let direction = LanguageDirectionResolver.resolve(
            for: "hello",
            sourceLanguage: "auto",
            targetLanguage: "auto",
            automaticLanguageIdentifiers: ["zh-Hans", "en"]
        )

        XCTAssertEqual(direction?.detectedSourceIdentifier, "en")
        XCTAssertEqual(direction?.source?.minimalIdentifier, "en")
        XCTAssertEqual(direction?.targetIdentifier, "zh-Hans")
    }

    func testLanguageDirectionResolverTreatsHanTextAsSimplifiedChineseInAutomaticMode() {
        let direction = LanguageDirectionResolver.resolve(
            for: "你好",
            sourceLanguage: "auto",
            targetLanguage: "auto",
            automaticLanguageIdentifiers: ["zh-Hans", "en"]
        )

        XCTAssertEqual(direction?.detectedSourceIdentifier, "zh-Hans")
        XCTAssertEqual(direction?.source?.minimalIdentifier, "zh")
        XCTAssertEqual(direction?.targetIdentifier, "en")
    }

    func testLanguageDirectionResolverDefaultsLatinSmallLanguagesToEnglishInAutomaticMode() {
        let direction = LanguageDirectionResolver.resolve(
            for: "bonjour",
            sourceLanguage: "auto",
            targetLanguage: "auto",
            automaticLanguageIdentifiers: ["zh-Hans", "en"]
        )

        XCTAssertEqual(direction?.detectedSourceIdentifier, "en")
        XCTAssertEqual(direction?.source?.minimalIdentifier, "en")
        XCTAssertEqual(direction?.targetIdentifier, "zh-Hans")
    }

    func testLanguageDirectionResolverKeepsManuallySelectedSmallLanguage() {
        let direction = LanguageDirectionResolver.resolve(
            for: "bonjour",
            sourceLanguage: "fr",
            targetLanguage: "zh-Hans",
            automaticLanguageIdentifiers: ["zh-Hans", "en"]
        )

        XCTAssertEqual(direction?.detectedSourceIdentifier, "fr")
        XCTAssertEqual(direction?.source?.minimalIdentifier, "fr")
        XCTAssertEqual(direction?.targetIdentifier, "zh-Hans")
    }

    func testLanguageDirectionResolverUsesConfiguredJapaneseEnglishPair() {
        let direction = LanguageDirectionResolver.resolve(
            for: "こんにちは",
            sourceLanguage: "auto",
            targetLanguage: "auto",
            automaticLanguageIdentifiers: ["ja", "en"]
        )

        XCTAssertEqual(direction?.detectedSourceIdentifier, "ja")
        XCTAssertEqual(direction?.source?.minimalIdentifier, "ja")
        XCTAssertEqual(direction?.targetIdentifier, "en")
    }

    func testLanguageDirectionResolverTranslatesEnglishToConfiguredPrimaryLanguage() {
        let direction = LanguageDirectionResolver.resolve(
            for: "hello",
            sourceLanguage: "auto",
            targetLanguage: "auto",
            automaticLanguageIdentifiers: ["ja", "en"]
        )

        XCTAssertEqual(direction?.detectedSourceIdentifier, "en")
        XCTAssertEqual(direction?.source?.minimalIdentifier, "en")
        XCTAssertEqual(direction?.targetIdentifier, "ja")
    }

    func testSettingsStoreKeepsAutoDetectionLanguagesDistinct() {
        let settingsStore = makeSettingsStore()

        settingsStore.primaryAutoDetectionLanguage = "ja"
        settingsStore.secondaryAutoDetectionLanguage = "ja"

        XCTAssertEqual(settingsStore.secondaryAutoDetectionLanguage, "ja")
        XCTAssertNotEqual(settingsStore.primaryAutoDetectionLanguage, settingsStore.secondaryAutoDetectionLanguage)
    }

    private func makeInMemoryContainer() throws -> ModelContainer {
        let schema = Schema([TranslationRecord.self])
        let configuration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
        return try ModelContainer(for: schema, configurations: [configuration])
    }

    private func makeSettingsStore() -> SettingsStore {
        SettingsStore(defaults: makeDefaultsSuite(named: "TransnapTests.\(UUID().uuidString)"), appBuild: "1")
    }

    private func makeDefaultsSuite(named suiteName: String) -> UserDefaults {
        let defaults = UserDefaults(suiteName: suiteName)!
        defaults.removePersistentDomain(forName: suiteName)
        addTeardownBlock {
            defaults.removePersistentDomain(forName: suiteName)
        }
        return defaults
    }
}
