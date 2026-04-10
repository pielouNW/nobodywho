//
//  ModelStore.swift
//  NobodyWatch Watch App
//

import Foundation
import SwiftData
import SwiftUI

@Observable
class ModelStore {
    var downloadProgress: [Int: Double] = [:]

    private var modelContext: ModelContext
    private var activeTasks: [Int: URLSessionDownloadTask] = [:]

    init(modelContext: ModelContext) {
        self.modelContext = modelContext
    }

    func downloadedModels() -> [DownloadedModel] {
        let descriptor = FetchDescriptor<DownloadedModel>(sortBy: [SortDescriptor(\.name)])
        return (try? modelContext.fetch(descriptor)) ?? []
    }

    func isDownloaded(_ remoteModel: RemoteModel) -> Bool {
        let remoteId = remoteModel.id
        let descriptor = FetchDescriptor<DownloadedModel>(predicate: #Predicate { $0.remoteId == remoteId })
        return ((try? modelContext.fetch(descriptor))?.isEmpty == false)
    }

    func isDownloading(_ remoteModel: RemoteModel) -> Bool {
        downloadProgress[remoteModel.id] != nil
    }

    func download(_ remoteModel: RemoteModel) {
        guard !isDownloaded(remoteModel), !isDownloading(remoteModel) else { return }

        downloadProgress[remoteModel.id] = 0.0

        let task = URLSession.shared.downloadTask(with: remoteModel.downloadURL) { [weak self] tempURL, _, error in
            Task { @MainActor in
                guard let self else { return }
                defer { self.downloadProgress.removeValue(forKey: remoteModel.id) }

                guard let tempURL, error == nil else { return }

                let documentsDir = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
                let destinationURL = documentsDir.appendingPathComponent(remoteModel.fileName)

                do {
                    if FileManager.default.fileExists(atPath: destinationURL.path) {
                        try FileManager.default.removeItem(at: destinationURL)
                    }
                    try FileManager.default.moveItem(at: tempURL, to: destinationURL)

                    let downloaded = DownloadedModel(
                        remoteId: remoteModel.id,
                        name: remoteModel.name,
                        author: remoteModel.author,
                        sizeMB: remoteModel.sizeMB,
                        fileName: remoteModel.fileName,
                        filePath: destinationURL.path
                    )
                    self.modelContext.insert(downloaded)
                    try self.modelContext.save()
                } catch {
                    print("Failed to save downloaded model: \(error)")
                }
            }
        }

        // Observe progress
        let remoteId = remoteModel.id
        let observation = task.progress.observe(\.fractionCompleted) { [weak self] progress, _ in
            Task { @MainActor in
                self?.downloadProgress[remoteId] = progress.fractionCompleted
            }
        }
        // Keep observation alive by storing in task — we rely on task lifetime
        objc_setAssociatedObject(task, "progressObservation", observation, .OBJC_ASSOCIATION_RETAIN)

        activeTasks[remoteModel.id] = task
        task.resume()
    }
}
