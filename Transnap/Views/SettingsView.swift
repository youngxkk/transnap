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

    var body: some View {
        Form {
            Section("翻译方向") {
                Picker("目标语言", selection: $settingsStore.preferredTargetLanguage) {
                    ForEach(PreferredTargetLanguage.allCases) { option in
                        Text(option.title).tag(option)
                    }
                }
                .pickerStyle(.menu)
            }

            Section("快捷键") {
                HStack {
                    Text("打开翻译面板")
                    Spacer()
                    ShortcutRecorderView(settingsStore: settingsStore)
                        .frame(width: 150, height: 32)
                }

                Text("当前快捷键：\(settingsStore.shortcutDisplayString)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .formStyle(.grouped)
        .padding(16)
        .background(Color.white)
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
