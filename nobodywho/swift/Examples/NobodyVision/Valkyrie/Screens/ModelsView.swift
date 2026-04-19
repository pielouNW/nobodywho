//
//  ModelsView.swift
//  Valkyrie
//

import SwiftData
import SwiftUI
import ValkyrieUI

struct ModelsView: View {
    private let endpoint = URL(string: "https://raw.githubusercontent.com/pielouNW/visionos-backend/refs/heads/main/backend.json")!

    @Environment(ModelStore.self) private var store
    @Environment(AppRouter.self) private var router
    @Query(sort: \DownloadedModel.name) private var downloadedModels: [DownloadedModel]

    @State private var remoteModels: [RemoteModel] = []
    @State private var isLoading = false
    @State private var errorMessage: String? = nil

    private var availableModels: [RemoteModel] {
        remoteModels.filter { !store.isDownloaded($0) && !store.isDownloading($0) }
    }

    var body: some View {
        NavigationStack {
            Group {
                if downloadedModels.isEmpty {
                    noDownloadedModelsView
                } else {
                    hasDownloadedModelsView
                }
            }
            .navigationTitle("Models")
        }
        .onAppear { fetchModels() }
    }

    // MARK: - No downloaded models

    private var noDownloadedModelsView: some View {
        Group {
            if isLoading || errorMessage != nil {
                VStack(spacing: 16) {
                    if let errorMessage {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .font(.title)
                            .foregroundStyle(.red)
                        Text(errorMessage)
                            .multilineTextAlignment(.center)
                            .foregroundStyle(.secondary)
                        Button { fetchModels() } label: {
                            Label("Retry", systemImage: "arrow.clockwise")
                        }
                        .buttonStyle(.bordered)
                    } else {
                        ProgressView()
                        Text("Loading models…")
                            .foregroundStyle(.secondary)
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if remoteModels.isEmpty {
                ContentUnavailableView("No Models", systemImage: "square.stack.3d.up.slash", description: Text("There are no models available to download."))
            } else {
                List {
                    downloadingSection
                    availableSection
                }
                .listStyle(.insetGrouped)
            }
        }
    }

    // MARK: - Has downloaded models

    private var hasDownloadedModelsView: some View {
        List {
            Section("Downloaded") {
                ForEach(downloadedModels) { model in
                    Button {
                        router.selectModel(model)
                        Task {
                            router.selectedTab = .chat
                        }
                    } label: {
                        ModelRow(name: model.name, author: model.author, sizeGB: model.sizeGB, tags: model.tags, isSelected: router.selectedChatModel?.id == model.id)
                    }
                    .buttonStyle(.plain)
                    .swipeActions(edge: .trailing) {
                        Button(role: .destructive) {
                            store.delete(model)
                            fetchModels()
                        } label: {
                            Label("Delete", systemImage: "trash")
                        }
                    }
                }
            }

            if isLoading {
                Section("To Download") {
                    ProgressView().frame(maxWidth: .infinity, alignment: .center)
                }
            } else if errorMessage != nil {
                Section("To Download") {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Cannot load the list of models right now.")
                            .foregroundStyle(.secondary)
                        Button { fetchModels() } label: {
                            Label("Retry", systemImage: "arrow.clockwise")
                        }
                        .buttonStyle(.borderless)
                        .padding(.top, 6)
                    }
                    .padding(.vertical, 4)
                }
            } else {
                downloadingSection
                availableSection
            }
        }
        .listStyle(.insetGrouped)
    }

    // MARK: - Reusable sections

    @ViewBuilder
    private var downloadingSection: some View {
        let downloading = remoteModels.filter { store.isDownloading($0) }
        if !downloading.isEmpty {
            Section("Downloading") {
                ForEach(downloading) { model in
                    RemoteModelRow(name: model.name, author: model.author, sizeGB: model.sizeGB, tags: model.tags, downloadProgress: store.downloadProgress[model.id] ?? 0)
                }
            }
        }
    }

    @ViewBuilder
    private var availableSection: some View {
        if !availableModels.isEmpty {
            Section("To Download") {
                ForEach(availableModels) { model in
                    Button { store.download(model) } label: {
                        RemoteModelRow(name: model.name, author: model.author, sizeGB: model.sizeGB, tags: model.tags, showDownloadIcon: true)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    // MARK: - Fetch

    private func fetchModels() {
        isLoading = true
        errorMessage = nil
        Task {
            do {
                let (data, _) = try await URLSession.shared.data(from: endpoint)
                let decoded = try JSONDecoder().decode([RemoteModel].self, from: data)
                await MainActor.run {
                    remoteModels = decoded
                    isLoading = false
                }
            } catch {
                await MainActor.run {
                    errorMessage = "Models could not be loaded. Try again later."
                    isLoading = false
                }
            }
        }
    }
}
