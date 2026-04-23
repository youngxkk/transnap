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
    private let showsWelcomeOnLaunch: Bool
    private let statusItem: NSStatusItem
    private let popover = NSPopover()
    private var cancellables: Set<AnyCancellable> = []

    init(
        viewModel: TransnapViewModel,
        settingsStore: SettingsStore,
        windowCoordinator: WindowCoordinator,
        modelContainer: ModelContainer,
        showsWelcomeOnLaunch: Bool = true
    ) {
        self.viewModel = viewModel
        self.settingsStore = settingsStore
        self.windowCoordinator = windowCoordinator
        self.modelContainer = modelContainer
        self.showsWelcomeOnLaunch = showsWelcomeOnLaunch
        self.statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        super.init()

        configureStatusItem()
        configurePopover()
        bindState()
        presentWelcomeIfNeededOnLaunch()
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
        if settingsStore.hasCompletedWelcomeFlow {
            viewModel.handleMenuOpened()
        }
        NSApp.activate(ignoringOtherApps: true)
        popover.show(relativeTo: button.bounds, of: button, preferredEdge: .maxY)
    }

    private func configureStatusItem() {
        guard let button = statusItem.button else { return }

        button.image = statusBarImage()
        button.imagePosition = .imageOnly
        button.imageScaling = .scaleProportionallyDown
        button.target = self
        button.action = #selector(togglePopoverFromStatusItem)
        button.sendAction(on: [.leftMouseUp])
        updateStatusItemTitle()
    }

    private func statusBarImage() -> NSImage? {
        if let image = NSImage(named: "StatusBarIcon") {
            image.isTemplate = true
            return image
        }

        let fallbackImage = NSImage(
            systemSymbolName: "translate",
            accessibilityDescription: "Transnap"
        )
        fallbackImage?.isTemplate = true
        return fallbackImage
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
        settingsStore.$menuBarPanelHeight
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                self?.updatePopoverContentSize()
            }
            .store(in: &cancellables)
    }

    private func presentWelcomeIfNeededOnLaunch() {
        guard showsWelcomeOnLaunch else { return }
        guard settingsStore.hasCompletedWelcomeFlow == false else { return }

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.45) { [weak self] in
            guard let self, self.popover.isShown == false else { return }
            self.showPopover()
        }
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

#if DEBUG
extension MenuBarController {
    var debugHasStatusItemButton: Bool {
        statusItem.button != nil
    }

    var debugIsPopoverShown: Bool {
        popover.isShown
    }
}
#endif
