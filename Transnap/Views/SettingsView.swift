//
//  SettingsView.swift
//  Transnap
//
//  Created by Codex on 2026/4/11.
//

import AppKit
import SwiftData
import SwiftUI
import Translation

struct SettingsView: View {
    @ObservedObject var settingsStore: SettingsStore
    @State private var activeTab: SettingsTab = .general

    enum SettingsTab: String, CaseIterable, Identifiable {
        case general, offline, about
        var id: String { rawValue }
        
        func title(in language: DisplayLanguage) -> String {
            switch self {
            case .general: return language.text("常规", "General", french: "Général", spanish: "General")
            case .offline: return language.text("离线包", "Offline Packs", french: "Packs hors ligne", spanish: "Paquetes sin conexión")
            case .about: return language.text("关于", "About", french: "À propos", spanish: "Acerca de")
            }
        }
        
        var icon: String {
            switch self {
            case .general: return "gearshape"
            case .offline: return "shippingbox"
            case .about: return "info.circle"
            }
        }
    }

    var body: some View {
        TabView(selection: $activeTab) {
            GeneralSettingsView(settingsStore: settingsStore)
                .tag(SettingsTab.general)
                .tabItem { Label(SettingsTab.general.title(in: settingsStore.displayLanguage), systemImage: SettingsTab.general.icon) }

            offlineTab
                .tag(SettingsTab.offline)
                .tabItem { Label(SettingsTab.offline.title(in: settingsStore.displayLanguage), systemImage: SettingsTab.offline.icon) }

            AboutSettingsView(settingsStore: settingsStore)
                .tag(SettingsTab.about)
                .tabItem { Label(SettingsTab.about.title(in: settingsStore.displayLanguage), systemImage: SettingsTab.about.icon) }
        }
        .frame(width: 480, height: 510)
        .padding(.vertical, 10)
        .preferredColorScheme(settingsStore.appearance == .system ? nil : (settingsStore.appearance == .dark ? .dark : .light))
    }

    @ViewBuilder
    private var offlineTab: some View {
        if #available(macOS 15.0, *) {
            OfflineSettingsView(settingsStore: settingsStore)
        } else {
            ContentUnavailableView(settingsStore.text("需要 macOS 15 或更新版本", "Requires macOS 15 or later"), systemImage: "exclamationmark.triangle")
        }
    }
}

// MARK: - General Tab
struct GeneralSettingsView: View {
    @ObservedObject var settingsStore: SettingsStore
    @Environment(\.modelContext) private var modelContext
    @Environment(\.scenePhase) private var scenePhase
    @Query private var history: [TranslationRecord]
    @State private var showingClearHistoryAlert = false
    @State private var clearHistoryErrorMessage: String?
    @State private var showingDoubleCopyPermissionExplanation = false
    @State private var hasInputMonitoringPermission = CGPreflightListenEventAccess()

