//
//  MenuBarRootView.swift
//  Transnap
//
//  Created by Codex on 2026/4/10.
//

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
        VStack(alignment: .leading, spacing: 20) {
            header
            featureList
            privacyNotice

            Spacer(minLength: 0)

            Button("开始使用") {
                settingsStore.hasCompletedWelcomeFlow = true
                viewModel.handleMenuOpened()
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
            .frame(maxWidth: .infinity, alignment: .trailing)
        }
        .padding(20)
        .background(PanelBackgroundView())
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .center, spacing: 14) {
                ZStack {
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .fill(.linearGradient(
                            colors: [Color.accentColor.opacity(0.92), Color.accentColor.opacity(0.68)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ))
                        .frame(width: 58, height: 58)

                    Image(systemName: "translate")
                        .font(.system(size: 26, weight: .semibold))
                        .foregroundStyle(.white)
                }

                VStack(alignment: .leading, spacing: 4) {
                    Text("欢迎使用 Transnap")
                        .font(.system(size: 24, weight: .semibold))

                    Text("更快开始，更少打断。")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
            }

            Text("首次使用前，先了解两件事。")
                .font(.system(size: 13))
                .foregroundStyle(.secondary)
        }
    }

    private var featureList: some View {
        VStack(spacing: 0) {
            welcomeRow(
                symbol: "doc.on.clipboard",
                tint: .blue,
                title: "读取当前剪贴板文本",
                message: "打开面板时会读取剪贴板中的文本，方便你直接开始翻译。"
            )

            Divider()
                .padding(.leading, 48)

            welcomeRow(
                symbol: "lock.shield",
                tint: .green,
                title: "仅本地翻译与本地存储",
                message: "翻译过程和历史记录都保留在这台 Mac 上，不会上传到服务器。"
            )

            Divider()
                .padding(.leading, 48)

            welcomeRow(
                symbol: "sparkles",
                tint: .orange,
                title: "随时从状态栏开始",
                message: "点按状态栏图标即可翻译，也可以继续使用快捷键和历史记录。"
            )
        }
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .strokeBorder(Color.primary.opacity(0.06), lineWidth: 0.5)
        }
    }

    private var privacyNotice: some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: "checkmark.seal")
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(.secondary)
                .padding(.top, 1)

            Text("开始使用后，你仍可在“设置”里查看权限状态、管理历史记录和调整快捷方式。")
                .font(.system(size: 12))
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
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
        .padding(.vertical, 14)
    }
}

@available(macOS 15.0, *)
private struct TranslatorPanelView: View {
    @Environment(\.colorScheme) private var colorScheme
    @ObservedObject var viewModel: TransnapViewModel
    @ObservedObject var settingsStore: SettingsStore
    let windowCoordinator: WindowCoordinator
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
                actionRow
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
        .translationTask(viewModel.translationConfiguration) { session in
            await viewModel.performTranslation(using: session)
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

    private var actionRow: some View {
        HStack {
            Button("翻译") {
                viewModel.requestTranslationFromInput()
            }
            .keyboardShortcut(.return, modifiers: [])
            .buttonStyle(.borderedProminent)
            .buttonBorderShape(.capsule)
            .controlSize(.regular)

            Spacer()

            if !viewModel.translatedText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                copyFloatingButton
                    .transition(.opacity.combined(with: .scale(scale: 0.92)))
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
