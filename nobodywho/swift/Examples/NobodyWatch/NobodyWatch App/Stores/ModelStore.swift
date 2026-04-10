//
//  ModelStore.swift
//  NobodyWatch Watch App
//

import Foundation
import SwiftData
import SwiftUI

@Observable
class ModelStore: NSObject {
    var downloadProgress: [Int: Double] = [:]

    /// Called by the system when all background events have been delivered.
    /// Must be invoked to let the system know we're done processing.
    var backgroundCompletionHandler: (() -> Void)?

    private var modelContext: ModelContext

    /// Maps URLSessionTask.taskIdentifier → RemoteModel metadata needed on completion.
    private var pendingDownloads: [Int: RemoteModel] = [:]

    /// UserDefaults key for persisting pending download metadata across app relaunches.
    private static let pendingDownloadsKey = "pendingDownloads"

    @ObservationIgnored
    private lazy var backgroundSession: URLSession = {
        let config = URLSessionConfiguration.background(withIdentifier: "com.nobodywho.NobodyWatch.model-download")
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

    func download(_ remoteModel: RemoteModel) {
        guard !isDownloaded(remoteModel), !isDownloading(remoteModel) else { return }

        downloadProgress[remoteModel.id] = 0.0

        let task = backgroundSession.downloadTask(with: remoteModel.downloadURL)
        task.taskDescription = String(remoteModel.id)
        pendingDownloads[task.taskIdentifier] = remoteModel
        savePendingDownloads()
        task.resume()
    }

    // MARK: - Persistence for pending downloads

    /// Persist pending download metadata to UserDefaults so we can recover after app relaunch.
    private func savePendingDownloads() {
        let entries = pendingDownloads.map { (taskId, model) in
            PendingDownloadEntry(taskIdentifier: taskId, remoteModel: model)
        }
        if let data = try? JSONEncoder().encode(entries) {
            UserDefaults.standard.set(data, forKey: Self.pendingDownloadsKey)
        }
    }

    /// Restore pending download metadata from UserDefaults.
    private func loadPendingDownloads() -> [Int: RemoteModel] {
        guard let data = UserDefaults.standard.data(forKey: Self.pendingDownloadsKey),
              let entries = try? JSONDecoder().decode([PendingDownloadEntry].self, from: data) else {
            return [:]
        }
        return Dictionary(uniqueKeysWithValues: entries.map { ($0.taskIdentifier, $0.remoteModel) })
    }

    /// On app relaunch, reconnect to any in-progress background downloads.
    private func reconnectToActiveDownloads() {
        let restored = loadPendingDownloads()

        backgroundSession.getAllTasks { [weak self] tasks in
            Task { @MainActor in
                guard let self else { return }
                for task in tasks where task.state == .running || task.state == .suspended {
                    if let idString = task.taskDescription, let remoteId = Int(idString) {
                        self.downloadProgress[remoteId] = task.progress.fractionCompleted

                        // Restore in-memory metadata from persisted data
                        if let model = restored[task.taskIdentifier] {
                            self.pendingDownloads[task.taskIdentifier] = model
                        }
                    }
                }
            }
        }
    }

    /// Resolve a RemoteModel from the in-memory pending downloads map.
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
    func urlSession(_ session: URLSession, downloadTask: URLSessionDownloadTask, didFinishDownloadingTo location: URL) {
        // Called on a background queue. Move file immediately — temp file is deleted after this method returns.
        guard let remoteModel = remoteModel(for: downloadTask) else { return }

        let documentsDir = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
        let destinationURL = documentsDir.appendingPathComponent(remoteModel.fileName)

        do {
            if FileManager.default.fileExists(atPath: destinationURL.path) {
                try FileManager.default.removeItem(at: destinationURL)
            }
            try FileManager.default.moveItem(at: location, to: destinationURL)
        } catch {
            print("Failed to move downloaded file: \(error)")
        }
    }

    func urlSession(_ session: URLSession, task: URLSessionTask, didCompleteWithError error: (any Error)?) {
        guard let remoteModel = remoteModel(for: task) else { return }

        let documentsDir = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
        let destinationURL = documentsDir.appendingPathComponent(remoteModel.fileName)

        Task { @MainActor in
            if let error {
                print("Download failed for \(remoteModel.name): \(error.localizedDescription)")
                // Clean up any partially downloaded file
                try? FileManager.default.removeItem(at: destinationURL)
            } else {
                // File was already moved in didFinishDownloadingTo. Now save to SwiftData.
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
                    // SwiftData save failed — remove the orphaned file
                    try? FileManager.default.removeItem(at: destinationURL)
                }
            }

            self.cleanupTask(task, remoteId: remoteModel.id)
        }
    }

    func urlSession(_ session: URLSession, downloadTask: URLSessionDownloadTask, didWriteData bytesWritten: Int64, totalBytesWritten: Int64, totalBytesExpectedToWrite: Int64) {
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
    /// Called from the app when the system delivers background session events.
    func handleBackgroundSessionEvents() {
        backgroundCompletionHandler?()
        backgroundCompletionHandler = nil
    }
}

// MARK: - Codable helper for persisting pending downloads

private struct PendingDownloadEntry: Codable {
    let taskIdentifier: Int
    let remoteModel: RemoteModel
}
