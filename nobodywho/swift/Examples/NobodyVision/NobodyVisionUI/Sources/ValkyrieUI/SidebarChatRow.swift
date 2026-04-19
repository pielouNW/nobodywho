//
//  SidebarChatRow.swift
//  ValkyrieUI
//

import SwiftUI

public struct SidebarChatRow: View {
    public let title: String
    public let icon: String?
    public let isSelected: Bool
    public let action: () -> Void

    public init(title: String, icon: String? = nil, isSelected: Bool = false, action: @escaping () -> Void = {}) {
        self.title = title
        self.icon = icon
        self.isSelected = isSelected
        self.action = action
    }

    public var body: some View {
        HStack(spacing: 8) {
            if let icon {
                Image(systemName: icon)
                    .foregroundStyle(isSelected ? .primary : .secondary)
            }
            Text(title)
                .font(.body)
                .lineLimit(1)
                .truncationMode(.tail)
            Spacer()
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 10)
        .background(isSelected ? AnyShapeStyle(.quaternary) : AnyShapeStyle(.clear), in: RoundedRectangle(cornerRadius: 8))
        .contentShape(RoundedRectangle(cornerRadius: 8))
        .hoverEffect(.highlight)
        .onTapGesture(perform: action)
        .listRowInsets(EdgeInsets(top: 0, leading: 8, bottom: 0, trailing: 8))
        .listRowSeparator(.hidden)
    }
}

#Preview("SidebarChatRow") {
    List {
        SidebarChatRow(title: "Explain quantum entanglement simply", isSelected: true)
        SidebarChatRow(title: "What's the best way to learn Rust?")
        SidebarChatRow(title: "Plan a 7-day trip to Japan")
        SidebarChatRow(title: "New chat", icon: "square.and.pencil")
    }
    .listStyle(.sidebar)
}
