//
//  HistoryWindowView.swift
//  Transnap
//
//  Created by Codex on 2026/4/11.
//

import SwiftData
import SwiftUI

struct HistoryWindowView: View {
    @Query(sort: \TranslationRecord.createdAt, order: .reverse) private var history: [TranslationRecord]
    @Environment(\.modelContext) private var modelContext

    var body: some View {
        Group {
            if history.isEmpty {
                ContentUnavailableView("还没有翻译记录", systemImage: "clock")
            } else {
                List {
                    ForEach(history) { record in
                        HistoryRowView(record: record) {
                            delete(record)
                        }
                        .listRowInsets(EdgeInsets(top: 6, leading: 2, bottom: 6, trailing: 2))
                        .listRowSeparator(.hidden)
                    }
                }
                .listStyle(.inset)
                .scrollContentBackground(.hidden)
            }
        }
        .padding(.top, 8)
        .background(Color(nsColor: .windowBackgroundColor))
    }

    private func delete(_ record: TranslationRecord) {
        modelContext.delete(record)
        try? modelContext.save()
    }
}

private struct HistoryRowView: View {
    let record: TranslationRecord
    let onDelete: () -> Void
    @State private var isHovering = false
    @State private var highlightedField: HistoryCopiedField?
    @State private var clearHighlightTask: Task<Void, Never>?

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(record.translatedText)
                .font(.body)
                .foregroundStyle(.primary)
                .lineLimit(3)
                .textSelection(.enabled)
                .historyCopyHighlight(isActive: highlightedField == .translation)

            Text(record.sourceText)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .lineLimit(2)
                .textSelection(.enabled)
                .historyCopyHighlight(isActive: highlightedField == .source)

            HStack(spacing: 10) {
                Text(languageDirectionText)
                    .font(.caption)
                    .foregroundStyle(.tertiary)
                    .lineLimit(1)

                Spacer(minLength: 12)

                Text(record.createdAt, format: .dateTime.month().day().hour().minute())
                    .font(.caption)
                    .foregroundStyle(.tertiary)
                    .opacity(isHovering ? 0 : 1)
                    .overlay(alignment: .trailing) {
                        hoverActions
                    }
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(isHovering ? Color.primary.opacity(0.05) : Color(nsColor: .controlBackgroundColor).opacity(0.32))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .stroke(Color.primary.opacity(isHovering ? 0.08 : 0.03), lineWidth: 0.5)
        )
        .contentShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        .contextMenu {
            Button("复制原文", systemImage: "doc.on.doc") {
                copy(.source)
            }

            Button("复制译文", systemImage: "doc.on.doc") {
                copy(.translation)
            }

            Divider()

            Button("删除", systemImage: "trash", role: .destructive) {
                onDelete()
            }
        }
        .onHover { isHovering = $0 }
        .onDisappear {
            clearHighlightTask?.cancel()
        }
    }

    private var languageDirectionText: String {
        "\(LanguageDirectionResolver.displayName(for: record.sourceLanguageIdentifier)) → \(LanguageDirectionResolver.displayName(for: record.targetLanguageIdentifier))"
    }

    @ViewBuilder
    private var hoverActions: some View {
        HStack(spacing: 4) {
            hoverActionButton(
                title: "复制译文",
                systemImage: "character.textbox",
                showsPopoverHint: true
            ) {
                copy(.translation)
            }

            hoverActionButton(
                title: "复制原文",
                systemImage: "text.quote",
                showsPopoverHint: true
            ) {
                copy(.source)
            }

            hoverActionButton(
                title: "删除",
                systemImage: "trash",
                role: .destructive,
                action: onDelete
            )
        }
        .padding(4)
        .background(.regularMaterial, in: Capsule(style: .continuous))
        .opacity(isHovering ? 1 : 0)
        .allowsHitTesting(isHovering)
        .animation(.easeInOut(duration: 0.16), value: isHovering)
    }

    private func hoverActionButton(
        title: String,
        systemImage: String,
        role: ButtonRole? = nil,
        showsPopoverHint: Bool = false,
        action: @escaping () -> Void
    ) -> some View {
        HistoryActionButton(
            title: title,
            systemImage: systemImage,
            role: role,
            showsPopoverHint: showsPopoverHint,
            action: action
        )
    }

    private func copy(_ field: HistoryCopiedField) {
        ClipboardService.copy(text: copiedText(for: field))

        clearHighlightTask?.cancel()
        withAnimation(.easeOut(duration: 0.15)) {
            highlightedField = field
        }

        clearHighlightTask = Task { @MainActor in
            try? await Task.sleep(for: .seconds(1.2))
            guard !Task.isCancelled, highlightedField == field else { return }
            withAnimation(.easeOut(duration: 0.2)) {
                highlightedField = nil
            }
        }
    }

    private func copiedText(for field: HistoryCopiedField) -> String {
        switch field {
        case .translation:
            record.translatedText
        case .source:
            record.sourceText
        }
    }
}

private struct HistoryActionButton: View {
    let title: String
    let systemImage: String
    let role: ButtonRole?
    let showsPopoverHint: Bool
    let action: () -> Void

    @State private var isPointerInside = false

    var body: some View {
        Button(role: role, action: action) {
            Image(systemName: systemImage)
                .font(.system(size: 11, weight: .semibold))
                .frame(width: 24, height: 24)
        }
        .buttonStyle(.plain)
        .foregroundStyle(role == .destructive ? .red : .secondary)
        .help(title)
        .onHover { hovering in
            isPointerInside = hovering
        }
        .overlay(alignment: .top) {
            if showsPopoverHint && isPointerInside {
                HistoryActionTooltip(title: title)
                    .offset(y: -34)
                    .transition(.opacity.combined(with: .scale(scale: 0.96, anchor: .bottom)))
                    .allowsHitTesting(false)
                    .zIndex(1)
            }
        }
        .animation(.easeOut(duration: 0.12), value: isPointerInside)
    }
}

private struct HistoryActionTooltip: View {
    let title: String

    var body: some View {
        VStack(spacing: 0) {
            Text(title)
                .font(.caption)
                .foregroundStyle(.primary)
                .padding(.horizontal, 8)
                .padding(.vertical, 5)
                .background(.regularMaterial, in: Capsule(style: .continuous))
                .overlay {
                    Capsule(style: .continuous)
                        .stroke(Color.primary.opacity(0.08), lineWidth: 0.5)
                }

            Image(systemName: "arrowtriangle.down.fill")
                .font(.system(size: 8))
                .foregroundStyle(Color(nsColor: .separatorColor))
                .offset(y: -1)
        }
        .fixedSize()
        .shadow(color: Color.black.opacity(0.08), radius: 8, y: 2)
    }
}

private enum HistoryCopiedField {
    case translation
    case source
}

private struct HistoryCopyHighlightModifier: ViewModifier {
    let isActive: Bool

    func body(content: Content) -> some View {
        content
            .background {
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill(Color.accentColor.opacity(0.12))
                    .padding(.horizontal, -6)
                    .padding(.vertical, -4)
                    .opacity(isActive ? 1 : 0)
            }
            .overlay {
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .stroke(Color.accentColor.opacity(0.28), lineWidth: 1)
                    .padding(.horizontal, -6)
                    .padding(.vertical, -4)
                    .opacity(isActive ? 1 : 0)
            }
            .animation(.easeOut(duration: 0.18), value: isActive)
    }
}

private extension View {
    func historyCopyHighlight(isActive: Bool) -> some View {
        modifier(HistoryCopyHighlightModifier(isActive: isActive))
    }
}
