//
//  DownloadedModel.swift
//  Valkyrie
//

import Foundation
import SwiftData

@Model
final class DownloadedModel {
    @Attribute(.unique) var remoteId: Int
    var name: String
    var author: String
    var sizeGB: Double
    var fileName: String
    var tags: [String]

    /// Full path to the model file, derived at runtime from the current documents directory.
    var filePath: String {
        let documentsDir = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
        return documentsDir.appendingPathComponent(fileName).path
    }

    init(remoteId: Int, name: String, author: String, sizeGB: Double, fileName: String, tags: [String]) {
        self.remoteId = remoteId
        self.name = name
        self.author = author
        self.sizeGB = sizeGB
        self.fileName = fileName
        self.tags = tags
    }
}
