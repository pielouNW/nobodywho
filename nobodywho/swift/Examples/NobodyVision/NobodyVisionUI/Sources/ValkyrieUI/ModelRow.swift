//
//  ModelRow.swift
//  ValkyrieUI
//

import SwiftUI

public struct ModelRow: View {
    public let name: String
    public let author: String
    public let sizeGB: Double
    public let tags: [String]
    public let isSelected: Bool

    public init(name: String, author: String, sizeGB: Double, tags: [String], isSelected: Bool = false) {
        self.name = name
        self.author = author
        self.sizeGB = sizeGB
        self.tags = tags
        self.isSelected = isSelected
    }

    public var body: some View {
        HStack() {
            if isSelected {
                Image(systemName: "checkmark.circle.fill")
                    .font(.title2)
                    .foregroundStyle(.green)
            }

            VStack(alignment: .leading, spacing: 4) {
                Text(name)
                    .font(.body)
                    .fontWeight(.medium)
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
                            .background(Color.green.opacity(0.15))
                            .foregroundStyle(.green)
                            .clipShape(Capsule())
                    }
                    Spacer()
                }
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 4)
    }
}

#Preview("ModelRow") {
    List {
        ModelRow(name: "Qwen3 4B Q4 K M", author: "Qwen", sizeGB: 2.5, tags: ["Thinking", "Clever"], isSelected: true)
        ModelRow(name: "Qwen3 0.6B Q4 K M", author: "Qwen", sizeGB: 0.4, tags: ["Fast"], isSelected: false)
    }
    .listStyle(.insetGrouped)
}
