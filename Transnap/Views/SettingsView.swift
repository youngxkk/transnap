//
//  SettingsView.swift
//  Transnap
//
//  Created by Codex on 2026/4/11.
//

import AppKit
import SwiftUI

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
                            .foregroundStyle(.white)
                            .font(.system(size: 14, weight: .medium))
                            .frame(width: 28, height: 28)
                            .background(tab.color.gradient)
                            .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
                        
                        Text(tab.title)
                            .font(.system(size: 13))
                    }
                    .padding(.vertical, 4)
                }
            }
            .listStyle(.sidebar)
            .navigationSplitViewColumnWidth(min: 160, ideal: 180, max: 200)
        } detail: {
            ZStack {
                Color(NSColor.windowBackgroundColor)
                    .ignoresSafeArea()
                
                if let tab = selectedTab {
                    ScrollView {
                        VStack(alignment: .leading, spacing: 0) {
                            Text(tab.title)
                                .font(.system(size: 24, weight: .bold))
                                .padding(.horizontal, 30)
                                .padding(.top, 30)
                                .padding(.bottom, 20)
                            
                            switch tab {
                            case .general:
                                GeneralSettingsView(settingsStore: settingsStore)
                            case .translation:
                                TranslationSettingsView(settingsStore: settingsStore)
                            case .shortcut:
                                ShortcutSettingsView(settingsStore: settingsStore)
                            case .offline:
                                OfflineSettingsView(settingsStore: settingsStore)
                            case .about:
                                AboutSettingsView()
                            }
                        }
                    }
                    .id(tab) // Force refresh on tab change
                } else {
                    Text("请选择一个项目")
                        .foregroundStyle(.secondary)
                }
            }
        }
        .frame(width: 700, height: 500)
    }
}

// MARK: - General Tab
struct GeneralSettingsView: View {
    @ObservedObject var settingsStore: SettingsStore
    
    var body: some View {
        VStack(spacing: 24) {
            SettingsGroup(header: "外观") {
                VStack(alignment: .leading, spacing: 16) {
                    HStack(spacing: 24) {
                        AppearanceOption(title: "跟随系统", type: .system, current: $settingsStore.appearance)
                        AppearanceOption(title: "浅色", type: .light, current: $settingsStore.appearance)
                        AppearanceOption(title: "深色", type: .dark, current: $settingsStore.appearance)
                    }
                }
                .padding(.vertical, 8)
            }
            
            SettingsGroup(header: "偏好设置") {
                LabeledContent("显示语言") {
                    Picker("", selection: $settingsStore.appLanguage) {
                        Text("简体中文").tag("zh-Hans")
                        Text("English").tag("en")
                    }
                    .frame(width: 140)
                }
                
                Divider()
                
                Toggle("跟随电脑启动", isOn: $settingsStore.launchAtLogin)
            }
            
            SettingsGroup(header: "内容管理", footer: "历史记录仅保存在本地，Transnap 不会上传您的任何翻译数据。") {
                LabeledContent("历史保留上限") {
                    HStack {
                        Slider(value: Binding(
                            get: { Double(settingsStore.historyLimit) },
                            set: { settingsStore.historyLimit = Int($0) }
                        ), in: 50...1000, step: 50)
                        Text("\(settingsStore.historyLimit) 条")
                            .monospacedDigit()
                            .font(.system(size: 11, design: .monospaced))
                            .frame(width: 60, alignment: .trailing)
                    }
                }
                
                Divider()
                
                Button(role: .destructive) {
                    settingsStore.clearAllHistory()
                } label: {
                    Text("立即清空所有历史记录")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(.red)
                        .frame(maxWidth: .infinity, alignment: .center)
                }
                .buttonStyle(.plain)
                .padding(.vertical, 4)
            }
        }
        .padding(.horizontal, 30)
        .padding(.bottom, 40)
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
        VStack(alignment: .leading, spacing: 8) {
            if let header = header {
                Text(header.uppercased())
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(.secondary)
                    .padding(.leading, 4)
            }
            
            VStack(alignment: .leading, spacing: 12) {
                content
            }
            .padding(16)
            .background(Color(NSColor.controlBackgroundColor).opacity(0.4))
            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .stroke(Color.primary.opacity(0.05), lineWidth: 1)
            )
            
            if let footer = footer {
                Text(footer)
                    .font(.system(size: 11))
                    .foregroundStyle(.tertiary)
                    .padding(.leading, 4)
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
            withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                current = type
            }
        } label: {
            VStack(spacing: 8) {
                ZStack {
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .fill(backgroundColor)
                        .frame(width: 80, height: 56)
                        .shadow(color: .black.opacity(isSelected ? 0.15 : 0.05), radius: isSelected ? 4 : 2)
                    
                    if type == .system {
                        HStack(spacing: 0) {
                            Rectangle().fill(Color.white).frame(width: 40)
                            Rectangle().fill(Color.black.opacity(0.85)).frame(width: 40)
                        }
                        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                    }
                    
                    if isSelected {
                        RoundedRectangle(cornerRadius: 8, style: .continuous)
                            .stroke(Color.blue, lineWidth: 3)
                    }
                }
                
                Text(title)
                    .font(.system(size: 12, weight: isSelected ? .medium : .regular))
                    .foregroundStyle(isSelected ? .primary : .secondary)
            }
        }
        .buttonStyle(.plain)
    }
    
    private var backgroundColor: Color {
        switch type {
        case .light: return .white
        case .dark: return .black.opacity(0.85)
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
                }
            }
        }
        .padding(.horizontal, 30)
    }
}

