import Foundation
import SwiftData
import SwiftUI

@Observable
class ModelStore: NSObject {
    var downloadProgress: [Int: Double] = [:]

    var backgroundCompletionHandler: (() -> Void)?

    private var modelContext: ModelContext

    private var pendingDownloads: [Int: RemoteModel] = [:]

    private nonisolated static let pendingDownloadsKey = "pendingDownloads"

    @ObservationIgnored
    private lazy var backgroundSession: URLSession = {
        let config = URLSessionConfiguration.background(withIdentifier: "ai.nobodywho.watch.model-download")
        config.isDiscretionary = false
        config.sessionSendsLaunchEvents = true
        return URLSession(configuration: config, delegate: self, delegateQueue: nil)
    }()

    init(modelContext: ModelContext) {
        self.modelContext = modelContext
        super.init()
        reconnectToActiveDownloads()
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

    @discardableResult
    func delete(_ model: DownloadedModel) -> Bool {
        let filePath = model.filePath
        modelContext.delete(model)
        do {
            try modelContext.save()
            try? FileManager.default.removeItem(atPath: filePath)
            return true
        } catch {
            return false
        }
    }

    func download(_ remoteModel: RemoteModel) {
        guard !isDownloaded(remoteModel), !isDownloading(remoteModel) else { return }

        downloadProgress[remoteModel.id] = 0.0

        let task = backgroundSession.downloadTask(with: remoteModel.downloadURL)
        task.taskDescription = String(remoteModel.id)
        pendingDownloads[task.taskIdentifier] = remoteModel
        savePendingDownloads()
        task.resume()
    }

    private func savePendingDownloads() {
        let entries = pendingDownloads.map { taskId, model in
            PendingDownloadEntry(taskIdentifier: taskId, remoteModel: model)
        }
        if let data = try? JSONEncoder().encode(entries) {
            UserDefaults.standard.set(data, forKey: Self.pendingDownloadsKey)
        }
    }

    private func loadPendingDownloads() -> [Int: RemoteModel] {
        guard let data = UserDefaults.standard.data(forKey: Self.pendingDownloadsKey),
              let entries = try? JSONDecoder().decode([PendingDownloadEntry].self, from: data)
        else {
            return [:]
        }
        return Dictionary(uniqueKeysWithValues: entries.map { ($0.taskIdentifier, $0.remoteModel) })
    }

    private func reconnectToActiveDownloads() {
        let restored = loadPendingDownloads()

        backgroundSession.getAllTasks { [weak self] tasks in
            guard let self else { return }
            Task { @MainActor [self] in
                for task in tasks where task.state == .running || task.state == .suspended {
                    if let idString = task.taskDescription, let remoteId = Int(idString) {
                        self.downloadProgress[remoteId] = task.progress.fractionCompleted

                        if let model = restored[task.taskIdentifier] {
                            self.pendingDownloads[task.taskIdentifier] = model
                        }
                    }
                }
            }
        }
    }

    private func remoteModel(for task: URLSessionTask) -> RemoteModel? {
        if let model = pendingDownloads[task.taskIdentifier] {
            return model
        }
        print("Warning: could not find RemoteModel metadata for completed task \(task.taskIdentifier).")
        return nil
    }

    private func cleanupTask(_ task: URLSessionTask, remoteId: Int) {
        pendingDownloads.removeValue(forKey: task.taskIdentifier)
        downloadProgress.removeValue(forKey: remoteId)
        savePendingDownloads()
    }
}

// MARK: - URLSessionDownloadDelegate

extension ModelStore: URLSessionDownloadDelegate {
    nonisolated func urlSession(_ session: URLSession, downloadTask: URLSessionDownloadTask, didFinishDownloadingTo location: URL) {
        // Must move file synchronously — temp file is deleted after this method returns.
        // Read metadata from UserDefaults (thread-safe) since pendingDownloads is MainActor-isolated.
        guard let data = UserDefaults.standard.data(forKey: ModelStore.pendingDownloadsKey),
              let entries = try? JSONDecoder().decode([PendingDownloadEntry].self, from: data),
              let entry = entries.first(where: { $0.taskIdentifier == downloadTask.taskIdentifier })
        else {
            return
        }

        let documentsDir = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
        let destinationURL = documentsDir.appendingPathComponent(entry.remoteModel.fileName)

        do {
            if FileManager.default.fileExists(atPath: destinationURL.path) {
                try FileManager.default.removeItem(at: destinationURL)
            }
            try FileManager.default.moveItem(at: location, to: destinationURL)
        } catch {
            print("Failed to move downloaded file: \(error)")
        }
    }

    nonisolated func urlSession(_ session: URLSession, task: URLSessionTask, didCompleteWithError error: (any Error)?) {
        let taskRef = task
        Task { @MainActor in
            guard let remoteModel = self.remoteModel(for: taskRef) else { return }

            let documentsDir = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
            let destinationURL = documentsDir.appendingPathComponent(remoteModel.fileName)

            if let error {
                print("Download failed for \(remoteModel.name): \(error.localizedDescription)")
                try? FileManager.default.removeItem(at: destinationURL)
            } else {
                do {
                    let downloaded = DownloadedModel(
                        remoteId: remoteModel.id,
                        name: remoteModel.name,
                        author: remoteModel.author,
                        sizeMB: remoteModel.sizeMB,
                        fileName: remoteModel.fileName
                    )
                    self.modelContext.insert(downloaded)
                    try self.modelContext.save()
                } catch {
                    print("Failed to save downloaded model to database: \(error)")
                    try? FileManager.default.removeItem(at: destinationURL)
                }
            }

            self.cleanupTask(taskRef, remoteId: remoteModel.id)
        }
    }

    nonisolated func urlSession(_ session: URLSession, downloadTask: URLSessionDownloadTask, didWriteData bytesWritten: Int64, totalBytesWritten: Int64, totalBytesExpectedToWrite: Int64) {
        guard totalBytesExpectedToWrite > 0,
              let idString = downloadTask.taskDescription,
              let remoteId = Int(idString) else { return }

        let progress = Double(totalBytesWritten) / Double(totalBytesExpectedToWrite)

        Task { @MainActor in
            self.downloadProgress[remoteId] = progress
        }
    }
}

// MARK: - Background session completion

extension ModelStore {
    func handleBackgroundSessionEvents() {
        backgroundCompletionHandler?()
        backgroundCompletionHandler = nil
    }
}

private struct PendingDownloadEntry: Codable {
    let taskIdentifier: Int
    let remoteModel: RemoteModel
}
