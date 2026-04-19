//
//  MessageBubble.swift
//  ValkyrieUI
//

import SwiftUI
import Textual

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

    var isUser: Bool { message.role == .user }

    private var cleanedContent: String {
        message.content
            .replacingOccurrences(of: "<think>[\\s\\S]*?</think>", with: "", options: .regularExpression)
            .replacingOccurrences(of: "<think>", with: "")
            .replacingOccurrences(of: "</think>", with: "")
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    public var body: some View {
        VStack(alignment: isUser ? .trailing : .leading, spacing: 6) {
            if let thinking = message.thinking, !thinking.isEmpty {
                VStack(alignment: .leading, spacing: 4) {
                    Button {
                        withAnimation(.easeInOut(duration: 0.2)) {
                            showThinking.toggle()
                        }
                    } label: {
                        HStack(spacing: 4) {
                            Image(systemName: "brain")
                            Text("Thinking")
                                .font(.caption)
                            Image(systemName: showThinking ? "chevron.up" : "chevron.down")
                                .font(.caption2)
                        }
                        .foregroundStyle(.secondary)
                    }
                    .buttonStyle(.plain)

                    if showThinking {
                        Text(thinking)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .padding(8)
                            .background(Color.gray.opacity(0.15))
                            .clipShape(RoundedRectangle(cornerRadius: 10))
                    }
                }
                .padding(.horizontal, 4)
            }

            HStack(spacing: 0) {
                if isUser { Spacer() }

                HStack(alignment: .bottom, spacing: 2) {
                    if message.isStreaming && message.content.isEmpty {
                        TypingIndicator()
                    } else if isUser {
                        Text(cleanedContent)
                    } else {
                        StructuredText(markdown: cleanedContent)
                    }
                }
                .padding(12)
                .background(isUser ? Color.blue : Color.gray.opacity(0.3))
                .foregroundStyle(isUser ? .white : .primary)
                .clipShape(RoundedRectangle(cornerRadius: 16))

                if !isUser { Spacer() }
            }
        }
    }
}

public struct TypingIndicator: View {
    @State private var phase = 0
    private let timer = Timer.publish(every: 0.4, on: .main, in: .common).autoconnect()

    public init() {}

    public var body: some View {
        HStack(spacing: 4) {
            ForEach(0..<3, id: \.self) { i in
                Circle()
                    .frame(width: 7, height: 7)
                    .opacity(phase == i ? 1 : 0.3)
            }
        }
        .onReceive(timer) { _ in
            phase = (phase + 1) % 3
        }
    }
}

#Preview("MessageBubble") {
    ScrollView {
        VStack(spacing: 12) {
            MessageBubble(message: ChatMessage(role: .user, content: "Hello!"))
            MessageBubble(message: ChatMessage(role: .assistant, content: "Hi, how can I help?"))
            MessageBubble(message: ChatMessage(
                role: .assistant,
                content: "The answer is 42.",
                thinking: "The user asked a question. Let me think carefully about the answer."
            ))
            MessageBubble(message: ChatMessage(role: .assistant, content: "", isStreaming: true))
            MessageBubble(message: ChatMessage(
                role: .assistant,
                content: """
                ## Banana bread recipe

                Here are the **three** steps:

                1. Mash *ripe* bananas.
                2. Mix with flour and sugar.
                3. Bake for 50 minutes.

                ```swift
                let oven = 175 // °C
                ```
                """
            ))
        }
        .padding()
    }
}
