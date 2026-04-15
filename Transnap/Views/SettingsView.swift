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
    @State private var selectedTab: SettingsTab? = .general

    enum SettingsTab: String, CaseIterable, Identifiable {
        case general, translation, shortcut, offline, about
        var id: String { rawValue }
        
        var title: String {
            switch self {
            case .general: return "常规"
            case .translation: return "翻译"
            case .shortcut: return "快捷键"
            case .offline: return "离线模型"
            case .about: return "关于"
            }
        }
        
        var icon: String {
            switch self {
            case .general: return "gearshape"
            case .translation: return "character.bubble"
            case .shortcut: return "keyboard"
            case .offline: return "shippingbox"
            case .about: return "info.circle"
            }
        }
        
        var color: Color {
            switch self {
            case .general: return .blue
            case .translation: return .green
            case .shortcut: return .orange
            case .offline: return .indigo
            case .about: return .gray
            }
        }
    }

    var body: some View {
        NavigationSplitView {
            List(SettingsTab.allCases, selection: $selectedTab) { tab in
                NavigationLink(value: tab) {
                    HStack(spacing: 12) {
                        Image(systemName: tab.icon)
                            .symbolRenderingMode(.hierarchical)
                            .foregroundStyle(tab.color)
                            .font(.system(size: 13, weight: .semibold))
                            .frame(width: 26, height: 26)
                            .background(tab.color.opacity(0.1), in: RoundedRectangle(cornerRadius: 6, style: .continuous))
                        
                        Text(tab.title)
                            .font(.system(size: 13, weight: selectedTab == tab ? .medium : .regular))
                    }
                    .padding(.vertical, 4)
                }
            }
            .listStyle(.sidebar)
            .navigationSplitViewColumnWidth(min: 170, ideal: 185, max: 200)
        } detail: {
            ZStack {
                Color(NSColor.windowBackgroundColor)
                    .ignoresSafeArea()
                
                if let tab = selectedTab {
                    ScrollView {
                        VStack(alignment: .leading, spacing: 0) {
                            Text(tab.title)
                                .font(.system(size: 24, weight: .bold))
                                .padding(.horizontal, 24)
                                .padding(.top, 24)
                                .padding(.bottom, 16)
                            
                            switch tab {
                            case .general:
                                GeneralSettingsView(settingsStore: settingsStore)
                            case .translation:
                                TranslationSettingsView(settingsStore: settingsStore)
                            case .shortcut:
                                ShortcutSettingsView(settingsStore: settingsStore)
                            case .offline:
                                if #available(macOS 15.0, *) {
                                    OfflineSettingsView(settingsStore: settingsStore)
                                } else {
                                    ContentUnavailableView("需要 macOS 15 或更新版本", systemImage: "exclamationmark.triangle")
                                }
                            case .about:
                                AboutSettingsView()
                            }
                        }
                    }
                    .id(tab)
                } else {
                    Text("请选择一个项目")
                        .foregroundStyle(.secondary)
                }
            }
        }
        .frame(width: 760, height: 540)
        .preferredColorScheme(settingsStore.appearance == .system ? nil : (settingsStore.appearance == .dark ? .dark : .light))
    }
}

// MARK: - General Tab
struct GeneralSettingsView: View {
    @ObservedObject var settingsStore: SettingsStore
    @Environment(\.modelContext) private var modelContext
    @Query private var history: [TranslationRecord]
    @State private var showingClearHistoryAlert = false
    @State private var clearHistoryErrorMessage: String?

