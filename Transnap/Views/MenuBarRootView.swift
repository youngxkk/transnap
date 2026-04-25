//
//  MenuBarRootView.swift
//  Transnap
//
//  Created by Codex on 2026/4/10.
//

import AppKit
import SwiftUI
import Translation

@available(macOS 15.0, *)
struct MenuBarRootView: View {
    @ObservedObject var viewModel: TransnapViewModel
    @ObservedObject var settingsStore: SettingsStore
    let windowCoordinator: WindowCoordinator

    var body: some View {
        Group {
            if settingsStore.hasCompletedWelcomeFlow {
                TranslatorPanelView(
                    viewModel: viewModel,
                    settingsStore: settingsStore,
                    windowCoordinator: windowCoordinator
                )
            } else {
                WelcomePanelView(
                    viewModel: viewModel,
                    settingsStore: settingsStore
                )
            }
        }
        .frame(width: 360, height: settingsStore.menuBarPanelHeight)
        .preferredColorScheme(preferredColorScheme)
    }

    private var preferredColorScheme: ColorScheme? {
        switch settingsStore.appearance {
        case .system:
            return nil
        case .light:
            return .light
        case .dark:
            return .dark
        }
    }
}

@available(macOS 15.0, *)
struct TranslatorWindowView: View {
    @ObservedObject var viewModel: TransnapViewModel
    @ObservedObject var settingsStore: SettingsStore
    let windowCoordinator: WindowCoordinator

    var body: some View {
        TranslatorPanelView(
            viewModel: viewModel,
            settingsStore: settingsStore,
            windowCoordinator: windowCoordinator
        )
        .frame(minWidth: 360, minHeight: 300)
        .preferredColorScheme(preferredColorScheme)
    }

    private var preferredColorScheme: ColorScheme? {
        switch settingsStore.appearance {
        case .system:
            return nil
        case .light:
            return .light
        case .dark:
            return .dark
        }
    }
}

@available(macOS 15.0, *)
private struct WelcomePanelView: View {
    @ObservedObject var viewModel: TransnapViewModel
    @ObservedObject var settingsStore: SettingsStore

    var body: some View {
        ScrollView(.vertical, showsIndicators: true) {
            VStack(alignment: .leading, spacing: 24) {
                header
                featureList

                Button("开始使用") {
                    settingsStore.hasCompletedWelcomeFlow = true
                    viewModel.handleMenuOpened()
                }
                .buttonStyle(.plain)
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(.white)
                .frame(width: 220, height: 52)
                .background(
                    Capsule(style: .continuous)
                        .fill(Color(red: 0.05, green: 0.48, blue: 0.98))
                )
                .shadow(color: .blue.opacity(0.22), radius: 10, y: 5)
                .padding(.top, 6)
                .frame(maxWidth: .infinity, alignment: .center)
            }
            .padding(.top, 30)
            .padding(.horizontal, 20)
            .padding(.bottom, 20)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .background(PanelBackgroundView())
        .scrollBounceBehavior(.basedOnSize)
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(alignment: .center, spacing: 14) {
                Image(nsImage: NSApplication.shared.applicationIconImage)
                    .resizable()
                    .interpolation(.high)
                    .scaledToFit()
                    .frame(width: 58, height: 58)
                    .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                    .shadow(color: .black.opacity(0.12), radius: 10, y: 4)

                VStack(alignment: .leading, spacing: 4) {
                    Text("欢迎使用 Transnap")
                        .font(.system(size: 24, weight: .semibold))

                    Text("打开就能翻译。")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
            }
        }
    }

    private var featureList: some View {
        VStack(spacing: 0) {
            welcomeRow(
                symbol: "doc.on.clipboard",
                tint: .blue,
                title: "自动读取剪贴板",
                message: "打开面板后会直接带入剪贴板文本。"
            )

            Divider()
                .padding(.leading, 48)

            welcomeRow(
                symbol: "lock.shield",
                tint: .green,
                title: "仅在本机处理",
                message: "翻译和历史记录都保存在这台 Mac 上。"
            )

            Divider()
                .padding(.leading, 48)

            welcomeRow(
                symbol: "keyboard",
                tint: .orange,
                title: "快捷键快速打开",
                message: "按 \(settingsStore.shortcutDisplayString) 即可打开翻译面板。"
            )
        }
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .strokeBorder(Color.primary.opacity(0.06), lineWidth: 0.5)
        }
    }

