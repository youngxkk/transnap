//
//  DoubleCopyMonitor.swift
//  Transnap
//
//  Created by Codex on 2026/4/10.
//

import AppKit
import ApplicationServices
import Combine

final class DoubleCopyMonitor {
    private let threshold: TimeInterval
    private let handler: @MainActor () -> Void

    private var eventTap: CFMachPort?
    private var runLoopSource: CFRunLoopSource?
    private var lastCopyDate: Date?

    init(
        threshold: TimeInterval = 0.5,
        handler: @escaping @MainActor () -> Void
    ) {
        self.threshold = threshold
        self.handler = handler
    }

    func start() {
        guard eventTap == nil else { return }
        guard Self.isAccessibilityTrusted() else { return }

        let callback: CGEventTapCallBack = { proxy, type, event, userInfo in
            guard let userInfo else {
                return Unmanaged.passUnretained(event)
            }

            let monitor = Unmanaged<DoubleCopyMonitor>.fromOpaque(userInfo).takeUnretainedValue()
            return monitor.handle(proxy: proxy, type: type, event: event)
        }

        let mask = 1 << CGEventType.keyDown.rawValue
        let userInfo = UnsafeMutableRawPointer(Unmanaged.passUnretained(self).toOpaque())

        guard let tap = CGEvent.tapCreate(
            tap: .cgSessionEventTap,
            place: .headInsertEventTap,
            options: .defaultTap,
            eventsOfInterest: CGEventMask(mask),
            callback: callback,
            userInfo: userInfo
        ) else {
            return
        }

        let source = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, tap, 0)
        CFRunLoopAddSource(CFRunLoopGetMain(), source, .commonModes)
        CGEvent.tapEnable(tap: tap, enable: true)

        eventTap = tap
        runLoopSource = source
    }

    func stop() {
        guard let eventTap else { return }

        CGEvent.tapEnable(tap: eventTap, enable: false)

        if let runLoopSource {
            CFRunLoopRemoveSource(CFRunLoopGetMain(), runLoopSource, .commonModes)
        }

        self.runLoopSource = nil
        self.eventTap = nil
        self.lastCopyDate = nil
    }

    deinit {
        stop()
    }

    private func handle(
        proxy: CGEventTapProxy,
        type: CGEventType,
        event: CGEvent
    ) -> Unmanaged<CGEvent>? {
        if type == .tapDisabledByTimeout || type == .tapDisabledByUserInput {
            if let eventTap {
                CGEvent.tapEnable(tap: eventTap, enable: true)
            }
            return Unmanaged.passUnretained(event)
        }

        guard type == .keyDown else {
            return Unmanaged.passUnretained(event)
        }

        let flags = event.flags
        let isCommandDown = flags.contains(.maskCommand)
        let keyCode = event.getIntegerValueField(.keyboardEventKeycode)
        let isCKey = keyCode == 8

        guard isCommandDown, isCKey else {
            return Unmanaged.passUnretained(event)
        }

        let now = Date()
        if let lastCopyDate, now.timeIntervalSince(lastCopyDate) <= threshold {
            self.lastCopyDate = nil
            Task { @MainActor in
                handler()
            }
        } else {
            lastCopyDate = now
        }

        return Unmanaged.passUnretained(event)
    }

    static func isAccessibilityTrusted() -> Bool {
        AXIsProcessTrusted()
    }

    static func openAccessibilitySettings() {
        guard let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility") else {
            return
        }

        NSWorkspace.shared.open(url)
    }
}

@MainActor
final class DoubleCopyMonitorController {
    private let settingsStore: SettingsStore
    private let monitor: DoubleCopyMonitor
    private var cancellables: Set<AnyCancellable> = []
    private var observers: [NSObjectProtocol] = []

    init(settingsStore: SettingsStore, monitor: DoubleCopyMonitor) {
        self.settingsStore = settingsStore
        self.monitor = monitor
        bindSettings()
        observeAppLifecycle()
        refresh()
    }

    deinit {
        for observer in observers {
            NotificationCenter.default.removeObserver(observer)
        }
    }

    private func bindSettings() {
        settingsStore.$doubleCopyTranslationEnabled
            .removeDuplicates()
            .sink { [weak self] _ in
                self?.refresh()
            }
            .store(in: &cancellables)
    }

    private func observeAppLifecycle() {
        let notificationCenter = NotificationCenter.default
        observers.append(
            notificationCenter.addObserver(
                forName: NSApplication.didBecomeActiveNotification,
                object: nil,
                queue: .main
            ) { [weak self] _ in
                self?.refresh()
            }
        )
    }

    private func refresh() {
        guard settingsStore.doubleCopyTranslationEnabled else {
            monitor.stop()
            return
        }

        guard DoubleCopyMonitor.isAccessibilityTrusted() else {
            monitor.stop()
            return
        }

        monitor.start()
    }
}