// MARK: - Shortcut Tab
struct ShortcutSettingsView: View {
    @ObservedObject var settingsStore: SettingsStore
    
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
        }
        .padding(.horizontal, 30)
    }
}

// MARK: - Offline Tab
struct OfflineSettingsView: View {
    @ObservedObject var settingsStore: SettingsStore
    
    let availableLanguages = [
        ("zh-Hans", "简体中文", "320 MB"),
        ("en", "英语", "280 MB"),
        ("ja", "日语", "350 MB"),
        ("ko", "韩语", "310 MB"),
        ("fr", "法语", "410 MB"),
        ("de", "德语", "390 MB"),
        ("es", "西班牙语", "430 MB")
    ]
    
    var body: some View {
        VStack(spacing: 24) {
            SettingsGroup(header: "原子化语言包", footer: "下载多个语言后，Transnap 即可在这些下载过的语言之间实现完全离线的互译。") {
                VStack(spacing: 0) {
                    ForEach(availableLanguages, id: \.0) { lang in
                        HStack {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(lang.1)
                                    .font(.system(size: 14, weight: .medium))
                                Text(lang.2)
                                    .font(.system(size: 11))
                                    .foregroundStyle(.tertiary)
                            }
                            
                            Spacer()
                            
                            let isDownloaded = settingsStore.downloadedLanguages.contains(lang.0)
                            
                            Button {
                                withAnimation(.interactiveSpring()) {
                                    settingsStore.toggleLanguageDownload(lang.0)
                                }
                            } label: {
                                if isDownloaded {
                                    HStack(spacing: 4) {
                                        Text("已就绪")
                                        Image(systemName: "checkmark.circle.fill")
                                    }
                                    .font(.system(size: 12, weight: .medium))
                                    .foregroundStyle(.green)
                                } else {
                                    HStack(spacing: 4) {
                                        Text("下载")
                                        Image(systemName: "icloud.and.arrow.down")
                                    }
                                    .font(.system(size: 12, weight: .medium))
                                    .foregroundStyle(.blue)
                                }
                            }
                            .buttonStyle(.plain)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 6)
                            .background(isDownloaded ? Color.green.opacity(0.1) : Color.blue.opacity(0.1))
                            .clipShape(Capsule())
                        }
                        .padding(.vertical, 10)
                        
                        if lang.0 != availableLanguages.last?.0 {
                            Divider()
                        }
                    }
                }
            }
        }
        .padding(.horizontal, 30)
        .padding(.bottom, 40)
    }
}

// MARK: - About Tab
struct AboutSettingsView: View {
    var body: some View {
        VStack(spacing: 0) {
            VStack(spacing: 20) {
                ZStack {
                    RoundedRectangle(cornerRadius: 22, style: .continuous)
                        .fill(LinearGradient(colors: [.blue.opacity(0.8), .blue], startPoint: .top, endPoint: .bottom))
                        .frame(width: 100, height: 100)
                        .shadow(color: .blue.opacity(0.4), radius: 15, y: 8)
                    
                    Image(systemName: "character.bubble.fill")
                        .font(.system(size: 56))
                        .foregroundStyle(.white)
                }
                
                VStack(spacing: 8) {
                    Text("Transnap")
                        .font(.system(size: 32, weight: .bold, design: .rounded))
                    
                    Text("Version 1.2.0")
                        .font(.system(.subheadline, design: .monospaced))
                        .foregroundStyle(.secondary)
                }
            }
            .padding(.top, 40)
            
            VStack(spacing: 12) {
                Text("极致简单的贴心翻译")
                    .font(.system(size: 15, weight: .medium))
                Text("基于 macOS 本地机器学习技术")
                    .font(.system(size: 13))
                    .foregroundStyle(.secondary)
            }
            .padding(.top, 30)
            
            Spacer()
            
            HStack(spacing: 24) {
                AboutLink(title: "访问官网", url: "https://transnap.app")
                AboutLink(title: "隐私政策", url: "https://transnap.app/privacy")
                AboutLink(title: "开发者", url: "https://github.com/youngxkk")
            }
            .padding(.bottom, 40)
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
        layer?.cornerRadius = 8
        layer?.backgroundColor = NSColor.white.cgColor
        layer?.borderColor = NSColor.black.withAlphaComponent(0.08).cgColor
        layer?.borderWidth = 1

        label.alignment = .center
        label.font = .systemFont(ofSize: 13)
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
