//
//  MenuBarRootView.swift
//  Transnap
//
//  Created by Codex on 2026/4/10.
//

import SwiftUI
import Translation

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
        .translationTask(viewModel.translationConfiguration) { session in
            await viewModel.performTranslation(using: session)
        }
        .onAppear {
            viewModel.handleMenuOpened()
        }
    }
}

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
        .translationTask(viewModel.translationConfiguration) { session in
            await viewModel.performTranslation(using: session)
        }
        .onAppear {
            viewModel.handleMenuOpened()
        }
    }
}

private struct TranslatorPanelView: View {
    @ObservedObject var viewModel: TransnapViewModel
    @ObservedObject var settingsStore: SettingsStore
    let windowCoordinator: WindowCoordinator
    @State private var inputEditorHeight: CGFloat = 86
    @State private var dragStartPanelHeight: Double?
    private let resizeHotspotSize: CGFloat = 18
    @State private var isHoveringCopy: Bool = false

    var body: some View {
        ScrollView(.vertical, showsIndicators: true) {
            VStack(alignment: .leading, spacing: 14) {
                header
                inputSection
                actionRow
                resultSection
            }
            .padding(14)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .background(Color.white)
        .scrollBounceBehavior(.basedOnSize)
        .overlay(alignment: .bottomTrailing) {
            Color.clear
                .frame(width: resizeHotspotSize, height: resizeHotspotSize)
                .contentShape(Rectangle())
                .modifier(ResizeCursorModifier())
                .gesture(
                    DragGesture(minimumDistance: 2)
                        .onChanged { value in
                            if dragStartPanelHeight == nil {
                                dragStartPanelHeight = settingsStore.menuBarPanelHeight
                            }

                            let startHeight = dragStartPanelHeight ?? settingsStore.menuBarPanelHeight
                            let nextHeight = startHeight + value.translation.height
                            settingsStore.menuBarPanelHeight = nextHeight
                        }
                        .onEnded { _ in
                            dragStartPanelHeight = nil
                        }
                )
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
                .fill(Color.white)
                .overlay {
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .stroke(Color.black.opacity(0.08), lineWidth: 1)
                }

            AdaptiveTextEditor(
                text: $viewModel.inputText,
                dynamicHeight: $inputEditorHeight,
                minLines: 3,
                maxLines: 6
            )
            .padding(.horizontal, 8)
            .padding(.vertical, 6)
            .frame(height: inputEditorHeight)

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
        HStack(spacing: 10) {
            Button("翻译") {
                viewModel.requestTranslationFromInput()
            }
            .keyboardShortcut(.return, modifiers: [])
            .buttonStyle(.borderedProminent)
            .buttonBorderShape(.capsule)
            .controlSize(.regular)

            Spacer()

            Button {
                viewModel.copyTranslatedText()
            } label: {
                Label("复制译文", systemImage: "doc.on.doc")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(isHoveringCopy && !viewModel.translatedText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? Color.black.opacity(0.05) : Color.clear, in: RoundedRectangle(cornerRadius: 6, style: .continuous))
            }
            .buttonStyle(.plain)
            .onHover { isHoveringCopy = $0 }
            .disabled(viewModel.translatedText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            .opacity(viewModel.translatedText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? 0.5 : 1.0)
        }
    }

    private var resultSection: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                Text(viewModel.translatedText.isEmpty ? "翻译结果会显示在这里" : viewModel.translatedText)
                    .textSelection(.enabled)
                    .foregroundStyle(viewModel.translatedText.isEmpty ? .secondary : .primary)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .frame(minHeight: 120)
        .padding(12)
        .background(Color.white, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .stroke(Color.black.opacity(0.08), lineWidth: 1)
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
    static let shared: NSCursor = {
        let baseSize = CGSize(width: 18, height: 18)
        let image = NSImage(size: baseSize)
        image.lockFocus()

        let configuration = NSImage.SymbolConfiguration(pointSize: 14, weight: .regular)
        let symbol = NSImage(
            systemSymbolName: "arrow.up.left.and.arrow.down.right",
            accessibilityDescription: "Resize"
        )?.withSymbolConfiguration(configuration)

        symbol?.draw(
            in: NSRect(x: 1, y: 1, width: 16, height: 16),
            from: .zero,
            operation: .sourceOver,
            fraction: 1
        )

        image.unlockFocus()
        return NSCursor(image: image, hotSpot: NSPoint(x: 9, y: 9))
    }()
}
