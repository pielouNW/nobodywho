//
//  ModelsView.swift
//  NobodyWatch Watch App
//

import NobodyWatchUI
import SwiftData
import SwiftUI

struct ModelsView: View {
    private let endpoint = URL(string: "https://gist.githubusercontent.com/PierreBresson/f3da1a01c39417237fa2883fb11fe376/raw/6859398979565e0e474bd1858b0cc066cb7364fd/nobody-watchos-app.json")!

    @Environment(\.modelContext) private var modelContext
    @State private var remoteModels: [RemoteModel] = []
    @State private var isLoading = false
    @State private var errorMessage: String? = nil
    @State private var store: ModelStore?

    private var downloadedModels: [DownloadedModel] {
        store?.downloadedModels() ?? []
    }

    private var availableModels: [RemoteModel] {
        guard let store else { return remoteModels }
        return remoteModels.filter { !store.isDownloaded($0) && !store.isDownloading($0) }
    }

    var body: some View {
        Group {
            if isLoading || errorMessage != nil {
                LoadingView(
                    hasError: errorMessage != nil,
                    errorMessage: errorMessage ?? "",
                    onRetry: fetchModels
                )
            } else if remoteModels.isEmpty && downloadedModels.isEmpty {
                Text("There are no models to download.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            } else {
                List {
                    if !downloadedModels.isEmpty {
                        Section("Downloaded") {
                            ForEach(downloadedModels) { model in
                                NavigationLink(destination: MainView()) {
                                    ModelRow(name: model.name, author: model.author, modelSizeMB: model.sizeMB)
                                }
                            }
                        }
                    }

                    if let store {
                        let downloading = remoteModels.filter { store.isDownloading($0) }
                        if !downloading.isEmpty {
                            Section("Downloading") {
                                ForEach(downloading) { model in
                                    ModelRow(name: model.name, author: model.author, modelSizeMB: model.sizeMB, downloadProgress: store.downloadProgress[model.id] ?? 0)
                                }
                            }
                        }
                    }

                    if !availableModels.isEmpty {
                        Section("Available") {
                            ForEach(availableModels) { model in
                                Button {
                                    store?.download(model)
                                } label: {
                                    ModelRow(name: model.name, author: model.author, modelSizeMB: model.sizeMB, showDownloadIcon: true)
                                }
                            }
                        }
                    }
                }
                .listStyle(.plain)
            }
        }
        .navigationTitle("Models")
        .onAppear {
            if store == nil {
                store = ModelStore(modelContext: modelContext)
            }
            fetchModels()
        }
    }

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

// #Preview("ModelsView") {
//    ModelsView()
//        .modelContainer(for: DownloadedModel.self, inMemory: true)
// }