    var body: some View {
        Form {
            Section {
                Picker(settingsStore.text("应用显示语言", "App Display Language"), selection: $settingsStore.displayLanguage) {
                    ForEach(DisplayLanguage.allCases) { language in
                        Text(language.title).tag(language)
                    }
                }

                Picker(settingsStore.text("外观", "Appearance"), selection: $settingsStore.appearance) {
                    ForEach(SettingsStore.Appearance.allCases) { appearance in
                        Text(appearance.title(in: settingsStore.displayLanguage)).tag(appearance)
                    }
                }

                HStack {
                    Text(settingsStore.text("登录时自动打开", "Open at Login"))
                    Spacer()
                    SettingsSwitch(
                        isOn: $settingsStore.launchAtLogin,
                        accessibilityLabel: settingsStore.text("登录时自动打开", "Open at Login")
                    )
                }
            } header: {
                Text(settingsStore.text("应用", "Application"))
            } footer: {
                Text(settingsStore.launchAtLoginState.message(in: settingsStore.displayLanguage))
            }

            Section {
                Picker(settingsStore.text("我的语言", "My Language"), selection: $settingsStore.primaryAutoDetectionLanguage) {
                    ForEach(TranslationLanguageOptions.autoDetectionCandidates) { option in
                        Text(option.title(in: settingsStore.displayLanguage)).tag(option.identifier)
                    }
                }

                Picker(settingsStore.text("常用互译语言", "Frequent Pair"), selection: $settingsStore.secondaryAutoDetectionLanguage) {
                    ForEach(TranslationLanguageOptions.autoDetectionCandidates) { option in
                        Text(option.title(in: settingsStore.displayLanguage)).tag(option.identifier)
                    }
                }
            } header: {
                Text(settingsStore.text("翻译", "Translation"))
            } footer: {
                Text(settingsStore.text("自动检测只会在这两种语言之间判断；其它语言需要在翻译面板里手动指定。", "Auto detection only decides between these two languages. Specify other languages manually in the translation panel."))
            }

            Section {
                HStack(alignment: .center, spacing: 16) {
                    Text(settingsStore.text("打开翻译窗口", "Open Translation Window"))
                        .frame(maxWidth: .infinity, alignment: .leading)

                    ShortcutRecorderView(settingsStore: settingsStore)
                        .frame(width: 176, height: 28)
                }

                HStack(alignment: .center, spacing: 16) {
                    Text(settingsStore.text("启用快捷键⌘ + C + C", "Enable Shortcut ⌘ + C + C"))
                        .frame(maxWidth: .infinity, alignment: .leading)

                    HStack(spacing: 12) {
                        inputMonitoringPermissionLabel

                        if !hasInputMonitoringPermission {
                            Button {
                                openInputMonitoringSettings()
                            } label: {
                                Image(systemName: "arrow.up.right.square")
                            }
                            .buttonStyle(.borderless)
                            .controlSize(.small)
                            .help(settingsStore.text("打开权限设置", "Open Permission Settings"))
                        }

                        SettingsSwitch(
                            isOn: Binding(
                                get: { settingsStore.doubleCopyShortcutEnabled },
                                set: { isEnabled in
                                    if isEnabled {
                                        showingDoubleCopyPermissionExplanation = true
                                    } else {
                                        settingsStore.doubleCopyShortcutEnabled = false
                                    }
                                }
                            ),
                            accessibilityLabel: settingsStore.text("启用快捷键⌘ + C + C", "Enable Shortcut ⌘ + C + C")
                        )
                    }
                }
            } header: {
                Text(settingsStore.text("快捷键", "Shortcuts"))
            } footer: {
                Text(settingsStore.text(
                    "点击键盘的 ⌘ + C + C（按住 ⌘ 并两次点击C），即可复制后快速显示翻译。如果打开权限后仍未生效，请重启 Transnap",
                    "Press ⌘ + C + C on the keyboard (hold ⌘ and press C twice) to copy and quickly show the translation. If it still does not work after enabling permission, restart Transnap."
                ))
            }

            Section {
                HStack {
                    Text(settingsStore.text("最多保存", "Keep up to"))
                    Spacer()
                    HStack(spacing: 10) {
                        Slider(value: Binding(
                            get: { Double(settingsStore.historyLimit) },
                            set: { settingsStore.historyLimit = Int($0) }
                        ), in: 10...200, step: 10)
                        .frame(width: 160)

                        Text("\(settingsStore.historyLimit)")
                            .monospacedDigit()
                            .frame(width: 34, alignment: .trailing)

                        Text(settingsStore.text("条", "items"))
                            .foregroundStyle(.secondary)
                    }
                }

                Button(role: .destructive) {
                    showingClearHistoryAlert = true
                } label: {
                    Text(settingsStore.text("清空历史记录", "Clear History"))
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(Color.red)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 7)
                        .background(Color.red.opacity(0.1), in: RoundedRectangle(cornerRadius: 6, style: .continuous))
                }
                .buttonStyle(.plain)
                .opacity(history.isEmpty ? 0.45 : 1)
                .disabled(history.isEmpty)
            } header: {
                Text(settingsStore.text("历史记录", "History"))
            } footer: {
                Text(settingsStore.text("历史记录只保存在这台 Mac 上，不会上传。", "History is stored only on this Mac and is never uploaded."))
            }
        }
        .formStyle(.grouped)
        .alert(settingsStore.text("启用 ⌘C 连按翻译？", "Enable Double ⌘C Translation?"), isPresented: $showingDoubleCopyPermissionExplanation) {
            Button(settingsStore.text("取消", "Cancel"), role: .cancel) {}
            Button(settingsStore.text("确认启用", "Enable")) {
                requestInputMonitoringPermissionAndEnable()
            }
        } message: {
            Text(settingsStore.text(
                "Transnap 只监听按下 ⌘+C+C 快捷键，不记录键盘输入内容。",
                "Transnap only listens for the ⌘+C+C shortcut and does not record keyboard input."
            ))
        }
        .alert(settingsStore.text("清空历史记录？", "Clear history?"), isPresented: $showingClearHistoryAlert) {
            Button(settingsStore.text("取消", "Cancel"), role: .cancel) {}
            Button(settingsStore.text("清空", "Clear"), role: .destructive) {
                clearAllHistory()
            }
        } message: {
            Text(settingsStore.text("这会删除这台 Mac 上的全部翻译记录，且无法恢复。", "This will delete all translation history on this Mac and cannot be undone."))
        }
        .alert(settingsStore.text("清空失败", "Could Not Clear History"), isPresented: Binding(
            get: { clearHistoryErrorMessage != nil },
            set: { if !$0 { clearHistoryErrorMessage = nil } }
        )) {
            Button(settingsStore.text("知道了", "OK"), role: .cancel) {}
        } message: {
            Text(clearHistoryErrorMessage ?? "")
        }
        .onAppear {
            refreshInputMonitoringPermission()
        }
        .onChange(of: scenePhase) { _, phase in
            guard phase == .active else { return }
            refreshInputMonitoringPermission()
        }
    }

    private var inputMonitoringPermissionLabel: some View {
        Label {
            Text(hasInputMonitoringPermission
                ? settingsStore.text("已开启", "Enabled")
                : settingsStore.text("未开启", "Disabled"))
        } icon: {
            Image(systemName: hasInputMonitoringPermission ? "checkmark.circle.fill" : "exclamationmark.circle.fill")
        }
        .foregroundStyle(hasInputMonitoringPermission ? .green : .orange)
        .font(.system(size: 12, weight: .medium))
    }

    private func refreshInputMonitoringPermission() {
        hasInputMonitoringPermission = CGPreflightListenEventAccess()
        if !hasInputMonitoringPermission, settingsStore.doubleCopyShortcutEnabled {
            settingsStore.doubleCopyShortcutEnabled = false
        }
    }

    private func requestInputMonitoringPermissionAndEnable() {
        let granted = CGRequestListenEventAccess()
        hasInputMonitoringPermission = granted || CGPreflightListenEventAccess()
        settingsStore.doubleCopyShortcutEnabled = hasInputMonitoringPermission
    }

    private func openInputMonitoringSettings() {
        let urlStrings = [
            "x-apple.systempreferences:com.apple.preference.security?Privacy_ListenEvent",
            "x-apple.systempreferences:com.apple.preference.security?Privacy"
        ]

        for urlString in urlStrings {
            guard let url = URL(string: urlString) else { continue }
            if NSWorkspace.shared.open(url) {
                return
            }
        }
    }

    private func clearAllHistory() {
        do {
            let records = try modelContext.fetch(FetchDescriptor<TranslationRecord>())
            for record in records {
                modelContext.delete(record)
            }
            try modelContext.save()
            clearHistoryErrorMessage = nil
        } catch {
            clearHistoryErrorMessage = error.localizedDescription
        }
    }
}