    private func welcomeRow(
        symbol: String,
        tint: Color,
        title: String,
        message: String
    ) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: symbol)
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(tint)
                .frame(width: 24, height: 24)
                .padding(.top, 2)

            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .font(.system(size: 13, weight: .semibold))

                Text(message)
                    .font(.system(size: 12))
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Spacer(minLength: 0)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 16)
    }
}

@available(macOS 15.0, *)
private struct TranslatorPanelView: View {
    @Environment(\.colorScheme) private var colorScheme
    @ObservedObject var viewModel: TransnapViewModel
    @ObservedObject var settingsStore: SettingsStore
    let windowCoordinator: WindowCoordinator
    @StateObject private var offlineLanguageManager = OfflineLanguageManager()
    @State private var inputEditorHeight: CGFloat = 126
    @State private var dragStartPanelHeight: Double?
    private let resizeHandleHeight: CGFloat = 20
    private let inputMinLines = 5
    private let inputMaxLines = 8
    private let resultMinimumHeight: CGFloat = 126
    @State private var isHoveringCopy: Bool = false
    @State private var showCopiedFeedback = false

    var body: some View {
        ScrollView(.vertical, showsIndicators: true) {
            VStack(alignment: .leading, spacing: 14) {
                header
                inputSection
                actionSection
                resultSection
            }
            .padding(14)
            .padding(.bottom, resizeHandleHeight + 6)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .background(panelBackground)
        .scrollBounceBehavior(.basedOnSize)
        .animation(.spring(response: 0.34, dampingFraction: 0.86), value: viewModel.isTranslating)
        .animation(.easeInOut(duration: 0.22), value: viewModel.translatedText)
        .task {
            await offlineLanguageManager.refreshStatuses()
        }
        .translationTask(viewModel.translationConfiguration) { session in
            await viewModel.performTranslation(using: session)
        }
        .translationTask(offlineLanguageManager.pendingConfiguration) { session in
            await offlineLanguageManager.performPendingInstall(using: session)
        }
        .overlay(alignment: .bottom) {
            resizeHandle
        }
        .onChange(of: viewModel.copyFeedbackToken) { _, _ in
            guard !viewModel.translatedText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }

            withAnimation(.spring(response: 0.22, dampingFraction: 0.78)) {
                showCopiedFeedback = true
            }

            Task { @MainActor in
                try? await Task.sleep(for: .milliseconds(600))
                withAnimation(.easeInOut(duration: 0.2)) {
                    showCopiedFeedback = false
                }
            }
        }
    }

