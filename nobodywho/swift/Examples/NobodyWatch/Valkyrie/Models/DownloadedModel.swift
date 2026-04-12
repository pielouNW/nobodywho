//
//  DownloadedModel.swift
//  NobodyWatch Watch App
//

import Foundation
import SwiftData

@Model
final class DownloadedModel {
    @Attribute(.unique) var remoteId: Int
    var name: String
    var author: String
    var sizeMB: Int
    var fileName: String

    /// Full path to the model file, derived at runtime from the current documents directory.
    var filePath: String {
        let documentsDir = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
        return documentsDir.appendingPathComponent(fileName).path
    }

    init(remoteId: Int, name: String, author: String, sizeMB: Int, fileName: String) {
        self.remoteId = remoteId
        self.name = name
        self.author = author
        self.sizeMB = sizeMB
        self.fileName = fileName
    }
}
