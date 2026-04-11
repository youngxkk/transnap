//
//  ContentView.swift
//  Transnap
//
//  Created by Codex on 2026/4/10.
//

import SwiftData
import SwiftUI

struct ContentView: View {
    @Environment(\.modelContext) private var modelContext

    var body: some View {
        let settingsStore = SettingsStore()
        let viewModel = TransnapViewModel(modelContext: modelContext, settingsStore: settingsStore)
        let schema = Schema([TranslationRecord.self])
        let container = try? ModelContainer(for: schema, configurations: [ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)])

        return Group {
            if let container {
                MenuBarRootView(
                    viewModel: viewModel,
                    settingsStore: settingsStore,
                    windowCoordinator: WindowCoordinator(
                        viewModel: viewModel,
                        settingsStore: settingsStore,
                        modelContainer: container
                    )
                )
            } else {
                Text("Preview unavailable")
            }
        }
    }
}

#Preview {
    ContentView()
        .modelContainer(for: TranslationRecord.self, inMemory: true)
}
