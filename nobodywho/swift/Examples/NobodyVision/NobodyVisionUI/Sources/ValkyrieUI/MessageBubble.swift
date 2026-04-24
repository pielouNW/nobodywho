//
//  MessageBubble.swift
//  ValkyrieUI
//

import SwiftUI
import Textual

public struct ChatMessage: Identifiable {
    public let id: UUID
    public let role: Role
    public var content: String
    public var thinking: String?
    public var isStreaming: Bool

    public enum Role {
        case user, assistant
    }

    public init(id: UUID = UUID(), role: Role, content: String, thinking: String? = nil, isStreaming: Bool = false) {
        self.id = id
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

    var isUser: Bool {
        message.role == .user
    }

    private var cleanedContent: String {
        let stripped = message.content
            .replacingOccurrences(of: "<think>[\\s\\S]*?</think>", with: "", options: .regularExpression)
            .replacingOccurrences(of: "<think>", with: "")
            .replacingOccurrences(of: "</think>", with: "")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        return message.isStreaming ? Self.stabilizeStreamingMarkdown(stripped) : stripped
    }

    private static func stabilizeStreamingMarkdown(_ input: String) -> String {
        var lines = input.components(separatedBy: "\n")
        while let last = lines.last {
            let trimmed = last.trimmingCharacters(in: .whitespaces)
            if isDanglingBlockMarker(trimmed) {
                lines.removeLast()
            } else {
                break
            }
        }
        var result = lines.joined(separator: "\n")
        if !(result.components(separatedBy: "```").count - 1).isMultiple(of: 2) {
            result += "\n```"
        }
        if !(result.components(separatedBy: "~~~").count - 1).isMultiple(of: 2) {
            result += "\n~~~"
        }
        return result
    }

    private static func isDanglingBlockMarker(_ line: String) -> Bool {
        if line.isEmpty { return true }
        if line == "-" || line == "*" || line == "+" || line == ">" || line == "|" { return true }
        if line.range(of: #"^[-*+]\s*\[[ xX]?\]?$"#, options: .regularExpression) != nil { return true }
        if line.range(of: #"^[-=*_](?:\s*[-=*_])*$"#, options: .regularExpression) != nil { return true }
        if line.range(of: #"^\d+[.)]$"#, options: .regularExpression) != nil { return true }
        if line.range(of: #"^#+$"#, options: .regularExpression) != nil { return true }
        if line.range(of: #"^\|[\s\-:|]*$"#, options: .regularExpression) != nil { return true }
        return false
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
            ForEach(0 ..< 3, id: \.self) { i in
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

#Preview("Simple") {
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
        }
        .padding()
    }
}

#Preview("Markdown") {
    ScrollView {
        MessageBubble(message: ChatMessage(
            role: .assistant,
            content: #"""
            # h1 Heading 8-)
            ## h2 Heading
            ### h3 Heading
            #### h4 Heading
            ##### h5 Heading
            ###### h6 Heading


            ## Horizontal Rules

            ___

            ---

            ***


            ## Typographic replacements

            Enable typographer option to see result.

            (c) (C) (r) (R) (tm) (TM) (p) (P) +-

            test.. test... test..... test?..... test!....

            !!!!!! ???? ,,  -- ---

            "Smartypants, double quotes" and 'single quotes'


            ## Emphasis

            **This is bold text**

            __This is bold text__

            *This is italic text*

            _This is italic text_

            ~~Strikethrough~~


            ## Blockquotes


            > Blockquotes can also be nested...
            >> ...by using additional greater-than signs right next to each other...
            > > > ...or with spaces between arrows.


            ## Lists

            Unordered

            + Create a list by starting a line with `+`, `-`, or `*`
            + Sub-lists are made by indenting 2 spaces:
              - Marker character change forces new list start:
                * Ac tristique libero volutpat at
                + Facilisis in pretium nisl aliquet
                - Nulla volutpat aliquam velit
            + Very easy!

            Ordered

            1. Lorem ipsum dolor sit amet
            2. Consectetur adipiscing elit
            3. Integer molestie lorem at massa


            1. You can use sequential numbers...
            1. ...or keep all the numbers as `1.`

            Start numbering with offset:

            57. foo
            1. bar


            ## Code

            Inline `code`

            Indented code

                // Some comments
                line 1 of code
                line 2 of code
                line 3 of code


            Block code "fences"

            ```
            Sample text here...
            ```

            Syntax highlighting

            ``` js
            var foo = function (bar) {
              return bar++;
            };

            console.log(foo(5));
            ```

            """#
        ))
    }
}

#Preview("Markdown small") {
    ScrollView {
        MessageBubble(message: ChatMessage(
            role: .assistant,
            content: #"""
            The World War II refers to two distinct events:
            1. **World War I** (1914–1918):
               - **Key events**:
                 - The assassination of Archduke Franz Ferdinand in 1914.
            """#
        ))
    }
}
