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
    private let hotkeyManager: GlobalHotkeyManager?
    private let menuBarController: MenuBarController?
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
            hotkeyManager = nil
            menuBarController = nil
        } else {
            appSettingsController = AppSettingsController(settingsStore: settingsStore)

            let menuBarController = MenuBarController(
                viewModel: rootViewModel,
                settingsStore: settingsStore,
                windowCoordinator: coordinator,
                modelContainer: container
            )
            self.menuBarController = menuBarController

            let hotkeyManager = GlobalHotkeyManager(settingsStore: settingsStore)
            hotkeyManager.onTrigger = {
                menuBarController.togglePopover()
            }
            hotkeyManager.onDoubleCopyTrigger = {
                menuBarController.showPopoverForShortcut()
            }
            self.hotkeyManager = hotkeyManager
        }
    }

    @SceneBuilder
    var body: some Scene {
        Settings { EmptyView() }
            .commands {
                CommandGroup(replacing: .appSettings) {
                    Button(settingsStore.text("设置...", "Settings...")) {
                        windowCoordinator.showSettingsWindow()
                    }
                    .keyboardShortcut(",", modifiers: [.command])
                }
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
