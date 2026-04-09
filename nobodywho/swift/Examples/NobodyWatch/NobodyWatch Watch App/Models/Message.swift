//
//  Message.swift
//  NobodyWatch Watch App
//
//  Created by pierre on 20/03/2026.
//

import Foundation

struct Message: Identifiable {
    let id = UUID()
    let role: Role
    var content: String
    var thinking: String?
    var isStreaming: Bool

    enum Role {
        case user, assistant
    }

    init(role: Role, content: String, thinking: String? = nil, isStreaming: Bool = false) {
        self.role = role
        self.content = content
        self.thinking = thinking
        self.isStreaming = isStreaming
    }
}