    var body: some View {
        VStack(spacing: 24) {
            SettingsGroup(header: "外观") {
                HStack(spacing: 20) {
                    AppearanceOption(title: "跟随系统", type: .system, current: $settingsStore.appearance)
                    AppearanceOption(title: "浅色", type: .light, current: $settingsStore.appearance)
                    AppearanceOption(title: "深色", type: .dark, current: $settingsStore.appearance)
                    Spacer()
                }
                .padding(.vertical, 4)
            }


            SettingsGroup(header: "启动行为", footer: settingsStore.launchAtLoginState.message) {
                HStack {
                    Toggle("跟随电脑启动", isOn: $settingsStore.launchAtLogin)
                    Spacer()
                }
            }

            SettingsGroup(header: "内容管理", footer: "历史记录仅保存在本地，Transnap 不会上传您的任何翻译数据。") {
                LabeledContent {
                    HStack(spacing: 12) {
                        Slider(value: Binding(
                            get: { Double(settingsStore.historyLimit) },
                            set: { settingsStore.historyLimit = Int($0) }
                        ), in: 10...200, step: 10)
                        
                        Text("\(settingsStore.historyLimit)")
                            .font(.system(.body, design: .monospaced))
                            .fontWeight(.medium)
                            .frame(width: 36, alignment: .trailing)
                        
                        Text("条")
                            .font(.system(size: 12))
                            .foregroundStyle(.secondary)
                    }
                } label: {
                    Text("记录上限")
                        .font(.system(size: 13))
                }
                
                Divider()
                
                Button(role: .destructive) {
                    showingClearHistoryAlert = true
                } label: {
                    Text("立即清空所有历史记录")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(.red)
                        .frame(maxWidth: .infinity, alignment: .center)
                }
                .buttonStyle(.plain)
                .padding(.vertical, 4)
                .disabled(history.isEmpty)
            }
        }
        .padding(.horizontal, 24)
        .padding(.bottom, 40)
        .alert("清空所有历史记录？", isPresented: $showingClearHistoryAlert) {
            Button("取消", role: .cancel) {}
            Button("清空", role: .destructive) {
                clearAllHistory()
            }
        } message: {
            Text("此操作会删除本地保存的全部翻译记录，且无法恢复。")
        }
        .alert("清空失败", isPresented: Binding(
            get: { clearHistoryErrorMessage != nil },
            set: { if !$0 { clearHistoryErrorMessage = nil } }
        )) {
            Button("知道了", role: .cancel) {}
        } message: {
            Text(clearHistoryErrorMessage ?? "")
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

// MARK: - Helper Views
struct SettingsGroup<Content: View>: View {
    let header: String?
    var footer: String? = nil
    let content: Content
    
    init(header: String? = nil, footer: String? = nil, @ViewBuilder content: () -> Content) {
        self.header = header
        self.footer = footer
        self.content = content()
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            if let header = header {
                Text(header)
                    .font(.system(size: 11, weight: .bold))
                    .foregroundStyle(.secondary)
                    .padding(.leading, 4)
            }
            
            VStack(alignment: .leading, spacing: 12) {
                content
            }
            .padding(14)
            .background(Color(NSColor.controlBackgroundColor).opacity(0.45))
            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .stroke(Color.primary.opacity(0.04), lineWidth: 0.5)
            )
            
            if let footer = footer {
                Text(footer)
                    .font(.system(size: 11))
                    .foregroundStyle(.tertiary)
                    .padding(.leading, 4)
                    .padding(.top, -2)
            }
        }
    }
}

struct AppearanceOption: View {
    let title: String
    let type: SettingsStore.Appearance
    @Binding var current: SettingsStore.Appearance
    
    var isSelected: Bool { current == type }
    
    var body: some View {
        Button {
            withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
                current = type
            }
        } label: {
            VStack(spacing: 12) {
                ZStack {
                    // Preview content simulating a macOS window
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .fill(previewBackground)
                        .frame(width: 96, height: 64)
                        .shadow(color: .black.opacity(isSelected ? 0.12 : 0.04), radius: isSelected ? 8 : 2, y: isSelected ? 4 : 1)
                    
                    if type == .system {
                        HStack(spacing: 0) {
                            Rectangle().fill(Color.white).frame(width: 48)
                            Rectangle().fill(Color.black.opacity(0.85)).frame(width: 48)
                        }
                        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                    }
                    
                    // Decorative elements representing a mini window
                    VStack(alignment: .leading, spacing: 4) {
                        HStack(spacing: 3) {
                            Circle().fill(Color.red.opacity(0.5)).frame(width: 4, height: 4)
                            Circle().fill(Color.yellow.opacity(0.5)).frame(width: 4, height: 4)
                            Circle().fill(Color.green.opacity(0.5)).frame(width: 4, height: 4)
                            Spacer()
                        }
                        .padding(.top, 4)
                        .padding(.leading, 6)
                        
                        Rectangle()
                            .fill(isSelected ? Color.blue.opacity(0.15) : Color.primary.opacity(0.05))
                            .frame(width: 50, height: 6)
                            .cornerRadius(2)
                            .padding(.leading, 6)
                        
                        Rectangle()
                            .fill(Color.primary.opacity(0.03))
                            .frame(height: 24)
                            .padding(.horizontal, 6)
                    }
                    .frame(width: 96, height: 64, alignment: .top)
                    
                    if isSelected {
                        RoundedRectangle(cornerRadius: 9, style: .continuous)
                            .stroke(Color.blue, lineWidth: 2.5)
                            .frame(width: 101, height: 69)
                    }
                }
                .scaleEffect(isSelected ? 1.02 : 1.0)
                
                Text(title)
                    .font(.system(size: 11, weight: isSelected ? .medium : .regular))
                    .foregroundStyle(isSelected ? .primary : .secondary)
            }
        }
        .buttonStyle(.plain)
    }
    
