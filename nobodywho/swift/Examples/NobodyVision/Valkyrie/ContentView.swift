//
//  ContentView.swift
//  Valkyrie
//
//  Created by Pierre Bresson on 17/04/2026.
//

import NobodyWho
import SwiftUI
import Combine

struct ContentView: View {
    @State private var session = ChatSession()
    private let scrollTimer = Timer.publish(every: 0.3, on: .main, in: .common).autoconnect()

    var body: some View {
        VStack(spacing: 16) {
            if !session.modelLoaded {
                VStack(spacing: 12) {
                    if session.errorLoadingModel {
                        Image(systemName: "exclamationmark.triangle")
                            .font(.largeTitle)
                            .foregroundStyle(.red)
                        Text("Failed to load model")
                            .font(.title3)
                        Button("Retry") {
                            session.loadModel()
                        }
                    } else {
                        ProgressView()
                            .scaleEffect(1.5)
                        Text("Loading model...")
                            .font(.title3)
                            .foregroundStyle(.secondary)
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                ScrollViewReader { proxy in
                    ScrollView {
                        LazyVStack(alignment: .leading, spacing: 12) {
                            ForEach(session.messages) { message in
                                MessageBubble(message: message)
                                    .id(message.id)
                            }
                            if let errorMessage = session.errorMessage {
                                Text(errorMessage)
                                    .font(.caption)
                                    .foregroundStyle(.red)
                                    .padding(.horizontal)
                            }
                        }
                        .padding()
                    }
                    .onChange(of: session.messages.count) {
                        withAnimation {
                            proxy.scrollTo(session.messages.last?.id, anchor: .bottom)
                        }
                    }
                    .onReceive(scrollTimer) { _ in
                        if session.messages.last?.isStreaming == true {
                            proxy.scrollTo(session.messages.last?.id, anchor: .bottom)
                        }
                    }
                }

                HStack {
                    TextField("Ask something...", text: $session.inputText)
                        .textFieldStyle(.roundedBorder)
                        .onSubmit {
                            session.sendMessage()
                        }

                    Button {
                        session.sendMessage()
                    } label: {
                        Image(systemName: "arrow.up.circle.fill")
                            .font(.title2)
                    }
                    .disabled(session.inputText.isEmpty || session.isLoading)
                }
                .padding()
            }
        }
        .frame(minWidth: 400, minHeight: 500)
        .onAppear {
            session.loadModel()
        }
    }
}

struct MessageBubble: View {
    let message: Message
    @State private var showThinking = false

    var isUser: Bool { message.role == .user }

    var body: some View {
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
                    } else {
                        Text(message.content)
                        if message.isStreaming {
                            StreamingCursor()
                        }
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

struct StreamingCursor: View {
    @State private var visible = true
    private let timer = Timer.publish(every: 0.5, on: .main, in: .common).autoconnect()

    var body: some View {
        Text("|")
            .opacity(visible ? 1 : 0)
            .onReceive(timer) { _ in visible.toggle() }
    }
}

struct TypingIndicator: View {
    @State private var phase = 0
    private let timer = Timer.publish(every: 0.4, on: .main, in: .common).autoconnect()

    var body: some View {
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

#Preview(windowStyle: .automatic) {
    ContentView()
}
