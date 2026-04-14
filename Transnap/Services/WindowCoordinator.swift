//
//  WindowCoordinator.swift
//  Transnap
//
//  Created by Codex on 2026/4/11.
//

import AppKit
import SwiftData
import SwiftUI

@available(macOS 15.0, *)
@MainActor
final class WindowCoordinator {
    private let viewModel: TransnapViewModel
    private let settingsStore: SettingsStore
    private let modelContainer: ModelContainer

    private var translatorWindowController: NSWindowController?
    private var historyWindowController: NSWindowController?
    private var settingsWindowController: NSWindowController?

    init(
        viewModel: TransnapViewModel,
        settingsStore: SettingsStore,
        modelContainer: ModelContainer
    ) {
        self.viewModel = viewModel
        self.settingsStore = settingsStore
        self.modelContainer = modelContainer
    }

    func showTranslatorWindow() {
        if translatorWindowController == nil {
            let content = TranslatorWindowView(viewModel: viewModel, settingsStore: settingsStore, windowCoordinator: self)
                .modelContainer(modelContainer)
            translatorWindowController = makeWindowController(
                title: "Transnap",
                size: NSSize(width: 380, height: 360),
                content: content
            )
        }

        viewModel.handleMenuOpened()
        show(windowController: translatorWindowController)
    }

    func showHistoryWindow() {
        if historyWindowController == nil {
            let content = HistoryWindowView()
                .modelContainer(modelContainer)
            historyWindowController = makeWindowController(
                title: "翻译历史",
                size: NSSize(width: 440, height: 520),
                content: content
            )
        }

        show(windowController: historyWindowController)
    }

    func showSettingsWindow() {
        if settingsWindowController == nil {
            let content = SettingsView(settingsStore: settingsStore)
                .modelContainer(modelContainer)
            settingsWindowController = makeWindowController(
                title: "设置",
                size: NSSize(width: 420, height: 320),
                content: content
            )
        }

        show(windowController: settingsWindowController)
    }

    private func show(windowController: NSWindowController?) {
        NSApp.activate(ignoringOtherApps: true)
        windowController?.showWindow(nil)
        windowController?.window?.makeKeyAndOrderFront(nil)
    }

    private func makeWindowController<Content: View>(
        title: String,
        size: NSSize,
        content: Content
    ) -> NSWindowController {
        let hostingController = NSHostingController(rootView: content)
        let window = NSWindow(contentViewController: hostingController)
        window.title = title
        window.setContentSize(size)
        window.styleMask = [.titled, .closable, .miniaturizable, .fullSizeContentView]
        window.isReleasedWhenClosed = false
        window.center()
        window.titlebarAppearsTransparent = true
        window.toolbarStyle = .unifiedCompact
        return NSWindowController(window: window)
    }
}
