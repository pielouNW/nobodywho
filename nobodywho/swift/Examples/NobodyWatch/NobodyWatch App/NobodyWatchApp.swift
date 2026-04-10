//
//  NobodyWatchApp.swift
//  NobodyWatch Watch App
//
//  Created by pierre on 20/03/2026.
//

import SwiftData
import SwiftUI

@main
struct NobodyWatch: App {
    private let modelContainer: ModelContainer
    @State private var store: ModelStore

    init() {
        let container = try! ModelContainer(for: DownloadedModel.self)
        self.modelContainer = container
        self._store = State(initialValue: ModelStore(modelContext: container.mainContext))
    }

    var body: some Scene {
        WindowGroup {
            NavigationStack {
                ModelsView(store: store)
            }
        }
        .modelContainer(modelContainer)
    }
}