// MARK: - Offline Tab
@available(macOS 15.0, *)
struct OfflineSettingsView: View {
    @Environment(\.scenePhase) private var scenePhase
    @ObservedObject var settingsStore: SettingsStore
    @StateObject private var offlineLanguageManager = OfflineLanguageManager()
    
    var body: some View {
        Form {
            Section {
                HStack(alignment: .center, spacing: 16) {
                    VStack(alignment: .leading, spacing: 3) {
                        Text(settingsStore.text("系统语言包", "System Language Packs"))
                        Text(settingsStore.text("离线翻译语言包由 Apple 官方提供和管理。删除已下载语言包需要前往系统设置。", "Offline translation language packs are provided by Apple. To delete downloaded packs, open System Settings."))
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }

                    Spacer(minLength: 16)

                    Button {
                        openSystemTranslationLanguageSettings()
                    } label: {
                        Label(settingsStore.text("打开系统设置", "Open System Settings"), systemImage: "arrow.up.right.square")
                            .font(.system(size: 13, weight: .medium))
                            .padding(.horizontal, 12)
                            .padding(.vertical, 6)
                            .background(Color.accentColor.opacity(0.1), in: Capsule())
                            .overlay {
                                Capsule()
                                    .stroke(Color.accentColor.opacity(0.28), lineWidth: 1)
                            }
                    }
                    .buttonStyle(.plain)
                    .foregroundStyle(Color.accentColor)
                    .fixedSize()
                }
                .frame(minHeight: 54, alignment: .center)
            } header: {
                Text(settingsStore.text("关于离线语言包", "About Offline Language Packs"))
            }

            Section {
                if offlineLanguageManager.packs.isEmpty {
                    VStack(spacing: 8) {
                        Image(systemName: "shippingbox")
                            .font(.system(size: 28, weight: .regular))
                            .foregroundStyle(.secondary)
                        Text(settingsStore.text("当前没有可下载的语言包。", "No downloadable language packs are available."))
                            .font(.system(size: 13, weight: .medium))
                            .foregroundStyle(.secondary)
                    }
                    .frame(maxWidth: .infinity, minHeight: 150)
                }

                ForEach(offlineLanguageManager.packs) { pack in
                    LabeledContent {
                        actionButton(for: pack.identifier)
                    } label: {
                        VStack(alignment: .leading, spacing: 3) {
                            Text(TranslationLanguageOptions.title(for: pack.identifier, in: settingsStore.displayLanguage))
                            Text(statusDescription(for: pack.identifier))
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
            } header: {
                Text(settingsStore.text("离线语言包", "Offline Language Packs"))
            } footer: {
                Text(settingsStore.text("下载后可离线翻译。已下载语言包可在 macOS 系统设置中管理。", "After downloading, translation works offline. Downloaded packs can be managed in macOS System Settings."))
            }

            if let lastErrorMessage = offlineLanguageManager.lastErrorMessage {
                Section {
                    Label(lastErrorMessage, systemImage: "exclamationmark.triangle.fill")
                        .foregroundStyle(.orange)
                }
            }
        }
        .formStyle(.grouped)
        .task {
            await offlineLanguageManager.refreshStatuses()
        }
        .translationTask(offlineLanguageManager.pendingConfiguration) { session in
            await offlineLanguageManager.performPendingInstall(using: session)
        }
        .onChange(of: scenePhase) { _, phase in
            guard phase == .active else { return }

            Task {
                await offlineLanguageManager.refreshStatuses()
            }
        }
    }

    @ViewBuilder
    private func actionButton(for identifier: String) -> some View {
        let status = offlineLanguageManager.statuses[identifier] ?? .unsupported
        let isInstalling = offlineLanguageManager.isInstalling(identifier)

        switch status {
        case .installed:
            packStatusLabel(
                settingsStore.text("已下载", "Downloaded"),
                systemImage: "checkmark.circle.fill",
                tint: .green
            )

        case .supported:
            Button {
                offlineLanguageManager.requestInstall(for: identifier)
            } label: {
                packStatusLabel(
                    isInstalling ? settingsStore.text("下载中", "Downloading") : settingsStore.text("下载", "Download"),
                    systemImage: isInstalling ? nil : "icloud.and.arrow.down",
                    tint: .accentColor,
                    isLoading: isInstalling
                )
            }
            .buttonStyle(.plain)
            .disabled(isInstalling)

        case .unsupported:
            packStatusLabel(
                settingsStore.text("不支持", "Unsupported"),
                systemImage: "xmark.circle",
                tint: .secondary
            )
        @unknown default:
            packStatusLabel(
                settingsStore.text("状态未知", "Unknown"),
                systemImage: "questionmark.circle",
                tint: .secondary
            )
        }
    }

    private func packStatusLabel(
        _ title: String,
        systemImage: String?,
        tint: Color,
        isLoading: Bool = false
    ) -> some View {
        HStack(spacing: 6) {
            if isLoading {
                ProgressView()
                    .controlSize(.small)
                    .tint(tint)
            } else if let systemImage {
                Image(systemName: systemImage)
                    .imageScale(.medium)
            }

            Text(title)
        }
        .font(.system(size: 13, weight: .medium))
        .foregroundStyle(tint)
        .frame(minWidth: 84)
        .padding(.horizontal, 10)
        .padding(.vertical, 5)
        .background(tint.opacity(0.1), in: Capsule())
        .overlay {
            Capsule()
                .stroke(tint.opacity(0.28), lineWidth: 1)
        }
        .fixedSize()
    }

    private func statusDescription(for identifier: String) -> String {
        switch offlineLanguageManager.statuses[identifier] ?? .unsupported {
        case .installed:
            return settingsStore.text("已下载，可离线使用", "Downloaded and ready for offline use")
        case .supported:
            return offlineLanguageManager.isInstalling(identifier)
                ? settingsStore.text("正在下载...", "Downloading...")
                : settingsStore.text("可下载，下载后可离线使用", "Available to download for offline use")
        case .unsupported:
            return settingsStore.text("暂不支持离线使用", "Offline use is not supported yet")
        @unknown default:
            return settingsStore.text("暂时无法确认状态", "Status cannot be confirmed right now")
        }
    }

    private func openSystemTranslationLanguageSettings() {
        let urlStrings = [
            "x-apple.systempreferences:com.apple.Localization-Settings.extension?translation",
            "x-apple.systempreferences:com.apple.Localization-Settings.extension",
            "x-apple.systempreferences:com.apple.Localization"
        ]

        for urlString in urlStrings {
            guard let url = URL(string: urlString) else { continue }
            if NSWorkspace.shared.open(url) {
                return
            }
        }

        offlineLanguageManager.lastErrorMessage = settingsStore.text(
            "无法打开系统设置，请手动前往“系统设置 > 通用 > 语言与地区 > 翻译语言”。",
            "Could not open System Settings. Go to System Settings > General > Language & Region > Translation Languages."
        )
    }
}

// MARK: - About Tab
struct AboutSettingsView: View {
    @ObservedObject var settingsStore: SettingsStore

    private var version: String {
        let info = Bundle.main.infoDictionary
        return info?["CFBundleShortVersionString"] as? String ?? "1.0"
    }

    private var build: String {
        let info = Bundle.main.infoDictionary
        return info?["CFBundleVersion"] as? String ?? "1"
    }
    
    var body: some View {
        VStack(spacing: 24) {
            Spacer()

            Image(nsImage: NSApplication.shared.applicationIconImage)
                .resizable()
                .interpolation(.high)
                .scaledToFit()
                .frame(width: 84, height: 84)
                .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
                .shadow(color: .black.opacity(0.12), radius: 12, y: 4)

            VStack(spacing: 8) {
                Text("Transnap")
                    .font(.system(size: 26, weight: .bold, design: .rounded))

                Text(settingsStore.text("复制一下，马上翻译", "Copy once. Translate instantly."))
                    .font(.system(size: 15))
                    .foregroundStyle(.secondary)
            }

            VStack(spacing: 12) {
                Text("\(settingsStore.text("版本", "Version")) \(version) (\(build))")
                    .font(.system(size: 12, weight: .medium, design: .monospaced))
                    .foregroundStyle(.tertiary)

                Button {
                    sendFeedback()
                } label: {
                    Label(settingsStore.text("反馈问题", "Send Feedback"), systemImage: "envelope.fill")
                        .font(.system(size: 13, weight: .medium))
                        .padding(.horizontal, 16)
                        .padding(.vertical, 8)
                        .background(Color.accentColor.opacity(0.12), in: Capsule())
                        .foregroundStyle(Color.accentColor)
                }
                .buttonStyle(.plain)
            }

            Spacer()

            VStack(spacing: 8) {
                Text("© 2026 Transnap Team")
                    .font(.system(size: 11))
                    .foregroundStyle(.quaternary)

                HStack(spacing: 12) {
                    Link(destination: URL(string: "https://maxc.cc/user-agreement/")!) {
                        linkLabel(settingsStore.text("用户协议", "User Agreement"))
                    }

                    Link(destination: URL(string: "https://maxc.cc/privacy-policy/")!) {
                        linkLabel(settingsStore.text("隐私政策", "Privacy Policy"))
                    }

                    Link(destination: URL(string: "https://maxc.cc/terms-of-use/")!) {
                        linkLabel(settingsStore.text("使用条款", "Terms"))
                    }

                    Button {
                        openXiaohongshu()
                    } label: {
                        linkLabel(settingsStore.text("小红书", "Xiaohongshu"))
                    }
                    .buttonStyle(.plain)
                }
                .font(.system(size: 10))
                .foregroundStyle(.tertiary)
            }
        }
        .padding(.bottom, 30)
    }

    private func linkLabel(_ title: String) -> some View {
        HStack(spacing: 3) {
            Text(title)
            Image(systemName: "arrow.up.right")
                .font(.system(size: 7, weight: .bold))
        }
    }

    private func sendFeedback() {
        let subject = "Transnap Feedback (v\(version) build \(build))"
        let body = """
        Please describe the issue here:


        ----
        App Version: \(version) (\(build))
        macOS: \(ProcessInfo.processInfo.operatingSystemVersionString)
        Preferred Language: \(settingsStore.displayLanguage.rawValue)
        Appearance: \(settingsStore.appearance.rawValue)
        Shortcut: \(settingsStore.shortcutDisplayString)
        History Limit: \(settingsStore.historyLimit)
        """

        var components = URLComponents()
        components.scheme = "mailto"
        components.path = "deepseals@icloud.com"
        components.queryItems = [
            URLQueryItem(name: "subject", value: subject),
            URLQueryItem(name: "body", value: body)
        ]

        if let url = components.url {
            NSWorkspace.shared.open(url)
        }
    }
    
    private func openXiaohongshu() {
        let appUrl = URL(string: "xhsdiscover://user/5777e1583460946ad6894dc4")!
        let webUrl = URL(string: "https://xhslink.com/m/9T8pXxjXBQk")!
        
        if NSWorkspace.shared.urlForApplication(toOpen: appUrl) != nil {
            NSWorkspace.shared.open(appUrl)
        } else {
            NSWorkspace.shared.open(webUrl)
        }
    }
}

private struct SettingsSwitch: View {
    @Binding var isOn: Bool
    let accessibilityLabel: String
    @State private var isHovering = false

    var body: some View {
        Button {
            withAnimation(.easeInOut(duration: 0.16)) {
                isOn.toggle()
            }
        } label: {
            ZStack(alignment: isOn ? .trailing : .leading) {
                Capsule()
                    .fill(trackColor)
                    .overlay {
                        Capsule()
                            .strokeBorder(Color.primary.opacity(isOn ? 0.04 : 0.08), lineWidth: 0.5)
                    }

                Circle()
                    .fill(Color.white)
                    .frame(width: 20, height: 20)
                    .shadow(color: .black.opacity(0.22), radius: 2, y: 1)
                    .padding(2)
            }
            .frame(width: 42, height: 24)
            .contentShape(Capsule())
            .opacity(isHovering ? 0.92 : 1)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(accessibilityLabel)
        .accessibilityValue(isOn ? "On" : "Off")
        .accessibilityAddTraits(isOn ? [.isButton, .isSelected] : .isButton)
        .onHover { isHovering = $0 }
    }

    private var trackColor: Color {
        if isOn {
            Color.accentColor
        } else {
            Color(nsColor: .quaternaryLabelColor).opacity(0.65)
        }
    }
}

private struct ShortcutRecorderView: NSViewRepresentable {
    @ObservedObject var settingsStore: SettingsStore

    func makeNSView(context: Context) -> ShortcutRecorderField {
        let field = ShortcutRecorderField()
        field.onShortcutRecorded = { keyCode, modifiers in
            settingsStore.updateShortcut(keyCode: keyCode, modifiers: modifiers)
            field.displayString = settingsStore.shortcutDisplayString
        }
        field.displayString = settingsStore.shortcutDisplayString
        return field
    }

    func updateNSView(_ nsView: ShortcutRecorderField, context: Context) {
        nsView.displayString = settingsStore.shortcutDisplayString
    }
}

final class ShortcutRecorderField: NSView {
    var onShortcutRecorded: ((UInt32, UInt32) -> Void)?
    var displayString: String = "" {
        didSet {
            label.stringValue = isRecording ? "按下快捷键" : displayString
        }
    }

    private let label = NSTextField(labelWithString: "")
    private var isRecording = false

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        wantsLayer = true
        layer?.cornerRadius = 6
        layer?.backgroundColor = NSColor.controlBackgroundColor.cgColor
        layer?.borderColor = NSColor.textColor.withAlphaComponent(0.06).cgColor
        layer?.borderWidth = 1

        label.alignment = .center
        label.font = .monospacedSystemFont(ofSize: 13, weight: .semibold)
        label.textColor = .labelColor
        label.translatesAutoresizingMaskIntoConstraints = false
        addSubview(label)

        NSLayoutConstraint.activate([
            label.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 8),
            label.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -8),
            label.centerYAnchor.constraint(equalTo: centerYAnchor)
        ])

        displayString = ""
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override var acceptsFirstResponder: Bool { true }

    override func mouseDown(with event: NSEvent) {
        window?.makeFirstResponder(self)
        isRecording = true
        label.stringValue = "按下快捷键"
    }

    override func resignFirstResponder() -> Bool {
        isRecording = false
        label.stringValue = displayString
        return true
    }

    override func keyDown(with event: NSEvent) {
        let modifiers = ShortcutFormatter.carbonModifiers(from: event.modifierFlags.intersection([.command, .option, .control, .shift]))
        guard modifiers != 0 else { return }

        onShortcutRecorded?(UInt32(event.keyCode), modifiers)
        isRecording = false
        window?.makeFirstResponder(nil)
    }
}