    @ViewBuilder
    private var panelBackground: some View {
        PanelBackgroundView()
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Label("Transnap", systemImage: "translate")
                    .font(.title3.weight(.semibold))

                if viewModel.isTranslating {
                    HStack(spacing: 6) {
                        spinnerView
                        Text("翻译中")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    .fixedSize()
                }

                Spacer()

                headerIcon(systemName: "clock") {
                    windowCoordinator.showHistoryWindow()
                }

                headerIcon(systemName: "gearshape") {
                    windowCoordinator.showSettingsWindow()
                }

                headerIcon(systemName: "xmark.circle") {
                    NSApp.terminate(nil)
                }
            }

            Text(viewModel.statusMessage)
                .font(.subheadline)
                .foregroundStyle(.secondary)

            if let lastErrorMessage = viewModel.lastErrorMessage {
                Text(lastErrorMessage)
                    .font(.caption)
                    .foregroundStyle(.orange)
                    .lineLimit(2)
            }
        }
    }

    private func headerIcon(systemName: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: systemName)
                .font(.system(size: 14, weight: .medium))
                .foregroundStyle(.secondary)
                .frame(width: 28, height: 28)
                .background(Color.black.opacity(0.05), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
        }
        .buttonStyle(.plain)
    }

    private var inputSection: some View {
        ZStack(alignment: .topLeading) {
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(inputSurfaceFill)

            AdaptiveTextEditor(
                text: $viewModel.inputText,
                dynamicHeight: $inputEditorHeight,
                minLines: inputMinLines,
                maxLines: inputMaxLines
            )
            .padding(.horizontal, 8)
            .padding(.vertical, 6)
            .frame(height: inputEditorHeight)
            .opacity(viewModel.isTranslating ? 0.68 : 1)

            if viewModel.inputText.isEmpty {
                Text("输入或粘贴要翻译的文本")
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 14)
                    .allowsHitTesting(false)
            }
        }
    }

    private var actionSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Button("翻译") {
                    viewModel.requestTranslationFromInput()
                }
                .keyboardShortcut(.return, modifiers: [])
                .buttonStyle(.borderedProminent)
                .buttonBorderShape(.capsule)
                .controlSize(.regular)

                languagePickerRow

                Spacer()

                if !viewModel.translatedText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    copyFloatingButton
                        .transition(.opacity.combined(with: .scale(scale: 0.92)))
                }
            }

            if let languageDownloadStatusRow {
                languageDownloadStatusRow
            }
        }
    }

    private var resizeHandle: some View {
        ZStack {
            Color.clear

            Capsule(style: .continuous)
                .fill(Color.primary.opacity(0.14))
                .frame(width: 52, height: 5)
                .overlay {
                    Capsule(style: .continuous)
                        .strokeBorder(Color.primary.opacity(0.06), lineWidth: 0.5)
                }
        }
        .frame(maxWidth: .infinity)
        .frame(height: resizeHandleHeight)
        .background(.regularMaterial.opacity(0.001))
        .contentShape(Rectangle())
        .modifier(ResizeCursorModifier())
        .gesture(
            DragGesture(minimumDistance: 2)
                .onChanged { value in
                    if dragStartPanelHeight == nil {
                        dragStartPanelHeight = settingsStore.menuBarPanelHeight
                    }

                    let startHeight = dragStartPanelHeight ?? settingsStore.menuBarPanelHeight
                    settingsStore.menuBarPanelHeight = startHeight + value.translation.height
                }
                .onEnded { _ in
                    dragStartPanelHeight = nil
                }
        )
    }

    private var resultSection: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                if viewModel.isTranslating {
                    translatingResultState
                        .transition(.opacity.combined(with: .scale(scale: 0.98)))
                } else if viewModel.translatedText.isEmpty {
                    Text("翻译结果会显示在这里")
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .transition(.opacity)
                } else {
                    Text(viewModel.translatedText)
                        .textSelection(.enabled)
                        .foregroundStyle(.primary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .transition(.asymmetric(
                            insertion: .opacity.combined(with: .move(edge: .bottom)),
                            removal: .opacity
                        ))
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.top, 2)
        }
        .frame(minHeight: resultMinimumHeight)
        .padding(12)
        .background(resultSurfaceFill, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
    }

    private var inputSurfaceFill: AnyShapeStyle {
        if colorScheme == .dark {
            return AnyShapeStyle(Color.white.opacity(0.08))
        } else {
            return AnyShapeStyle(.thinMaterial)
        }
    }

    private var resultSurfaceFill: AnyShapeStyle {
        if colorScheme == .dark {
            return AnyShapeStyle(Color.white.opacity(0.12))
        } else {
            return AnyShapeStyle(.ultraThinMaterial)
        }
    }

    private var translatingResultState: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 8) {
                spinnerView
                Text("正在生成译文")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            .fixedSize()

            VStack(alignment: .leading, spacing: 8) {
                placeholderLine(width: 0.92)
                placeholderLine(width: 0.84)
                placeholderLine(width: 0.68)
            }
        }
        .redacted(reason: .placeholder)
    }

    private func placeholderLine(width: CGFloat) -> some View {
        RoundedRectangle(cornerRadius: 4, style: .continuous)
            .fill(Color.primary.opacity(0.08))
            .frame(maxWidth: .infinity, alignment: .leading)
            .frame(height: 12)
            .padding(.trailing, 140 * (1 - width))
    }

    private var copyFloatingButton: some View {
        Button {
            viewModel.copyTranslatedText()
        } label: {
            ZStack {
                copyButtonLabel(
                    text: "复制译文",
                    systemImage: "doc.on.doc",
                    foregroundColor: .secondary
                )
                .opacity(showCopiedFeedback ? 0 : 1)

                copyButtonLabel(
                    text: "已复制",
                    systemImage: "checkmark",
                    foregroundColor: .green
                )
                .opacity(showCopiedFeedback ? 1 : 0)
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(
                (showCopiedFeedback ? Color.green.opacity(0.12) : Color.black.opacity(isHoveringCopy ? 0.08 : 0.04)),
                in: Capsule()
            )
        }
        .buttonStyle(.plain)
        .onHover { isHoveringCopy = $0 }
    }

    private var languagePickerRow: some View {
        HStack(spacing: 3) {
            compactLanguageMenu(
                title: sourceLanguageLabel,
                selection: settingsStore.sourceLanguage
            ) { identifier in
                selectSourceLanguage(identifier)
            }

            Button {
                swapLanguages()
            } label: {
                Image(systemName: "arrow.left.arrow.right")
                    .font(.system(size: 9, weight: .medium))
                    .foregroundStyle(.secondary)
                    .frame(width: 18, height: 18)
            }
            .buttonStyle(.plain)
            .help("交换原文和翻译语言")

            compactLanguageMenu(
                title: targetLanguageLabel,
                selection: settingsStore.targetLanguage
            ) { identifier in
                selectTargetLanguage(identifier)
            }
        }
        .padding(.horizontal, 5)
        .padding(.vertical, 2)
        .background(Color.black.opacity(0.03), in: Capsule())
        .fixedSize()
        .help("仅在自动识别不准确时手动指定语言")
    }

    private var sourceLanguageLabel: String {
        settingsStore.sourceLanguage == "auto"
            ? "自动检测"
            : TranslationLanguageOptions.title(for: settingsStore.sourceLanguage)
    }

    private var targetLanguageLabel: String {
        settingsStore.targetLanguage == "auto"
            ? "自动检测"
            : TranslationLanguageOptions.title(for: settingsStore.targetLanguage)
    }

    private func compactLanguageMenu(
        title: String,
        selection: String,
        onSelect: @escaping (String) -> Void
    ) -> some View {
        Menu {
            ForEach(TranslationLanguageOptions.all) { option in
                selectionAction(
                    title: option.title,
                    isSelected: selection == option.identifier
                ) {
                    onSelect(option.identifier)
                }
            }
        } label: {
            Text(title)
                .lineLimit(1)
                .font(.system(size: 10, weight: .medium))
                .foregroundStyle(selection == "auto" ? .tertiary : .secondary)
                .padding(.horizontal, 1)
                .padding(.vertical, 0.5)
        }
        .menuStyle(.borderlessButton)
    }

    private func swapLanguages() {
        let source = settingsStore.sourceLanguage
        let target = settingsStore.targetLanguage
        settingsStore.sourceLanguage = target
        settingsStore.targetLanguage = source
        requestLanguageInstallIfNeeded(for: target)
        requestLanguageInstallIfNeeded(for: source)
    }

    private func selectSourceLanguage(_ identifier: String) {
        settingsStore.sourceLanguage = identifier
        requestLanguageInstallIfNeeded(for: identifier)
    }

    private func selectTargetLanguage(_ identifier: String) {
        settingsStore.targetLanguage = identifier
        requestLanguageInstallIfNeeded(for: identifier)
    }

    private func requestLanguageInstallIfNeeded(for identifier: String) {
        Task {
            await offlineLanguageManager.requestInstallIfNeeded(for: identifier)
        }
    }

    private var languageDownloadStatusRow: AnyView? {
        if case let .installing(identifier) = offlineLanguageManager.installState {
            return AnyView(
                HStack(alignment: .center, spacing: 8) {
                    LoadingSpinner(size: 14, lineWidth: 1.6, tint: .blue)
                        .fixedSize()

                    VStack(alignment: .leading, spacing: 2) {
                        Text("正在下载 \(TranslationLanguageOptions.title(for: identifier)) 语言包")
                            .font(.system(size: 12, weight: .medium))
                            .foregroundStyle(.primary)
                        Text("关闭系统下载窗口后，Transnap 会继续等待下载完成。")
                            .font(.system(size: 11))
                            .foregroundStyle(.secondary)
                    }

                    Spacer(minLength: 0)
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 8)
                .background(Color.blue.opacity(0.08), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
            )
        }

        if let lastErrorMessage = offlineLanguageManager.lastErrorMessage {
            return AnyView(
                HStack(alignment: .center, spacing: 8) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .font(.system(size: 12))
                        .foregroundStyle(.orange)

                    VStack(alignment: .leading, spacing: 2) {
                        Text("语言包下载失败")
                            .font(.system(size: 12, weight: .medium))
                            .foregroundStyle(.primary)
                        Text(lastErrorMessage)
                            .font(.system(size: 11))
                            .foregroundStyle(.secondary)
                            .lineLimit(2)
                    }

                    Spacer(minLength: 0)
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 8)
                .background(Color.orange.opacity(0.08), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
            )
        }

        return nil
    }

    private func copyButtonLabel(
        text: String,
        systemImage: String,
        foregroundColor: Color
    ) -> some View {
        HStack(spacing: 6) {
            Image(systemName: systemImage)
                .font(.system(size: 11, weight: .semibold))
                .frame(width: 12)
            Text(text)
                .font(.caption.weight(.medium))
        }
        .foregroundStyle(foregroundColor)
    }

    private func selectionAction(
        title: String,
        isSelected: Bool,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            if isSelected {
                Label(title, systemImage: "checkmark")
            } else {
                Text(title)
            }
        }
    }

    private var spinnerView: some View {
        LoadingSpinner(size: 16, lineWidth: 1.8, tint: .secondary)
            .fixedSize()
    }
}

@available(macOS 15.0, *)
private struct PanelBackgroundView: View {
    var body: some View {
        let shape = RoundedRectangle(cornerRadius: 18, style: .continuous)

        Group {
            if #available(macOS 26.0, *) {
                shape
                    .fill(.clear)
                    .glassEffect(.regular, in: shape)
                    .overlay {
                        shape
                            .strokeBorder(Color.white.opacity(0.18), lineWidth: 0.5)
                    }
            } else {
                shape
                    .fill(Color.white.opacity(0.58))
                    .background(.regularMaterial, in: shape)
                    .overlay {
                        shape
                            .strokeBorder(Color.white.opacity(0.22), lineWidth: 0.5)
                    }
            }
        }
    }

}

private struct ResizeCursorModifier: ViewModifier {
    func body(content: Content) -> some View {
        content.onHover { isHovering in
            if isHovering {
                ResizeCursor.shared.push()
            } else {
                NSCursor.pop()
            }
        }
    }
}

private enum ResizeCursor {
    static let shared: NSCursor = .resizeUpDown
}
