//
//  DoubleCopyMonitor.swift
//  Transnap
//
//  Created by Codex on 2026/4/10.
//

import AppKit
import ApplicationServices

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
        requestAccessibilityPermissionIfNeeded()

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

    private func requestAccessibilityPermissionIfNeeded() {
        let options = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true] as CFDictionary
        _ = AXIsProcessTrustedWithOptions(options)
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
}
