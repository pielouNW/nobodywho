//
//  SidebarModelRow.swift
//  ValkyrieUI
//

import SwiftUI

public struct SidebarModelRow: View {
    public let name: String
    public let author: String
    public let sizeGB: Double

    public init(name: String, author: String, sizeGB: Double) {
        self.name = name
        self.author = author
        self.sizeGB = sizeGB
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(name)
                .font(.body)
                .fontWeight(.medium)
            HStack(spacing: 6) {
                Text(author)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Text("·")
                    .foregroundStyle(.secondary)
                Text(String(format: "%.1f GB", sizeGB))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }
}

#Preview("SidebarModelRow") {
    List {
        SidebarModelRow(name: "Qwen3 4B Q4 K M", author: "Qwen", sizeGB: 2.5)
        SidebarModelRow(name: "Qwen3 0.6B Q4 K M", author: "Qwen", sizeGB: 0.4)
    }
}