    private var previewBackground: Color {
        switch type {
        case .light: return .white
        case .dark: return Color(white: 0.15)
        case .system: return .clear
        }
    }
}

// MARK: - Translation Tab
struct TranslationSettingsView: View {
    @ObservedObject var settingsStore: SettingsStore
    
    let languages = [
        ("auto", "自动检测"),
        ("zh-Hans", "简体中文"),
        ("en", "英语"),
        ("ja", "日语"),
        ("ko", "韩语"),
        ("fr", "法语"),
        ("de", "德语")
    ]
    
    var body: some View {
        VStack(spacing: 24) {
            SettingsGroup(header: "语言方向", footer: "当选择“自动检测”时，Transnap 会根据识别到的原文自动判断目标语言。") {
                HStack(spacing: 0) {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("原文").font(.caption2).foregroundStyle(.secondary)
                        Picker("", selection: $settingsStore.sourceLanguage) {
                            ForEach(languages, id: \.0) { opt in Text(opt.1).tag(opt.0) }
                        }
                        .labelsHidden()
                    }
                    
                    Image(systemName: "arrow.right")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundStyle(.blue.opacity(0.5))
                        .padding(.horizontal, 20)
                        .padding(.top, 18)
                    
                    VStack(alignment: .leading, spacing: 8) {
                        Text("译文").font(.caption2).foregroundStyle(.secondary)
                        Picker("", selection: $settingsStore.targetLanguage) {
                            ForEach(languages, id: \.0) { opt in Text(opt.1).tag(opt.0) }
                        }
                        .labelsHidden()
                    }
                    
                    Spacer()
                }
            }
        }
        .padding(.horizontal, 24)
    }
}

// MARK: - Shortcut Tab
struct ShortcutSettingsView: View {
    @ObservedObject var settingsStore: SettingsStore
    @State private var accessibilityTrusted = DoubleCopyMonitor.isAccessibilityTrusted()
    
    var body: some View {
        VStack(spacing: 24) {
            SettingsGroup(header: "全局快捷键") {
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("唤起主面板")
                            .font(.system(size: 13, weight: .medium))
                        Text("双击 ⌘C 之后，也可通过此快捷键手动唤起。")
                            .font(.system(size: 11))
                            .foregroundStyle(.secondary)
                    }
                    
                    Spacer()
                    
                    ShortcutRecorderView(settingsStore: settingsStore)
                        .frame(width: 160, height: 32)
                }
            }

