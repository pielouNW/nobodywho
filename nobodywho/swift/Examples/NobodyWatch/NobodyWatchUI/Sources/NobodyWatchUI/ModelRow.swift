//
//  ModelRow.swift
//  NobodyWatchUI
//

import SwiftUI

public struct ModelRow: View {
    public let name: String
    public let author: String
    public let modelSizeMB: Int
    public var showDownloadIcon: Bool = false
    public var downloadProgress: Double? = nil

    public init(name: String, author: String, modelSizeMB: Int, showDownloadIcon: Bool = false, downloadProgress: Double? = nil) {
        self.name = name
        self.author = author
        self.modelSizeMB = modelSizeMB
        self.showDownloadIcon = showDownloadIcon
        self.downloadProgress = downloadProgress
    }

    public var body: some View {
        HStack(spacing: 8) {
            if showDownloadIcon {
                Image(systemName: "arrow.down.circle")
                    .font(.title3)
                    .foregroundColor(.white)
            }

            VStack(alignment: .leading, spacing: 2) {
                Text(name)
                    .font(.caption)
                    .fontWeight(.medium)
                    .lineLimit(2)
                if let downloadProgress {
                    HStack {
                        Text(author).font(.caption2).hidden()
                        Spacer()
                    }
                    .overlay {
                        ProgressView(value: downloadProgress)
                            .tint(.blue)
                    }
                } else {
                    HStack(spacing: 6) {
                        Text(author)
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                        Spacer()
                        Text("\(modelSizeMB) MB")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                }
            }
        }
        .padding(.vertical, 2)
    }
}

#Preview("ModelRow") {
    List {
        ModelRow(name: "LFM2 350M Q2 K", author: "Liquid AI", modelSizeMB: 160)
        ModelRow(name: "Bonsai 1.7B", author: "PrismML", modelSizeMB: 248, showDownloadIcon: true)
        ModelRow(name: "LFM2 450M Q2 K", author: "Liquid AI", modelSizeMB: 310, downloadProgress: 0.45)
    }
    .listStyle(.plain)
}
