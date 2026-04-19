//
//  ValkyrieApp.swift
//  Valkyrie
//
//  Created by Pierre Bresson on 17/04/2026.
//

import SwiftUI
import SwiftData

@main
struct ValkyrieApp: App {
    private let modelContainer: ModelContainer
    @State private var store: ModelStore
    @State private var router = AppRouter()

    init() {
        let appSupportURL = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        try? FileManager.default.createDirectory(at: appSupportURL, withIntermediateDirectories: true)

        let container = try! ModelContainer(for: DownloadedModel.self, Conversation.self, PersistedChatMessage.self)
        self.modelContainer = container
        self._store = State(initialValue: ModelStore(modelContext: container.mainContext))
    }

    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(store)
                .environment(router)
        }
        .modelContainer(modelContainer)
    }
}

private struct RootView: View {
    @Environment(AppRouter.self) private var router
    @Query(sort: \DownloadedModel.name) private var downloadedModels: [DownloadedModel]

    var body: some View {
        @Bindable var router = router
        TabView(selection: $router.selectedTab) {
            Tab("Models", systemImage: "sparkles", value: AppTab.models) {
                ModelsView()
            }
            if router.selectedChatModel != nil {
                Tab("Chat", systemImage: "message", value: AppTab.chat) {
                    ChatView()
                }
            }
        }
        .onAppear {
            router.restoreSelection(from: downloadedModels)
        }
        .onChange(of: downloadedModels) { _, models in
            if let selected = router.selectedChatModel,
               !models.contains(where: { $0.id == selected.id }) {
                router.clearSelectedModel()
            }
        }
    }
}
