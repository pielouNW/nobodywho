//
//  RemoteModelRow.swift
//  ValkyrieUI
//

import SwiftUI

public struct RemoteModelRow: View {
    public let name: String
    public let author: String
    public let sizeGB: Double
    public let tags: [String]
    public var showDownloadIcon: Bool = false
    public var downloadProgress: Double? = nil

    public init(name: String, author: String, sizeGB: Double, tags: [String], showDownloadIcon: Bool = false, downloadProgress: Double? = nil) {
        self.name = name
        self.author = author
        self.sizeGB = sizeGB
        self.tags = tags
        self.showDownloadIcon = showDownloadIcon
        self.downloadProgress = downloadProgress
    }

    public var body: some View {
        HStack(spacing: 12) {
            if showDownloadIcon {
                Image(systemName: "arrow.down.circle")
                    .font(.title2)
                    .foregroundStyle(.blue)
            }

            VStack(alignment: .leading, spacing: 4) {
                Text(name)
                    .font(.body)
                    .fontWeight(.medium)

                if let downloadProgress {
                    ProgressView(value: downloadProgress)
                        .tint(.blue)
                } else {
                    HStack(spacing: 8) {
                        Text(author)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        Text("·")
                            .foregroundStyle(.secondary)
                        Text(String(format: "%.1f GB", sizeGB))
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        ForEach(tags, id: \.self) { tag in
                            Text(tag)
                                .font(.caption2)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(Color.blue.opacity(0.15))
                                .foregroundStyle(.white)
                                .clipShape(Capsule())
                        }
                        Spacer()
                    }
                }
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 4)
    }
}

#Preview("RemoteModelRow") {
    List {
        RemoteModelRow(name: "Qwen3 4B Q4 K M", author: "Qwen", sizeGB: 2.5, tags: ["Thinking"], showDownloadIcon: true)
        RemoteModelRow(name: "Qwen3 0.6B Q4 K M", author: "Qwen", sizeGB: 0.4, tags: ["Fast"])
        RemoteModelRow(name: "Qwen3 4B Q4 K M", author: "Qwen", sizeGB: 2.5, tags: ["Thinking"], downloadProgress: 0.45)
    }
    .listStyle(.insetGrouped)
}
