//
//  MenuBarController.swift
//  Transnap
//
//  Created by Codex on 2026/4/14.
//

import AppKit
import Combine
import SwiftData
import SwiftUI

@available(macOS 15.0, *)
@MainActor
final class MenuBarController: NSObject {
    private let viewModel: TransnapViewModel
    private let settingsStore: SettingsStore
    private let windowCoordinator: WindowCoordinator
    private let modelContainer: ModelContainer
    private let statusItem: NSStatusItem
    private let popover = NSPopover()
    private var cancellables: Set<AnyCancellable> = []

    init(
        viewModel: TransnapViewModel,
        settingsStore: SettingsStore,
        windowCoordinator: WindowCoordinator,
        modelContainer: ModelContainer
    ) {
        self.viewModel = viewModel
        self.settingsStore = settingsStore
        self.windowCoordinator = windowCoordinator
        self.modelContainer = modelContainer
        self.statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        super.init()

        configureStatusItem()
        configurePopover()
        bindState()
    }

    func togglePopover() {
        if popover.isShown {
            popover.performClose(nil)
        } else {
            showPopover()
        }
    }

    func showPopover() {
        guard let button = statusItem.button else { return }

        updatePopoverContentSize()
        viewModel.handleMenuOpened()
        NSApp.activate(ignoringOtherApps: true)
        popover.show(relativeTo: button.bounds, of: button, preferredEdge: .maxY)
    }

    private func configureStatusItem() {
        guard let button = statusItem.button else { return }

        button.image = NSImage(
            systemSymbolName: "character.bubble",
            accessibilityDescription: "Transnap"
        )
        button.imagePosition = .imageLeading
        button.target = self
        button.action = #selector(togglePopoverFromStatusItem)
        button.sendAction(on: [.leftMouseUp])
        updateStatusItemTitle()
    }

    private func configurePopover() {
        popover.behavior = .transient
        popover.animates = true
        popover.contentViewController = NSHostingController(
            rootView: MenuBarRootView(
                viewModel: viewModel,
                settingsStore: settingsStore,
                windowCoordinator: windowCoordinator
            )
            .modelContainer(modelContainer)
        )
        updatePopoverContentSize()
    }

    private func bindState() {
        viewModel.$menuBarSubtitle
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                self?.updateStatusItemTitle()
            }
            .store(in: &cancellables)

        settingsStore.$menuBarPanelHeight
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                self?.updatePopoverContentSize()
            }
            .store(in: &cancellables)
    }

    private func updateStatusItemTitle() {
        guard let button = statusItem.button else { return }
        button.title = ""
    }

    private func updatePopoverContentSize() {
        popover.contentSize = NSSize(width: 360, height: settingsStore.menuBarPanelHeight)
    }

    @objc
    private func togglePopoverFromStatusItem() {
        togglePopover()
    }
}
