//
//  ChatView.swift
//  NobodyWatch Watch App
//

import SwiftUI

struct ChatView: View {
    @Bindable var session: ChatSession

    var body: some View {
        VStack(spacing: 0) {
            ScrollViewReader { proxy in
                List {
                    ForEach(session.messages) { message in
                        MessageBubble(message: message)
                            .listRowInsets(EdgeInsets())
                            .listRowBackground(Color.clear)
                            .padding(.bottom, message.id == session.messages.last?.id ? 8 : 0)
                            .id(message.id)
                    }
                    if session.isLoading {
                        TypingIndicator()
                            .listRowInsets(EdgeInsets())
                            .listRowBackground(Color.clear)
                            .id("loading")
                    }
                    if let errorMessage = session.errorMessage {
                        Text(errorMessage)
                            .font(.caption2)
                            .foregroundStyle(.red)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 8)
                            .listRowInsets(EdgeInsets())
                            .listRowBackground(Color.clear)
                    }
                }
                .listStyle(.plain)
                .onChange(of: session.messages.count) {
                    withAnimation {
                        proxy.scrollTo(session.messages.last?.id, anchor: .bottom)
                    }
                }
                .onChange(of: session.isLoading) {
                    if session.isLoading {
                        withAnimation {
                            proxy.scrollTo("loading", anchor: .bottom)
                        }
                    }
                }
            }

            Divider()

            HStack(spacing: 4) {
                TextField("Ask something…", text: $session.inputText)
                    .font(.caption)
                Button {
                    session.sendMessage()
                } label: {
                    Image(systemName: "arrow.up.circle.fill")
                        .font(.system(size: 20))
                        .foregroundStyle(session.inputText.isEmpty || session.isLoading ? .gray : .blue)
                }
                .disabled(session.inputText.isEmpty || session.isLoading)
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 4)
            .padding(.vertical, 4)
        }
    }
}

/// Animated dot-dot-dot typing indicator
struct TypingIndicator: View {
    @State private var dotCount = 0
    private let timer = Timer.publish(every: 0.5, on: .main, in: .common).autoconnect()

    var body: some View {
        HStack(spacing: 3) {
            ForEach(0..<3) { index in
                Circle()
                    .fill(Color.gray)
                    .frame(width: 5, height: 5)
                    .opacity(index < dotCount ? 1.0 : 0.3)
            }
            Spacer()
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 4)
        .onReceive(timer) { _ in
            dotCount = (dotCount % 3) + 1
        }
    }
}

#Preview {
    let session = ChatSession()
    session.messages = [
        Message(role: .user, content: "What's 2+2?"),
        Message(
            role: .assistant,
            content: "The answer is 4.",
            thinking: "The user asked about 2+2. Let me compute this simple arithmetic."
        ),
        Message(role: .user, content: "Thanks!"),
    ]
    return ChatView(session: session)
}
