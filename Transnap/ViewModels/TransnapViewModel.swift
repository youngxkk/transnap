//
//  TransnapViewModel.swift
//  Transnap
//
//  Created by Codex on 2026/4/10.
//

import Combine
import Foundation
import SwiftData
import SwiftUI
import Translation

@available(macOS 15.0, *)
@MainActor
final class TransnapViewModel: ObservableObject {
    @Published var translationConfiguration: TranslationSession.Configuration?
    @Published var inputText = ""
    @Published var translatedText = ""
    @Published var sourceText = ""
    @Published var statusMessage = "点击状态栏图标即可翻译剪贴板"
    @Published var isTranslating = false
    @Published var lastErrorMessage: String?
    @Published private(set) var copyFeedbackToken = 0
    private var pendingRequest: PendingTranslationRequest?
    private let modelContext: ModelContext
    private let settingsStore: SettingsStore

    init(modelContext: ModelContext, settingsStore: SettingsStore) {
        self.modelContext = modelContext
        self.settingsStore = settingsStore
    }

    func handleMenuOpened() {
        syncInputFromClipboard()
        requestAutomaticTranslationIfPossible()
    }

    func syncInputFromClipboard() {
        guard let clipboardText = ClipboardService.currentText() else {
            statusMessage = "把内容复制后，点翻译即可"
            lastErrorMessage = nil
            return
        }

        inputText = clipboardText
        sourceText = clipboardText
        statusMessage = "已填入剪贴板内容"
        lastErrorMessage = nil
    }

    func requestTranslationFromInput() {
        let trimmed = inputText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            statusMessage = "请输入要翻译的文本"
            lastErrorMessage = "输入框为空。"
            return
        }

        queueTranslation(for: trimmed, trigger: .manualInput)
    }

    func requestAutomaticTranslationIfPossible() {
        let trimmed = inputText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }

        queueTranslation(for: trimmed, trigger: .menuBarClick)
    }

    func copyTranslatedText() {
        let trimmed = translatedText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }

        ClipboardService.copy(text: trimmed)
        statusMessage = "译文已复制"
        lastErrorMessage = nil
        copyFeedbackToken += 1
    }

    func performTranslation(using session: TranslationSession) async {
        guard let request = pendingRequest else { return }
        pendingRequest = nil

        do {
            let response = try await session.translate(request.text)
            let record = TranslationRecord(
                sourceText: response.sourceText,
                translatedText: response.targetText,
                sourceLanguageIdentifier: request.detectedSourceIdentifier,
                targetLanguageIdentifier: request.targetIdentifier,
                trigger: request.trigger
            )

            modelContext.insert(record)
            try modelContext.save()
            try pruneHistoryIfNeeded()

            sourceText = response.sourceText
            translatedText = response.targetText
            statusMessage = "\(LanguageDirectionResolver.displayName(for: record.sourceLanguageIdentifier)) → \(LanguageDirectionResolver.displayName(for: record.targetLanguageIdentifier))"
            lastErrorMessage = nil
        } catch is CancellationError {
            lastErrorMessage = nil
        } catch {
            translatedText = ""
            sourceText = request.text
            statusMessage = "翻译失败: \(error.localizedDescription)"
            lastErrorMessage = error.localizedDescription
        }

        isTranslating = false
    }

    func delete(_ record: TranslationRecord) {
        modelContext.delete(record)
        do {
            try modelContext.save()
        } catch {
            lastErrorMessage = error.localizedDescription
        }
    }

    private func queueTranslation(for text: String, trigger: TranslationTrigger) {
        guard let direction = LanguageDirectionResolver.resolve(
            for: text,
            sourceLanguage: settingsStore.sourceLanguage,
            targetLanguage: settingsStore.targetLanguage,
            preferredTargetLanguage: settingsStore.preferredTargetLanguage
        ) else {
            statusMessage = "无法识别语言"
            lastErrorMessage = "系统未能识别文本语言。"
            return
        }

        pendingRequest = PendingTranslationRequest(
            text: text,
            trigger: trigger,
            detectedSourceIdentifier: direction.detectedSourceIdentifier,
            targetIdentifier: direction.targetIdentifier
        )

        sourceText = text
        translatedText = ""
        statusMessage = "翻译中..."
        isTranslating = true
        lastErrorMessage = nil

        let nextConfiguration = TranslationSession.Configuration(
            source: direction.source,
            target: direction.target
        )

        if var existingConfiguration = translationConfiguration,
           existingConfiguration == nextConfiguration {
            existingConfiguration.invalidate()
            translationConfiguration = existingConfiguration
        } else {
            translationConfiguration = nextConfiguration
        }
    }

    private func pruneHistoryIfNeeded() throws {
        let limit = max(settingsStore.historyLimit, 1)
        let descriptor = FetchDescriptor<TranslationRecord>(
            sortBy: [SortDescriptor(\TranslationRecord.createdAt, order: .reverse)]
        )
        let records = try modelContext.fetch(descriptor)
        guard records.count > limit else { return }

        for record in records.dropFirst(limit) {
            modelContext.delete(record)
        }

        try modelContext.save()
    }
}

private struct PendingTranslationRequest {
    let text: String
    let trigger: TranslationTrigger
    let detectedSourceIdentifier: String
    let targetIdentifier: String
}
