//
//  ContentView.swift
//  NobodyWatch Watch App
//
//  Created by pierre on 20/03/2026.
//

import SwiftUI
import NobodyWho

struct Message: Identifiable {
    let id = UUID()
    let role: Role
    let content: String

    enum Role {
        case user, assistant
    }
}

struct ContentView: View {
    @State private var messages: [Message] = []
    @State private var inputText: String = ""
    @State private var isLoading: Bool = false
    @State private var errorMessage: String?
    @State private var modelLoaded: Bool = false
    @State private var chat: Chat?

    /// Path to a GGUF model file on the watch.
    /// In a real app you'd bundle this or download it at runtime.
    private var modelPath: String {
        Bundle.main.path(forResource: "model", ofType: "gguf")!
    }

    var body: some View {
        if !modelLoaded {
            loadingView
        } else {
            chatView
        }
    }

    private var loadingView: some View {
        VStack(spacing: 12) {
            Button {
                loadModel()
            } label: {
                Label("Load Model", systemImage: "cpu")
            }
            .disabled(isLoading)

            if isLoading {
                ProgressView()
                    .padding(.top, 4)
            }

            if let errorMessage {
                Text(errorMessage)
                    .font(.caption2)
                    .foregroundStyle(.red)
                    .multilineTextAlignment(.center)
            }
        }
        .padding()
    }

    private var chatView: some View {
        VStack(spacing: 0) {
            ScrollViewReader { proxy in
                ScrollView {
                    LazyVStack(spacing: 6) {
                        ForEach(messages) { message in
                            MessageBubble(message: message)
                                .id(message.id)
                        }
                        if isLoading {
                            HStack {
                                ProgressView()
                                    .scaleEffect(0.7)
                                Spacer()
                            }
                            .padding(.horizontal, 8)
                            .id("loading")
                        }
                        if let errorMessage {
                            Text(errorMessage)
                                .font(.caption2)
                                .foregroundStyle(.red)
                                .multilineTextAlignment(.center)
                                .padding(.horizontal, 8)
                        }
                    }
                    .padding(.vertical, 8)
                }
                .onChange(of: messages.count) { _ in
                    withAnimation {
                        proxy.scrollTo(messages.last?.id, anchor: .bottom)
                    }
                }
                .onChange(of: isLoading) { loading in
                    if loading {
                        withAnimation {
                            proxy.scrollTo("loading", anchor: .bottom)
                        }
                    }
                }
            }

            Divider()

            HStack(spacing: 6) {
                TextField("Ask something…", text: $inputText)
                    .font(.caption)

                Button {
                    sendMessage()
                } label: {
                    Image(systemName: "arrow.up.circle.fill")
                        .foregroundStyle(inputText.isEmpty || isLoading ? .gray : .blue)
                }
                .disabled(inputText.isEmpty || isLoading)
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 6)
        }
    }

    private func loadModel() {
        isLoading = true
        errorMessage = nil

        Task.detached {
            do {
                initLogging()
                // useGpu: false — Metal is not available on watchOS
                let model = try NobodyWho.loadModel(path: modelPath, useGpu: false)
                let config = ChatConfig(
                    contextSize: 2048,
                    systemPrompt: "You are a helpful assistant running on Apple Watch. Keep answers very short."
                )
                let chatInstance = try Chat(model: model, config: config)

                await MainActor.run {
                    chat = chatInstance
                    modelLoaded = true
                    isLoading = false
                }
            } catch {
                await MainActor.run {
                    errorMessage = "Failed to load model: \(error.localizedDescription)"
                    isLoading = false
                }
            }
        }
    }

    private func sendMessage() {
        guard let chat, !inputText.isEmpty else { return }
        let question = inputText
        inputText = ""
        isLoading = true
        errorMessage = nil

        messages.append(Message(role: .user, content: question))

        Task.detached {
            do {
                let answer = try chat.askBlocking(prompt: question)
                await MainActor.run {
                    messages.append(Message(role: .assistant, content: answer))
                    isLoading = false
                }
            } catch {
                await MainActor.run {
                    errorMessage = "Error: \(error.localizedDescription)"
                    isLoading = false
                }
            }
        }
    }
}

struct MessageBubble: View {
    let message: Message

    var body: some View {
        Text(message.content)
            .font(.caption2)
            .padding(.horizontal, 8)
            .padding(.vertical, 5)
            .background(message.role == .user ? Color.blue : Color.gray.opacity(0.3))
            .foregroundStyle(message.role == .user ? .white : .primary)
            .clipShape(RoundedRectangle(cornerRadius: 10))
            .frame(maxWidth: .infinity, alignment: message.role == .user ? .trailing : .leading)
            .padding(.horizontal, 8)
    }
}

#Preview {
    ContentView()
}
