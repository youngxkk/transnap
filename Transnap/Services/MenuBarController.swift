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
    private var welcomePresentationAttempts = 0

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

    func showPopoverForShortcut() {
        if popover.isShown {
            if settingsStore.hasCompletedWelcomeFlow {
                viewModel.handleMenuOpened()
            }
            NSApp.activate(ignoringOtherApps: true)
        } else {
            showPopover()
        }
    }

    func showPopover() {
        guard let button = statusPopoverAnchorButton() else { return }

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

        welcomePresentationAttempts = 0
        scheduleWelcomePresentationAttempt(after: 0.8)
    }

    private func scheduleWelcomePresentationAttempt(after delay: TimeInterval) {
        DispatchQueue.main.asyncAfter(deadline: .now() + delay) { [weak self] in
            self?.presentWelcomeWhenStatusItemIsReady()
        }
    }

    private func presentWelcomeWhenStatusItemIsReady() {
        guard popover.isShown == false else { return }
        guard settingsStore.hasCompletedWelcomeFlow == false else { return }

        welcomePresentationAttempts += 1

        guard statusPopoverAnchorButton() != nil else {
            guard welcomePresentationAttempts < 24 else { return }
            scheduleWelcomePresentationAttempt(after: 0.2)
            return
        }

        showPopover()
    }

    private func updateStatusItemTitle() {
        guard let button = statusItem.button else { return }
        button.title = ""
    }

    private func updatePopoverContentSize() {
        popover.contentSize = NSSize(width: 360, height: settingsStore.menuBarPanelHeight)
    }

    private func statusPopoverAnchorButton() -> NSStatusBarButton? {
        guard let button = statusItem.button else { return nil }
        guard let window = button.window else { return nil }
        guard window.screen != nil else { return nil }

        button.layoutSubtreeIfNeeded()
        guard button.bounds.width > 0, button.bounds.height > 0 else { return nil }
        guard window.frame.width > 0, window.frame.height > 0 else { return nil }

        return button
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
