//
//  MessageBubbleView.swift
//  ValkyrieUI
//

import SwiftUI

public struct ChatMessage: Identifiable {
    public let id = UUID()
    public let role: Role
    public var content: String
    public var thinking: String?
    public var isStreaming: Bool

    public enum Role {
        case user, assistant
    }

    public init(role: Role, content: String, thinking: String? = nil, isStreaming: Bool = false) {
        self.role = role
        self.content = content
        self.thinking = thinking
        self.isStreaming = isStreaming
    }
}

public struct MessageBubble: View {
    public let message: ChatMessage
    @State private var showThinking = false

    public init(message: ChatMessage) {
        self.message = message
    }

    public var body: some View {
        VStack(alignment: message.role == .user ? .trailing : .leading, spacing: 4) {
            // Thinking block (assistant only)
            if let thinking = message.thinking, !thinking.isEmpty {
                ThinkingBlock(thinking: thinking, isExpanded: $showThinking)
            }

            // Main content
            if message.isStreaming && message.content.isEmpty {
                TypingIndicator()
            } else {
                HStack(spacing: 0) {
                    Text(message.content)
                        .font(.caption2)
                    if message.isStreaming {
                        StreamingCursor()
                    }
                }
                .padding(.horizontal, 8)
                .padding(.vertical, 5)
                .background(message.role == .user ? Color.blue : Color.gray.opacity(0.3))
                .foregroundStyle(message.role == .user ? .white : .primary)
                .clipShape(RoundedRectangle(cornerRadius: 10))
            }
        }
        .frame(maxWidth: .infinity, alignment: message.role == .user ? .trailing : .leading)
        .padding(.horizontal, 8)
    }
}

public struct ThinkingBlock: View {
    public let thinking: String
    @Binding public var isExpanded: Bool

    public init(thinking: String, isExpanded: Binding<Bool>) {
        self.thinking = thinking
        self._isExpanded = isExpanded
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Button {
                withAnimation(.easeInOut(duration: 0.2)) {
                    isExpanded.toggle()
                }
            } label: {
                HStack(spacing: 3) {
                    Image(systemName: "brain")
                        .font(.system(size: 9))
                    Text("Thinking")
                        .font(.system(size: 10, weight: .medium))
                    Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                        .font(.system(size: 8))
                }
                .foregroundStyle(.secondary)
            }
            .buttonStyle(.plain)

            if isExpanded {
                Text(thinking)
                    .font(.system(size: 9))
                    .foregroundStyle(.secondary)
                    .padding(6)
                    .background(Color.gray.opacity(0.15))
                    .clipShape(RoundedRectangle(cornerRadius: 6))
            }
        }
        .padding(.horizontal, 8)
    }
}

public struct StreamingCursor: View {
    @State private var visible = true
    private let timer = Timer.publish(every: 0.5, on: .main, in: .common).autoconnect()

    public init() {}

    public var body: some View {
        Text("|")
            .font(.caption2)
            .opacity(visible ? 1 : 0)
            .onReceive(timer) { _ in visible.toggle() }
    }
}

#Preview {
    ScrollView {
        VStack(spacing: 6) {
            MessageBubble(message: ChatMessage(role: .user, content: "Hello!"))
            MessageBubble(message: ChatMessage(
                role: .assistant,
                content: "The answer is 4.",
                thinking: "The user asked about 2+2. Let me compute: 2+2=4."
            ))
            MessageBubble(message: ChatMessage(role: .assistant, content: "Hi, how can I help?"))
        }
    }
}
