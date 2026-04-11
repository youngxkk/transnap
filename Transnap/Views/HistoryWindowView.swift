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
                        .padding(.vertical, 6)
                    }
                }
                .listStyle(.inset)
            }
        }
        .padding(.top, 8)
        .background(Color.white)
    }

    private func delete(_ record: TranslationRecord) {
        modelContext.delete(record)
        try? modelContext.save()
    }
}

private struct HistoryRowView: View {
    let record: TranslationRecord
    let onDelete: () -> Void
    @State private var isHoveringCopy = false

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("\(LanguageDirectionResolver.displayName(for: record.sourceLanguageIdentifier)) → \(LanguageDirectionResolver.displayName(for: record.targetLanguageIdentifier))")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Spacer()
                Text(record.createdAt, format: .dateTime.month().day().hour().minute())
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Text(record.sourceText)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .textSelection(.enabled)

            Text(record.translatedText)
                .font(.body)
                .textSelection(.enabled)

            HStack(spacing: 10) {
                Button(role: .destructive) {
                    onDelete()
                } label: {
                    Label("删除", systemImage: "trash")
                        .font(.caption)
                }
                .buttonStyle(.bordered)
                .controlSize(.small)

                Spacer()

                Button {
                    ClipboardService.copy(text: record.translatedText)
                } label: {
                    Label("复制译文", systemImage: "doc.on.doc")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(isHoveringCopy ? Color.black.opacity(0.05) : Color.clear, in: RoundedRectangle(cornerRadius: 6, style: .continuous))
                }
                .buttonStyle(.plain)
                .onHover { isHoveringCopy = $0 }
            }
        }
    }
}
