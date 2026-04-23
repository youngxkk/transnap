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
