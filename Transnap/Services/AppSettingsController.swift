//
//  AppSettingsController.swift
//  Transnap
//
//  Created by Codex on 2026/4/13.
//

import AppKit
import Combine
import ServiceManagement

@MainActor
final class AppSettingsController {
    private let settingsStore: SettingsStore
    private var cancellables: Set<AnyCancellable> = []
    private var isSynchronizingLaunchAtLogin = false

    init(settingsStore: SettingsStore) {
        self.settingsStore = settingsStore
        bindSettings()

        DispatchQueue.main.async { [weak self] in
            self?.activate()
        }
    }

    private func bindSettings() {
        settingsStore.$appearance
            .removeDuplicates()
            .dropFirst()
            .sink { [weak self] _ in
                self?.syncAppearance()
            }
            .store(in: &cancellables)

        settingsStore.$launchAtLogin
            .removeDuplicates()
            .dropFirst()
            .sink { [weak self] isEnabled in
                self?.setLaunchAtLogin(isEnabled)
            }
            .store(in: &cancellables)
    }

    func activate() {
        syncAppearance()
        syncLaunchAtLoginFromSystem()
    }

    private func syncAppearance() {
        guard let app = NSApp else { return }

        switch settingsStore.appearance {
        case .system:
            app.appearance = nil
        case .light:
            app.appearance = NSAppearance(named: .vibrantLight)
        case .dark:
            app.appearance = NSAppearance(named: .vibrantDark)
        }
    }

    private func setLaunchAtLogin(_ isEnabled: Bool) {
        guard isSynchronizingLaunchAtLogin == false else { return }

        do {
            if isEnabled {
                try SMAppService.mainApp.register()
            } else {
                try SMAppService.mainApp.unregister()
            }
            syncLaunchAtLoginFromSystem()
        } catch {
            settingsStore.updateLaunchAtLoginState(.unavailable(Self.userFacingLaunchAtLoginError(from: error)))
            syncStoredLaunchAtLoginValue(from: SMAppService.mainApp.status)
        }
    }

    private func syncLaunchAtLoginFromSystem() {
        let status = SMAppService.mainApp.status
        syncStoredLaunchAtLoginValue(from: status)

        switch status {
        case .enabled:
            settingsStore.updateLaunchAtLoginState(.enabled)
        case .notRegistered:
            settingsStore.updateLaunchAtLoginState(.disabled)
        case .notFound:
            settingsStore.updateLaunchAtLoginState(.unavailable("当前环境暂不支持“登录时自动打开”。"))
        case .requiresApproval:
            settingsStore.updateLaunchAtLoginState(.requiresApproval)
        @unknown default:
            settingsStore.updateLaunchAtLoginState(.unavailable("暂时无法读取“登录时自动打开”的状态。"))
        }
    }

    private func syncStoredLaunchAtLoginValue(from status: SMAppService.Status) {
        let shouldBeEnabled: Bool
        switch status {
        case .enabled, .requiresApproval:
            shouldBeEnabled = true
        case .notRegistered, .notFound:
            shouldBeEnabled = false
        @unknown default:
            shouldBeEnabled = settingsStore.launchAtLogin
        }

        guard settingsStore.launchAtLogin != shouldBeEnabled else { return }

        isSynchronizingLaunchAtLogin = true
        settingsStore.launchAtLogin = shouldBeEnabled
        isSynchronizingLaunchAtLogin = false
    }

    private static func userFacingLaunchAtLoginError(from error: Error) -> String {
        "设置“登录时自动打开”失败：\(error.localizedDescription)"
    }
}
