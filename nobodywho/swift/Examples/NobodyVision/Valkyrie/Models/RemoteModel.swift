//
//  RemoteModel.swift
//  Valkyrie
//

import Foundation

struct RemoteModel: Codable, Identifiable {
    let id: Int
    let name: String
    let sizeGB: Double
    let parameterCountBillions: Double
    let author: String
    let fileName: String
    let downloadURL: URL
    let tags: [String]

    enum CodingKeys: String, CodingKey {
        case id = "modelId"
        case name = "modelName"
        case sizeGB = "modelSizeGB"
        case parameterCountBillions
        case author
        case fileName
        case downloadURL
        case tags
    }
}
