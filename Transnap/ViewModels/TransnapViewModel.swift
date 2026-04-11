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

@MainActor
final class TransnapViewModel: ObservableObject {
    @Published var translationConfiguration: TranslationSession.Configuration?
    @Published var inputText = ""
    @Published var translatedText = ""
    @Published var sourceText = ""
    @Published var statusMessage = "点击状态栏图标即可翻译剪贴板"
    @Published var isTranslating = false
    @Published var menuBarSubtitle = ""
    @Published var lastErrorMessage: String?
    private var pendingRequest: PendingTranslationRequest?
    private var clearSubtitleTask: Task<Void, Never>?
    private let modelContext: ModelContext
    private let settingsStore: SettingsStore

    init(modelContext: ModelContext, settingsStore: SettingsStore) {
        self.modelContext = modelContext
        self.settingsStore = settingsStore
    }

    func handleMenuOpened() {
        syncInputFromClipboard()
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

    func requestQuickClipboardTranslation() {
        guard let clipboardText = ClipboardService.currentText() else {
            statusMessage = "剪贴板里没有可翻译的文本"
            lastErrorMessage = "当前剪贴板不是文本，已忽略。"
            return
        }

        inputText = clipboardText
        queueTranslation(for: clipboardText, trigger: .doubleCopy)
    }

    func copyTranslatedText() {
        let trimmed = translatedText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }

        ClipboardService.copy(text: trimmed)
        statusMessage = "译文已复制"
        lastErrorMessage = nil
    }

    func performTranslation(using session: TranslationSession) async {
        guard let request = pendingRequest else { return }

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

            sourceText = response.sourceText
            translatedText = response.targetText
            statusMessage = "\(LanguageDirectionResolver.displayName(for: record.sourceLanguageIdentifier)) → \(LanguageDirectionResolver.displayName(for: record.targetLanguageIdentifier))"
            lastErrorMessage = nil

            if request.trigger == .doubleCopy {
                showMenuBarSubtitle(response.targetText)
            }
        } catch {
            translatedText = ""
            sourceText = request.text
            statusMessage = "翻译失败"
            lastErrorMessage = error.localizedDescription
        }

        pendingRequest = nil
        isTranslating = false
        translationConfiguration = nil
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

        translationConfiguration = nil
        let configuration = TranslationSession.Configuration(
            source: direction.source,
            target: direction.target
        )

        Task { @MainActor [weak self] in
            self?.translationConfiguration = configuration
        }
    }

    private func showMenuBarSubtitle(_ text: String) {
        clearSubtitleTask?.cancel()
        menuBarSubtitle = String(text.prefix(18))

        clearSubtitleTask = Task { @MainActor [weak self] in
            try? await Task.sleep(for: .seconds(8))
            self?.menuBarSubtitle = ""
        }
    }
}

private struct PendingTranslationRequest {
    let text: String
    let trigger: TranslationTrigger
    let detectedSourceIdentifier: String
    let targetIdentifier: String
}
