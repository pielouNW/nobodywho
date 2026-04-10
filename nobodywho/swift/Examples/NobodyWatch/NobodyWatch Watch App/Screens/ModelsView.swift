//
//  ModelsView.swift
//  NobodyWatch Watch App
//

import NobodyWatchUI
import SwiftUI

struct ModelsView: View {
    private let endpoint = URL(string: "https://gist.githubusercontent.com/PierreBresson/f3da1a01c39417237fa2883fb11fe376/raw/6859398979565e0e474bd1858b0cc066cb7364fd/nobody-watchos-app.json")!

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
                    NavigationLink(destination: ModelLoadingView(modelPath: model.filePath)) {
                        ModelRow(name: model.name, author: model.author, modelSizeMB: model.sizeMB)
                    }
                }
            } header: {
                Text("Downloaded")
                    .padding(.bottom, 4)
            }

            if !availableModels.isEmpty || !remoteModels.filter({ store.isDownloading($0) }).isEmpty || errorMessage != nil || isLoading {
                Section {
                    if isLoading {
                        ProgressView()
                            .frame(maxWidth: .infinity, alignment: .center)
                    } else if errorMessage != nil {
                        Text("Cannot get the list of models at the moment.")
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
                    } else {
                        ForEach(remoteModels.filter { store.isDownloading($0) }) { model in
                            ModelRow(name: model.name, author: model.author, modelSizeMB: model.sizeMB, downloadProgress: store.downloadProgress[model.id] ?? 0)
                        }
                        ForEach(availableModels) { model in
                            Button {
                                store.download(model)
                            } label: {
                                ModelRow(name: model.name, author: model.author, modelSizeMB: model.sizeMB, showDownloadIcon: true)
                            }
                        }
                    }
                } header: {
                    Text("Models to download")
                        .padding(.bottom, 4)
                }
            }
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
            Section("Available") {
                ForEach(availableModels) { model in
                    Button {
                        store.download(model)
                    } label: {
                        ModelRow(name: model.name, author: model.author, modelSizeMB: model.sizeMB, showDownloadIcon: true)
                    }
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
