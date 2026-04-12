//
//  ValkyrieApp.swift
//  Valkyrie
//

import SwiftData
import SwiftUI

@main
struct ValkyrieApp: App {
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
