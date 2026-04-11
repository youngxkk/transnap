//
//  TransnapApp.swift
//  Transnap
//
//  Created by Codex on 2026/4/10.
//

import AppKit
import SwiftData
import SwiftUI

@main
struct TransnapApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate

    private let sharedModelContainer: ModelContainer
    private let settingsStore: SettingsStore
    private let doubleCopyMonitor: DoubleCopyMonitor
    private let hotkeyManager: GlobalHotkeyManager
    private let windowCoordinator: WindowCoordinator
    @StateObject private var viewModel: TransnapViewModel

    init() {
        let schema = Schema([
            TranslationRecord.self,
        ])
        let configuration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: false)
        let container: ModelContainer

        do {
            container = try ModelContainer(for: schema, configurations: [configuration])
        } catch {
            fatalError("Could not create ModelContainer: \(error)")
        }

        sharedModelContainer = container

        let settingsStore = SettingsStore()
        self.settingsStore = settingsStore

        let rootViewModel = TransnapViewModel(
            modelContext: container.mainContext,
            settingsStore: settingsStore
        )
        _viewModel = StateObject(wrappedValue: rootViewModel)

        let coordinator = WindowCoordinator(
            viewModel: rootViewModel,
            settingsStore: settingsStore,
            modelContainer: container
        )
        self.windowCoordinator = coordinator

        doubleCopyMonitor = DoubleCopyMonitor {
            rootViewModel.requestQuickClipboardTranslation()
        }
        doubleCopyMonitor.start()

        hotkeyManager = GlobalHotkeyManager(settingsStore: settingsStore)
        hotkeyManager.onTrigger = {
            coordinator.showTranslatorWindow()
        }
    }

    var body: some Scene {
        MenuBarExtra {
            MenuBarRootView(
                viewModel: viewModel,
                settingsStore: settingsStore,
                windowCoordinator: windowCoordinator
            )
            .modelContainer(sharedModelContainer)
        } label: {
            Label {
                Text(viewModel.menuBarSubtitle.isEmpty ? "Transnap" : viewModel.menuBarSubtitle)
            } icon: {
                Image(systemName: "character.bubble")
            }
        }
        .menuBarExtraStyle(.window)
        .modelContainer(sharedModelContainer)

        Settings {
            SettingsView(settingsStore: settingsStore)
        }
    }
}

final class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)
    }
}