            SettingsGroup(
                header: "双击 ⌘C",
                footer: "默认关闭。开启后仅在你已授予辅助功能权限时生效，Transnap 不会自动申请该权限。"
            ) {
                Toggle("启用双击 ⌘C 快速翻译", isOn: $settingsStore.doubleCopyTranslationEnabled)

                Divider()

                HStack(alignment: .top, spacing: 12) {
                    Image(systemName: accessibilityTrusted ? "checkmark.shield" : "exclamationmark.shield")
                        .foregroundStyle(accessibilityTrusted ? .green : .orange)
                        .frame(width: 20)

                    VStack(alignment: .leading, spacing: 6) {
                        Text(accessibilityTrusted ? "辅助功能权限已授权" : "辅助功能权限未授权")
                            .font(.system(size: 13, weight: .medium))

                        Text(
                            accessibilityTrusted
                            ? "双击 ⌘C 功能可以正常使用。"
                            : "如果你之后想启用这个功能，需要在系统设置 > 隐私与安全性 > 辅助功能里允许 Transnap。"
                        )
                        .font(.system(size: 11))
                        .foregroundStyle(.secondary)
                    }

                    Spacer()
                }

                if !accessibilityTrusted {
                    Button("打开辅助功能设置") {
                        DoubleCopyMonitor.openAccessibilitySettings()
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                }
            }
        }
        .padding(.horizontal, 24)
        .onAppear(perform: refreshAccessibilityStatus)
        .onReceive(NotificationCenter.default.publisher(for: NSApplication.didBecomeActiveNotification)) { _ in
            refreshAccessibilityStatus()
        }
    }

    private func refreshAccessibilityStatus() {
        accessibilityTrusted = DoubleCopyMonitor.isAccessibilityTrusted()
    }
}

// MARK: - Offline Tab
@available(macOS 15.0, *)
struct OfflineSettingsView: View {
    @ObservedObject var settingsStore: SettingsStore
    @StateObject private var offlineLanguageManager = OfflineLanguageManager()
    
    var body: some View {
        VStack(spacing: 24) {
            SettingsGroup(header: "系统翻译语言包", footer: "这里显示的是系统翻译框架返回的真实安装状态。点击下载后会调用系统翻译资源准备流程。") {
                VStack(spacing: 0) {
                    if offlineLanguageManager.packs.isEmpty {
                        Text("当前系统没有返回可管理的翻译语言。")
                            .font(.system(size: 13))
                            .foregroundStyle(.secondary)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(.vertical, 8)
                    }

                    ForEach(Array(offlineLanguageManager.packs.enumerated()), id: \.element.id) { index, pack in
                        HStack {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(pack.name)
                                    .font(.system(size: 14, weight: .medium))
                                Text(statusDescription(for: pack.identifier))
                                    .font(.system(size: 11))
                                    .foregroundStyle(.tertiary)
                            }
                            
                            Spacer()
                            
                            actionButton(for: pack.identifier)
                        }
                        .padding(.vertical, 10)
                        
                        if index < offlineLanguageManager.packs.count - 1 {
                            Divider()
                        }
                    }
                }
            }

            if let lastErrorMessage = offlineLanguageManager.lastErrorMessage {
                Text(lastErrorMessage)
                    .font(.system(size: 12))
                    .foregroundStyle(.orange)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .padding(.horizontal, 24)
        .padding(.bottom, 40)
        .task {
            await offlineLanguageManager.refreshStatuses()
        }
        .translationTask(offlineLanguageManager.pendingConfiguration) { session in
            await offlineLanguageManager.performPendingInstall(using: session)
        }
    }

    @ViewBuilder
    private func actionButton(for identifier: String) -> some View {
        let status = offlineLanguageManager.statuses[identifier] ?? .unsupported
        let isInstalling = offlineLanguageManager.isInstalling(identifier)

        switch status {
        case .installed:
            HStack(spacing: 4) {
                Text("已安装")
                Image(systemName: "checkmark.circle.fill")
            }
            .font(.system(size: 12, weight: .medium))
            .foregroundStyle(.green)
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(Color.green.opacity(0.1))
            .clipShape(Capsule())

        case .supported:
            Button {
                offlineLanguageManager.requestInstall(for: identifier)
            } label: {
                HStack(spacing: 6) {
                    if isInstalling {
                        LoadingSpinner(size: 16, lineWidth: 1.8, tint: .blue)
                            .fixedSize()
                    } else {
                        Image(systemName: "icloud.and.arrow.down")
                    }
                    Text(isInstalling ? "准备中" : "下载")
                }
                .fixedSize()
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(.blue)
            }
            .buttonStyle(.plain)
            .disabled(isInstalling)
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(Color.blue.opacity(0.1))
            .clipShape(Capsule())

        case .unsupported:
            HStack(spacing: 4) {
                Text("不可用")
                Image(systemName: "xmark.circle")
            }
            .font(.system(size: 12, weight: .medium))
            .foregroundStyle(.secondary)
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(Color.secondary.opacity(0.1))
            .clipShape(Capsule())
        @unknown default:
            HStack(spacing: 4) {
                Text("未知状态")
                Image(systemName: "questionmark.circle")
            }
            .font(.system(size: 12, weight: .medium))
            .foregroundStyle(.secondary)
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(Color.secondary.opacity(0.1))
            .clipShape(Capsule())
        }
    }

    private func statusDescription(for identifier: String) -> String {
        switch offlineLanguageManager.statuses[identifier] ?? .unsupported {
        case .installed:
            return "已安装到系统翻译资源中"
        case .supported:
            return offlineLanguageManager.isInstalling(identifier) ? "正在请求系统下载..." : "支持下载，可离线使用"
        case .unsupported:
            return "当前系统不支持该语言资源"
        @unknown default:
            return "系统返回了未识别的语言包状态"
        }
    }
}

// MARK: - About Tab
struct AboutSettingsView: View {
    @State private var iconScale: CGFloat = 1.0

