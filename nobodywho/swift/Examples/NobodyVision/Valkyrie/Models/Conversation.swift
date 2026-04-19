//
//  Conversation.swift
//  Valkyrie
//

import Foundation
import SwiftData

@Model
final class Conversation {
    @Attribute(.unique) var id: UUID
    var title: String
    var createdAt: Date
    var modelRemoteId: Int

    @Relationship(deleteRule: .cascade, inverse: \PersistedChatMessage.conversation)
    var messages: [PersistedChatMessage] = []

    init(id: UUID = UUID(), title: String, modelRemoteId: Int, createdAt: Date = Date()) {
        self.id = id
        self.title = title
        self.modelRemoteId = modelRemoteId
        self.createdAt = createdAt
    }
}

@Model
final class PersistedChatMessage {
    @Attribute(.unique) var id: UUID
    var roleRaw: String
    var content: String
    var thinking: String?
    var order: Int
    var conversation: Conversation?

    init(id: UUID = UUID(), role: Role, content: String, thinking: String? = nil, order: Int) {
        self.id = id
        self.roleRaw = role.rawValue
        self.content = content
        self.thinking = thinking
        self.order = order
    }

    enum Role: String {
        case user, assistant
    }

    var role: Role {
        Role(rawValue: roleRaw) ?? .assistant
    }
}
