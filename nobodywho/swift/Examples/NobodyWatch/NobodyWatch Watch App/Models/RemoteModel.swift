//
//  RemoteModel.swift
//  NobodyWatch Watch App
//

import Foundation

struct RemoteModel: Codable, Identifiable {
    let id: Int
    let name: String
    let sizeMB: Int
    let parameterCountMillions: Int
    let author: String
    let fileName: String
    let downloadURL: URL

    enum CodingKeys: String, CodingKey {
        case id = "modelId"
        case name = "modelName"
        case sizeMB = "modelSizeMB"
        case parameterCountMillions
        case author
        case fileName
        case downloadURL
    }
}
