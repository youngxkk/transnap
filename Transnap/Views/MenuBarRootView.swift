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
    @StateObject private var onboardingLanguageManager = OfflineLanguageManager()

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
                    settingsStore: settingsStore,
                    offlineLanguageManager: onboardingLanguageManager
                )
            }
        }
        .frame(width: 360, height: settingsStore.menuBarPanelHeight)
        .preferredColorScheme(preferredColorScheme)
        .translationTask(onboardingLanguageManager.pendingConfiguration) { session in
            await onboardingLanguageManager.performPendingInstall(using: session)
        }
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
    @ObservedObject var offlineLanguageManager: OfflineLanguageManager
    @State private var selectedSourceLanguage: String
    @State private var selectedTargetLanguage: String
    @State private var isHoveringStartButton = false

    init(
        viewModel: TransnapViewModel,
        settingsStore: SettingsStore,
        offlineLanguageManager: OfflineLanguageManager
    ) {
        self.viewModel = viewModel
        self.settingsStore = settingsStore
        self.offlineLanguageManager = offlineLanguageManager
        _selectedSourceLanguage = State(initialValue: Self.defaultSourceLanguage())
        _selectedTargetLanguage = State(initialValue: "en")
    }

    var body: some View {
        ScrollView(.vertical, showsIndicators: false) {
            VStack(alignment: .leading, spacing: 18) {
                header
                languageSetup

                startButton
            }
            .padding(.top, 24)
            .padding(.horizontal, 20)
            .padding(.bottom, 20)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .background(PanelBackgroundView())
        .scrollBounceBehavior(.basedOnSize)
    }

    private var header: some View {
        VStack(spacing: 12) {
            ZStack(alignment: .bottomTrailing) {
                Image(nsImage: NSApplication.shared.applicationIconImage)
                    .resizable()
                    .interpolation(.high)
                    .scaledToFit()
                    .frame(width: 64, height: 64)
                    .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
                    .shadow(color: .black.opacity(0.14), radius: 14, y: 6)

                Text("🎉")
                    .font(.system(size: 20))
                    .frame(width: 30, height: 30)
                    .background(.regularMaterial, in: Circle())
                    .overlay {
                        Circle()
                            .strokeBorder(Color.primary.opacity(0.08), lineWidth: 0.5)
                    }
                    .offset(x: 8, y: 6)
            }

            VStack(spacing: 5) {
                Text(settingsStore.text("欢迎使用 Transnap", "Welcome to Transnap"))
                    .font(.system(size: 25, weight: .semibold))

                Text(settingsStore.text("使用键盘快捷键⌘ + C + C（按住⌘并两次点击C），复制后自动在弹窗中显示翻译，此功能需到设置中手动打开", "Use the keyboard shortcut ⌘ + C + C (hold ⌘ and press C twice) to copy and automatically show the translation in the panel. This feature must be enabled manually in Settings."))
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 4)
        .padding(.bottom, 2)
    }

    private var languageSetup: some View {
        VStack(alignment: .leading, spacing: 8) {
            VStack(alignment: .leading, spacing: 12) {
                HStack(spacing: 6) {
                    Image(systemName: "globe")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(.blue)

                    Text(settingsStore.text("选择常用语言", "Choose Your Languages"))
                        .font(.system(size: 14, weight: .semibold))
                }

                HStack(spacing: 10) {
                    languagePicker(
                        title: settingsStore.text("我的语言", "My Language"),
                        selection: $selectedSourceLanguage
                    )

                    languagePicker(
                        title: settingsStore.text("主要翻译成", "Translate Mainly To"),
                        selection: $selectedTargetLanguage
                    )
                }
            }
            .padding(14)
            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .strokeBorder(Color.primary.opacity(0.06), lineWidth: 0.5)
            }

            Text(settingsStore.text(
                "下载语言包后翻译速度更快，轻量化，毫秒级。",
                "Download language packs for faster, lightweight, millisecond-level translation."
            ))
            .font(.system(size: 12))
            .foregroundStyle(.secondary)
            .fixedSize(horizontal: false, vertical: true)
        }
    }

    private func languagePicker(title: String, selection: Binding<String>) -> some View {
        VStack(alignment: .leading, spacing: 5) {
            Text(title)
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(.secondary)

            Picker(title, selection: selection) {
                ForEach(TranslationLanguageOptions.autoDetectionCandidates) { option in
                    Text(option.title(in: settingsStore.displayLanguage))
                        .tag(option.identifier)
                }
            }
            .labelsHidden()
            .pickerStyle(.menu)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var startButton: some View {
        Button(settingsStore.text("下载语言包并进入", "Download Languages and Continue")) {
            startOnboardingDownload()
        }
        .buttonStyle(.plain)
        .font(.system(size: 15, weight: .semibold))
        .foregroundStyle(.white)
        .frame(width: 240, height: 50)
        .background(
            Capsule(style: .continuous)
                .fill(startButtonFill)
        )
        .overlay {
            Capsule(style: .continuous)
                .strokeBorder(Color.white.opacity(isHoveringStartButton ? 0.36 : 0.16), lineWidth: 1)
        }
        .scaleEffect(isHoveringStartButton ? 1.035 : 1)
        .shadow(color: .blue.opacity(isHoveringStartButton ? 0.3 : 0.22), radius: isHoveringStartButton ? 13 : 10, y: isHoveringStartButton ? 6 : 5)
        .padding(.top, 2)
        .frame(maxWidth: .infinity, alignment: .center)
        .contentShape(Capsule(style: .continuous))
        .onHover { hovering in
            withAnimation(.easeOut(duration: 0.14)) {
                isHoveringStartButton = hovering
            }
        }
    }

    private var startButtonFill: Color {
        if isHoveringStartButton {
            return Color(red: 0.03, green: 0.54, blue: 1.0)
        }

        return Color(red: 0.05, green: 0.48, blue: 0.98)
    }

    private func startOnboardingDownload() {
        let sourceLanguage = selectedSourceLanguage
        var targetLanguage = selectedTargetLanguage

        if sourceLanguage == targetLanguage {
            targetLanguage = TranslationLanguageOptions.fallbackAutoDetectionLanguage(
                excluding: sourceLanguage
            )
            selectedTargetLanguage = targetLanguage
        }

        settingsStore.primaryAutoDetectionLanguage = sourceLanguage
        settingsStore.secondaryAutoDetectionLanguage = targetLanguage
        settingsStore.sourceLanguage = TranslationLanguageOptions.automaticIdentifier
        settingsStore.targetLanguage = TranslationLanguageOptions.automaticIdentifier
        settingsStore.hasCompletedWelcomeFlow = true
        viewModel.handleMenuOpened()

        offlineLanguageManager.requestInstall(
            source: sourceLanguage,
            target: targetLanguage
        )
    }

    private static func defaultSourceLanguage() -> String {
        let preferredIdentifier = Locale.preferredLanguages.first ?? Locale.current.identifier
        let language = Locale.Language(identifier: preferredIdentifier)
        let minimalIdentifier = language.minimalIdentifier
        let maximalIdentifier = language.maximalIdentifier

        if minimalIdentifier.hasPrefix("zh") || maximalIdentifier.contains("Hans") {
            return maximalIdentifier.contains("Hant") ? "zh-Hant" : "zh-Hans"
        }

        if let exactMatch = TranslationLanguageOptions.autoDetectionCandidates.first(where: {
            $0.identifier == minimalIdentifier || $0.identifier == preferredIdentifier
        }) {
            return exactMatch.identifier
        }

        return TranslationLanguageOptions.defaultPrimaryAutoDetectionLanguage
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
    @State private var isHoveringTranslate: Bool = false
    @State private var isHoveringSwapLanguages: Bool = false
    @State private var isHoveringCopy: Bool = false
    @State private var showCopiedFeedback = false

    var body: some View {
        ScrollView(.vertical, showsIndicators: false) {
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
                HStack(spacing: 7) {
                    Image("StatusBarIcon")
                        .renderingMode(.template)
                        .resizable()
                        .scaledToFit()
                        .frame(width: 18, height: 18)

                    Text("Transnap")
                }
                .font(.title3.weight(.semibold))

                if viewModel.isTranslating {
                    HStack(spacing: 6) {
                        spinnerView
                        Text(settingsStore.text("翻译中", "Translating"))
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    .fixedSize()
                }

                Spacer()

                headerIcon(systemName: "clock", hoverTint: .accentColor) {
                    windowCoordinator.showHistoryWindow()
                }

                headerIcon(systemName: "gear", hoverTint: .accentColor) {
                    windowCoordinator.showSettingsWindow()
                }

                headerIcon(systemName: "xmark.circle", hoverTint: .red) {
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

    private func headerIcon(systemName: String, hoverTint: Color, action: @escaping () -> Void) -> some View {
        HeaderIconButton(systemName: systemName, hoverTint: hoverTint, action: action)
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
                Text(settingsStore.text("输入或粘贴要翻译的文本", "Type or paste text to translate"))
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
                Button(settingsStore.text("翻译", "Trans")) {
                    viewModel.requestTranslationFromInput()
                }
                .keyboardShortcut(.return, modifiers: [])
                .buttonStyle(.plain)
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(.white)
                .padding(.horizontal, 16)
                .padding(.vertical, 7)
                .background(
                    Capsule(style: .continuous)
                        .fill(Color.accentColor.opacity(isHoveringTranslate ? 1 : 0.88))
                )
                .overlay {
                    Capsule(style: .continuous)
                        .strokeBorder(Color.white.opacity(isHoveringTranslate ? 0.35 : 0.16), lineWidth: 1)
                }
                .scaleEffect(isHoveringTranslate ? 1.04 : 1)
                .shadow(color: Color.accentColor.opacity(isHoveringTranslate ? 0.26 : 0.12), radius: isHoveringTranslate ? 9 : 4, y: isHoveringTranslate ? 3 : 1)
                .contentShape(Capsule(style: .continuous))
                .onHover { hovering in
                    withAnimation(.easeOut(duration: 0.12)) {
                        isHoveringTranslate = hovering
                    }
                }

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
        ScrollView(.vertical, showsIndicators: false) {
            VStack(alignment: .leading, spacing: 0) {
                if viewModel.isTranslating {
                    translatingResultState
                        .transition(.opacity.combined(with: .scale(scale: 0.98)))
                } else if viewModel.translatedText.isEmpty {
                    Text(settingsStore.text("翻译结果会显示在这里", "Translation results will appear here"))
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
                Text(settingsStore.text("正在生成译文", "Generating translation"))
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
                    text: settingsStore.text("复制译文", "Copy"),
                    systemImage: "doc.on.doc",
                    foregroundColor: isHoveringCopy ? .accentColor : .secondary
                )
                .opacity(showCopiedFeedback ? 0 : 1)

                copyButtonLabel(
                    text: settingsStore.text("已复制", "Copied"),
                    systemImage: "checkmark",
                    foregroundColor: .green
                )
                .opacity(showCopiedFeedback ? 1 : 0)
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(
                (showCopiedFeedback ? Color.green.opacity(0.12) : Color.accentColor.opacity(isHoveringCopy ? 0.14 : 0.04)),
                in: Capsule()
            )
            .overlay {
                Capsule(style: .continuous)
                    .strokeBorder(isHoveringCopy ? Color.accentColor.opacity(0.42) : Color.primary.opacity(0.06), lineWidth: 1)
            }
            .scaleEffect(isHoveringCopy ? 1.04 : 1)
            .shadow(color: isHoveringCopy ? Color.accentColor.opacity(0.16) : .clear, radius: 7, y: 2)
        }
        .buttonStyle(.plain)
        .contentShape(Capsule(style: .continuous))
        .onHover { hovering in
            withAnimation(.easeOut(duration: 0.12)) {
                isHoveringCopy = hovering
            }
        }
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
                    .font(.system(size: 9, weight: isHoveringSwapLanguages ? .semibold : .medium))
                    .foregroundStyle(isHoveringSwapLanguages ? Color.accentColor : .secondary)
                    .frame(width: 20, height: 20)
                    .background(
                        Circle()
                            .fill(isHoveringSwapLanguages ? Color.accentColor.opacity(0.13) : Color.clear)
                    )
                    .overlay {
                        Circle()
                            .strokeBorder(isHoveringSwapLanguages ? Color.accentColor.opacity(0.36) : Color.clear, lineWidth: 1)
                    }
                    .scaleEffect(isHoveringSwapLanguages ? 1.08 : 1)
            }
            .buttonStyle(.plain)
            .contentShape(Circle())
            .onHover { hovering in
                withAnimation(.easeOut(duration: 0.12)) {
                    isHoveringSwapLanguages = hovering
                }
            }
            .help(settingsStore.text("交换原文和翻译语言", "Swap source and target languages"))

            compactLanguageMenu(
                title: targetLanguageLabel,
                selection: settingsStore.targetLanguage
            ) { identifier in
                selectTargetLanguage(identifier)
            }
        }
        .padding(.horizontal, 5)
        .padding(.vertical, 2)
        .background(Color.black.opacity(0.035), in: Capsule())
        .overlay {
            Capsule(style: .continuous)
                .strokeBorder(Color.primary.opacity(0.05), lineWidth: 1)
        }
        .fixedSize()
        .help(settingsStore.text("仅在自动识别不准确时手动指定语言", "Specify languages manually when auto detection is inaccurate"))
    }

    private var sourceLanguageLabel: String {
        settingsStore.sourceLanguage == "auto"
            ? settingsStore.text("自动检测", "Auto")
            : TranslationLanguageOptions.title(for: settingsStore.sourceLanguage, in: settingsStore.displayLanguage)
    }

    private var targetLanguageLabel: String {
        settingsStore.targetLanguage == "auto"
            ? settingsStore.text("自动检测", "Auto")
            : TranslationLanguageOptions.title(for: settingsStore.targetLanguage, in: settingsStore.displayLanguage)
    }

    private func compactLanguageMenu(
        title: String,
        selection: String,
        onSelect: @escaping (String) -> Void
    ) -> some View {
        CompactLanguageMenuButton(
            title: title,
            selection: selection,
            displayLanguage: settingsStore.displayLanguage,
            onSelect: onSelect
        )
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
                        Text(settingsStore.text("正在下载 \(TranslationLanguageOptions.title(for: identifier, in: settingsStore.displayLanguage)) 语言包", "Downloading \(TranslationLanguageOptions.title(for: identifier, in: settingsStore.displayLanguage)) language pack"))
                            .font(.system(size: 12, weight: .medium))
                            .foregroundStyle(.primary)
                        Text(settingsStore.text("关闭系统下载窗口后，Transnap 会继续等待下载完成。", "After closing the system download window, Transnap will keep waiting for the download to finish."))
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
                        Text(settingsStore.text("语言包下载失败", "Language Pack Download Failed"))
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

private struct CompactLanguageMenuButton: View {
    let title: String
    let selection: String
    let displayLanguage: DisplayLanguage
    let onSelect: (String) -> Void

    @State private var isHovering = false

    var body: some View {
        Menu {
            ForEach(TranslationLanguageOptions.all) { option in
                Button {
                    onSelect(option.identifier)
                } label: {
                    if selection == option.identifier {
                        Label(option.title(in: displayLanguage), systemImage: "checkmark")
                    } else {
                        Text(option.title(in: displayLanguage))
                    }
                }
            }
        } label: {
            Text(title)
                .lineLimit(1)
                .font(.system(size: 10, weight: isHovering ? .semibold : .medium))
                .foregroundStyle(labelColor)
                .padding(.horizontal, 7)
                .padding(.vertical, 4)
                .background(
                    Capsule(style: .continuous)
                        .fill(isHovering ? Color.accentColor.opacity(0.13) : Color.clear)
                )
                .overlay {
                    Capsule(style: .continuous)
                        .strokeBorder(isHovering ? Color.accentColor.opacity(0.36) : Color.clear, lineWidth: 1)
                }
                .scaleEffect(isHovering ? 1.04 : 1)
        }
        .menuStyle(.borderlessButton)
        .buttonStyle(.plain)
        .contentShape(Capsule(style: .continuous))
        .onHover { hovering in
            withAnimation(.easeOut(duration: 0.12)) {
                isHovering = hovering
            }
        }
    }

    private var labelColor: Color {
        if isHovering {
            return .accentColor
        }

        return selection == "auto" ? .secondary : .primary.opacity(0.72)
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

private struct HeaderIconButton: View {
    let systemName: String
    let hoverTint: Color
    let action: () -> Void

    @State private var isHovering = false

    var body: some View {
        Button(action: action) {
            Image(systemName: systemName)
                .font(.system(size: 14, weight: isHovering ? .semibold : .medium))
                .foregroundStyle(isHovering ? hoverTint : .secondary)
                .frame(width: 28, height: 28)
                .background(backgroundShape)
                .overlay(borderShape)
                .scaleEffect(isHovering ? 1.08 : 1)
                .shadow(color: isHovering ? hoverTint.opacity(0.18) : .clear, radius: 7, y: 2)
        }
        .buttonStyle(.plain)
        .contentShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
        .onHover { hovering in
            withAnimation(.easeOut(duration: 0.12)) {
                isHovering = hovering
            }
        }
    }

    private var backgroundShape: some View {
        RoundedRectangle(cornerRadius: 8, style: .continuous)
            .fill(isHovering ? hoverTint.opacity(0.14) : Color.black.opacity(0.05))
    }

    private var borderShape: some View {
        RoundedRectangle(cornerRadius: 8, style: .continuous)
            .strokeBorder(isHovering ? hoverTint.opacity(0.42) : Color.clear, lineWidth: 1)
    }
}
