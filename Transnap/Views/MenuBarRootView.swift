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
        TranslatorPanelView(
            viewModel: viewModel,
            settingsStore: settingsStore,
            windowCoordinator: windowCoordinator
        )
        .frame(width: 360, height: settingsStore.menuBarPanelHeight)
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
    }
}

@available(macOS 15.0, *)
private struct TranslatorPanelView: View {
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
        let shape = RoundedRectangle(cornerRadius: 18, style: .continuous)

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

    private var header: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Label("Transnap", systemImage: "translate")
                    .font(.title3.weight(.semibold))

                if viewModel.isTranslating {
                    HStack(spacing: 6) {
                        ProgressView()
                            .controlSize(.small)
                        Text("翻译中")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
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
                .fill(.thinMaterial)
                .overlay {
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .strokeBorder(Color.primary.opacity(0.05), lineWidth: 0.5)
                }

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
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .strokeBorder(Color.primary.opacity(0.05), lineWidth: 0.5)
        }
    }

    private var translatingResultState: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 8) {
                ProgressView()
                    .controlSize(.small)
                Text("正在生成译文")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

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
            HStack(spacing: 6) {
                Image(systemName: showCopiedFeedback ? "checkmark" : "doc.on.doc")
                    .font(.system(size: 11, weight: .semibold))
                Text(showCopiedFeedback ? "已复制" : "复制译文")
                    .font(.caption.weight(.medium))
            }
            .foregroundStyle(showCopiedFeedback ? Color.green : Color.secondary)
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
