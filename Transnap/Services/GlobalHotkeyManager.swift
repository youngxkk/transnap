//
//  GlobalHotkeyManager.swift
//  Transnap
//
//  Created by Codex on 2026/4/11.
//

import Carbon
import Combine
import Foundation

@MainActor
final class GlobalHotkeyManager {
    var onTrigger: (() -> Void)?

    private var hotKeyRef: EventHotKeyRef?
    private var eventHandlerRef: EventHandlerRef?
    private var cancellables: Set<AnyCancellable> = []
    private let settingsStore: SettingsStore

    init(settingsStore: SettingsStore) {
        self.settingsStore = settingsStore
        installEventHandler()
        bindSettings()
        registerCurrentShortcut()
    }

    private func bindSettings() {
        settingsStore.$shortcutKeyCode
            .combineLatest(settingsStore.$shortcutModifiers)
            .sink { [weak self] _, _ in
                self?.registerCurrentShortcut()
            }
            .store(in: &cancellables)
    }

    private func installEventHandler() {
        guard eventHandlerRef == nil else { return }

        var eventType = EventTypeSpec(eventClass: OSType(kEventClassKeyboard), eventKind: UInt32(kEventHotKeyPressed))
        let handler: EventHandlerUPP = { _, event, userData in
            guard let userData else { return noErr }
            let manager = Unmanaged<GlobalHotkeyManager>.fromOpaque(userData).takeUnretainedValue()

            var hotKeyID = EventHotKeyID()
            GetEventParameter(
                event,
                EventParamName(kEventParamDirectObject),
                EventParamType(typeEventHotKeyID),
                nil,
                MemoryLayout<EventHotKeyID>.size,
                nil,
                &hotKeyID
            )

            if hotKeyID.id == 1 {
                DispatchQueue.main.async {
                    manager.onTrigger?()
                }
            }

            return noErr
        }

        InstallEventHandler(
            GetApplicationEventTarget(),
            handler,
            1,
            &eventType,
            UnsafeMutableRawPointer(Unmanaged.passUnretained(self).toOpaque()),
            &eventHandlerRef
        )
    }

    private func registerCurrentShortcut() {
        unregisterHotkey()

        let hotKeyID = EventHotKeyID(signature: OSType(0x54534E50), id: 1)
        RegisterEventHotKey(
            UInt32(settingsStore.shortcutKeyCode),
            settingsStore.shortcutModifiers,
            hotKeyID,
            GetApplicationEventTarget(),
            0,
            &hotKeyRef
        )
    }

    private func unregisterHotkey() {
        if let hotKeyRef {
            UnregisterEventHotKey(hotKeyRef)
            self.hotKeyRef = nil
        }
    }
}
