//
//  ModelsView.swift
//  NobodyWatch Watch App
//

import ValkyrieUI
import SwiftUI

struct ModelsView: View {
    private let endpoint = URL(string: "https://raw.githubusercontent.com/pielouNW/watchos-backend/refs/heads/main/backend.json")!

    var store: ModelStore

    @State private var remoteModels: [RemoteModel] = []
    @State private var isLoading = false
    @State private var errorMessage: String? = nil

    private var downloadedModels: [DownloadedModel] {
        store.downloadedModels()
    }

    private var availableModels: [RemoteModel] {
        return remoteModels.filter { !store.isDownloaded($0) && !store.isDownloading($0) }
    }

    var body: some View {
        Group {
            if downloadedModels.isEmpty {
                noDownloadedModelsView
            } else {
                hasDownloadedModelsView
            }
        }
        .navigationTitle("Models")
        .onAppear {
            fetchModels()
        }
    }

    // MARK: - No downloaded models: full-screen loading / error / list

    private var noDownloadedModelsView: some View {
        Group {
            if isLoading || errorMessage != nil {
                LoadingView(
                    hasError: errorMessage != nil,
                    errorMessage: errorMessage ?? "",
                    onRetry: fetchModels
                )
            } else if remoteModels.isEmpty {
                Text("There are no models to download.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            } else {
                List {
                    downloadingSection
                    availableSection
                    infoButton
                }
                .listStyle(.plain)
            }
        }
    }

    // MARK: - Has downloaded models: always show them, remote list below

    private var hasDownloadedModelsView: some View {
        List {
            Section {
                ForEach(downloadedModels) { model in
                    NavigationLink(destination: ModelLoadingView(modelPath: model.filePath).id(model.fileName)) {
                        ModelRow(name: model.name, author: model.author, modelSizeMB: model.sizeMB)
                    }
                    .swipeActions(edge: .trailing) {
                        Button(role: .destructive) {
                            if store.delete(model) {
                                fetchModels()
                            }
                        } label: {
                            Label("Delete", systemImage: "trash")
                        }
                    }
                }
            } header: {
                Text("Downloaded")
                    .padding(.bottom, 4)
            }

            if isLoading {
                Section {
                    ProgressView()
                        .frame(maxWidth: .infinity, alignment: .center)
                } header: {
                    Text("To download")
                        .padding(.bottom, 4)
                }
            } else if errorMessage != nil {
                Section {
                    Text("Cannot get the list of models to download at the moment.")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                        .listRowBackground(Color.clear)
                        .padding(.bottom, 4)
                    Button {
                        fetchModels()
                    } label: {
                        Label("Retry", systemImage: "arrow.clockwise")
                            .font(.caption2)
                    }
                } header: {
                    Text("To download")
                        .padding(.bottom, 4)
                }
            } else {
                if !remoteModels.filter({ store.isDownloading($0) }).isEmpty {
                    Section {
                        ForEach(remoteModels.filter { store.isDownloading($0) }) { model in
                            ModelRow(name: model.name, author: model.author, modelSizeMB: model.sizeMB, downloadProgress: store.downloadProgress[model.id] ?? 0)
                        }
                    } header: {
                        Text("Downloading")
                            .padding(.bottom, 4)
                    }
                }

                if !availableModels.isEmpty {
                    Section {
                        ForEach(availableModels) { model in
                            Button {
                                store.download(model)
                            } label: {
                                ModelRow(name: model.name, author: model.author, modelSizeMB: model.sizeMB, showDownloadIcon: true)
                            }
                        }
                    } header: {
                        Text("To download")
                            .padding(.bottom, 4)
                    }
                }
            }

            infoButton
        }
        .listStyle(.plain)
    }

    // MARK: - Reusable sections for the no-downloaded-models list

    @ViewBuilder
    private var downloadingSection: some View {
        let downloading = remoteModels.filter { store.isDownloading($0) }
        if !downloading.isEmpty {
            Section {
                ForEach(downloading) { model in
                    ModelRow(name: model.name, author: model.author, modelSizeMB: model.sizeMB, downloadProgress: store.downloadProgress[model.id] ?? 0)
                }
            } header: {
                Text("Downloading")
                    .padding(.bottom, 4)
            }
        }
    }

    @ViewBuilder
    private var availableSection: some View {
        if !availableModels.isEmpty {
            Section {
                ForEach(availableModels) { model in
                    Button {
                        store.download(model)
                    } label: {
                        ModelRow(name: model.name, author: model.author, modelSizeMB: model.sizeMB, showDownloadIcon: true)
                    }
                }
            } header: {
                Text("To download")
                    .padding(.bottom, 4)
            }
        }
    }

    private var infoButton: some View {
        NavigationLink(destination: InfoView()) {
            Label("Info", systemImage: "info.circle")
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
                    errorMessage = nil
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
