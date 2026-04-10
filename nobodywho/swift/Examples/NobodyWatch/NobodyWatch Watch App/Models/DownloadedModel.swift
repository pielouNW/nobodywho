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
    var filePath: String

    init(remoteId: Int, name: String, author: String, sizeMB: Int, fileName: String, filePath: String) {
        self.remoteId = remoteId
        self.name = name
        self.author = author
        self.sizeMB = sizeMB
        self.fileName = fileName
        self.filePath = filePath
    }
}