    private var versionDescription: String {
        let info = Bundle.main.infoDictionary
        let shortVersion = info?["CFBundleShortVersionString"] as? String ?? "1.0"
        let buildNumber = info?["CFBundleVersion"] as? String ?? "1"

        if shortVersion == buildNumber {
            return "Version \(shortVersion)"
        }

        return "Version \(shortVersion) (\(buildNumber))"
    }
    
    var body: some View {
        VStack(spacing: 0) {
            VStack(spacing: 24) {
                ZStack {
                    RoundedRectangle(cornerRadius: 24, style: .continuous)
                        .fill(LinearGradient(colors: [.blue.opacity(0.8), .indigo], startPoint: .topLeading, endPoint: .bottomTrailing))
                        .frame(width: 100, height: 100)
                        .shadow(color: .blue.opacity(0.3), radius: 20, y: 10)
                    
                    Image(systemName: "character.bubble.fill")
                        .font(.system(size: 52))
                        .foregroundStyle(.white)
                        .shadow(color: .black.opacity(0.1), radius: 5)
                }
                .scaleEffect(iconScale)
                .onAppear {
                    withAnimation(.easeInOut(duration: 2.0).repeatForever(autoreverses: true)) {
                        iconScale = 1.05
                    }
                }
                
                VStack(spacing: 8) {
                    Text("Transnap")
                        .font(.system(size: 36, weight: .bold, design: .rounded))
                        .foregroundStyle(.primary)
                    
                    Text(versionDescription)
                        .font(.system(.subheadline, design: .monospaced))
                        .opacity(0.6)
                }
            }
            .padding(.top, 48)
            
            VStack(spacing: 12) {
                Text("极致简单的贴心翻译")
                    .font(.system(size: 15, weight: .semibold))
                
                Text("基于 macOS 本地机器学习技术")
                    .font(.system(size: 13))
                    .foregroundStyle(.secondary)
            }
            .padding(.top, 32)
            
            Spacer()
            
            VStack(spacing: 16) {
                HStack(spacing: 24) {
                    AboutLink(title: "用户协议", url: "https://maxc.cc/user-agreement/")
                    AboutLink(title: "隐私政策", url: "https://maxc.cc/privacy-policy/")
                    AboutLink(title: "使用条款", url: "https://maxc.cc/terms-of-use/")
                }
                
                Button {
                    openXiaohongshu()
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: "heart.circle.fill") // 小红书常用的心情/红心感
                        Text("关注开发者 (小红书)")
                    }
                    .font(.caption)
                    .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
                .onHover { isHovering in
                    if isHovering {
                        NSCursor.pointingHand.push()
                    } else {
                        NSCursor.pop()
                    }
                }
            }
            .padding(.bottom, 48)
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

struct AboutLink: View {
    let title: String
    let url: String
    var body: some View {
        Link(title, destination: URL(string: url)!)
            .font(.caption)
            .foregroundStyle(.blue)
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
        label.font = .monospacedSystemFont(ofSize: 12, weight: .medium)
        label.textColor = .secondaryLabelColor
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
