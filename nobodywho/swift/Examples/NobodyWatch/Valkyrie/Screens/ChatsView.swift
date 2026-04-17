//
//  ChatsView.swift
//  NobodyWatch Watch App
//

import SwiftUI

private struct Chat: Identifiable {
    let id: Int
    let title: String
    let date: Date
}

private let fakeChats: [Chat] = [
    Chat(id: 1, title: "Weekend plans", date: Calendar.current.date(byAdding: .hour, value: -1, to: .now)!),
    Chat(id: 2, title: "Recipe ideas", date: Calendar.current.date(byAdding: .day, value: -1, to: .now)!),
    Chat(id: 3, title: "Workout routine for better results", date: Calendar.current.date(byAdding: .day, value: -2, to: .now)!),
    Chat(id: 4, title: "Book recommendations", date: Calendar.current.date(byAdding: .day, value: -5, to: .now)!),
    Chat(id: 5, title: "Travel tips", date: Calendar.current.date(byAdding: .day, value: -10, to: .now)!),
]

struct ChatsView: View {
    @Bindable var session: ChatSession

    var body: some View {
        List(fakeChats) { chat in
            VStack(alignment: .leading, spacing: 2) {
                Text(chat.title)
                    .font(.body)
                    .lineLimit(1)
                Text(chat.date, style: .date)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
        }
        .listStyle(.plain)
        .navigationTitle("Chats")
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                NavigationLink(destination: ChatView(session: session)) {
                    Image(systemName: "plus")
                }
            }
        }
    }
}
