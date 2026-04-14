//
//  TransnapApp.swift
//  Transnap
//
//  Created by Codex on 2026/4/10.
//

import AppKit
import SwiftData
import SwiftUI

@available(macOS 15.0, *)
@main
struct TransnapApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate

    private let sharedModelContainer: ModelContainer
    private let settingsStore: SettingsStore
    private let appSettingsController: AppSettingsController?
    private let doubleCopyMonitor: DoubleCopyMonitor?
    private let hotkeyManager: GlobalHotkeyManager?
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

        if Self.isRunningTests {
            appSettingsController = nil
            doubleCopyMonitor = nil
            hotkeyManager = nil
        } else {
            appSettingsController = AppSettingsController(settingsStore: settingsStore)

            let monitor = DoubleCopyMonitor {
                rootViewModel.requestQuickClipboardTranslation()
            }
            monitor.start()
            doubleCopyMonitor = monitor

            let hotkeyManager = GlobalHotkeyManager(settingsStore: settingsStore)
            hotkeyManager.onTrigger = {
                coordinator.showTranslatorWindow()
            }
            self.hotkeyManager = hotkeyManager
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
                ZStack(alignment: .leading) {
                    Text("Transnap")
                        .opacity(viewModel.menuBarSubtitle.isEmpty ? 1 : max(0, 1 - viewModel.menuBarSubtitleOpacity))
                    Text(viewModel.menuBarSubtitle)
                        .opacity(viewModel.menuBarSubtitleOpacity)
                }
                .animation(.easeInOut(duration: 0.24), value: viewModel.menuBarSubtitleOpacity)
            } icon: {
                Image(systemName: "character.bubble")
            }
        }
        .menuBarExtraStyle(.window)
        .modelContainer(sharedModelContainer)

        Settings {
            SettingsView(settingsStore: settingsStore)
                .modelContainer(sharedModelContainer)
        }
    }

    private static var isRunningTests: Bool {
        ProcessInfo.processInfo.environment["XCTestConfigurationFilePath"] != nil
    }
}

final class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)
    }
}
