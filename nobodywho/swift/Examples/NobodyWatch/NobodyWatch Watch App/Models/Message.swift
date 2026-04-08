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
    let content: String
    let thinking: String?

    enum Role {
        case user, assistant
    }

    init(role: Role, content: String, thinking: String? = nil) {
        self.role = role
        self.content = content
        self.thinking = thinking
    }
}
