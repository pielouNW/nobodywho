//
//  ChatSession.swift
//  NobodyVision
//

import SwiftUI
import SwiftData
import NobodyWho
import ValkyrieUI

@Observable class ChatSession {
    var messages: [ChatMessage] = []
    var inputText: String = ""
    var isLoading: Bool = false
    var errorLoadingModel: Bool = false
    var errorMessage: String?
    var modelLoaded: Bool = false
    var chat: Chat?
    var loadedModelId: Int?

    /// ID of the conversation currently being edited. `nil` means we're in "New chat" mode.
    var currentConversationId: UUID?

    private var nobodyModel: NobodyWho.Model?
    private var chatConfig: ChatConfig?
    var modelContext: ModelContext?

    func loadModel(_ downloadedModel: DownloadedModel) {
        guard loadedModelId != downloadedModel.remoteId else { return }

        isLoading = true
        errorLoadingModel = false
        modelLoaded = false
        messages = []
        errorMessage = nil
        chat = nil
        nobodyModel = nil
        currentConversationId = nil
        loadedModelId = downloadedModel.remoteId

        let path = downloadedModel.filePath
        Task.detached {
            do {
                initLogging()
                #if targetEnvironment(simulator)
                let useGpu = false
                #else
                let useGpu = true
                #endif
                let model = try NobodyWho.loadModel(path: path, useGpu: useGpu, mmprojPath: nil)
                let config = ChatConfig(
                    contextSize: 2048,
                    systemPrompt: "You are a helpful assistant running on Apple Vision Pro. Keep answers concise.",
                    allowThinking: true
                )
                let chatInstance = try Chat(model: model, config: config)

                await MainActor.run {
                    self.nobodyModel = model
                    self.chatConfig = config
                    self.chat = chatInstance
                    self.modelLoaded = true
                    self.isLoading = false
                }
            } catch {
                await MainActor.run {
                    self.errorLoadingModel = true
                    self.isLoading = false
                }
            }
        }
    }

    /// Reset to a fresh "New chat" state: empty messages and a new LLM chat context.
    func startNewChat() {
        messages = []
        errorMessage = nil
        currentConversationId = nil
        rebuildChat()
    }

    /// Load an existing conversation's messages for display and reset the LLM chat context.
    func loadConversation(_ conversation: Conversation) {
        let sorted = conversation.messages.sorted(by: { $0.order < $1.order })
        messages = sorted.map { ChatMessage(
            role: $0.role == .user ? .user : .assistant,
            content: $0.content,
            thinking: $0.thinking,
            isStreaming: false
        ) }
        errorMessage = nil
        currentConversationId = conversation.id
        rebuildChat()
    }

    private func rebuildChat() {
        guard let model = nobodyModel, let config = chatConfig else { return }
        chat = try? Chat(model: model, config: config)
    }

    func sendMessage() {
        guard let chat, !inputText.isEmpty else { return }
        let question = inputText
        inputText = ""
        isLoading = true
        errorMessage = nil

        messages.append(ChatMessage(role: .user, content: question))
        let assistantIndex = messages.count
        messages.append(ChatMessage(role: .assistant, content: "", isStreaming: true))

        // Persist: create a new conversation if needed, and insert the user message now.
        let userMessageOrder = ensureConversationAndPersistUserMessage(question: question)

        Task.detached {
            do {
                let stream = chat.ask(prompt: question)
                var fullResponse = ""

                while let token = stream.nextToken() {
                    fullResponse += token
                    let current = fullResponse
                    await MainActor.run {
                        self.messages[assistantIndex].content = current
                    }
                }

                // Stream complete — parse thinking blocks from final response
                let parsed = Self.parseThinkingFromResponse(fullResponse)

                await MainActor.run {
                    self.messages[assistantIndex].content = parsed.answer
                    self.messages[assistantIndex].thinking = parsed.thinking
                    self.messages[assistantIndex].isStreaming = false
                    self.isLoading = false
                    self.persistAssistantMessage(
                        content: parsed.answer,
                        thinking: parsed.thinking,
                        order: userMessageOrder + 1
                    )
                }
            } catch {
                await MainActor.run {
                    self.messages[assistantIndex].isStreaming = false
                    self.errorMessage = "Error: \(error.localizedDescription)"
                    self.isLoading = false
                }
            }
        }
    }

    // MARK: - Persistence helpers

    private func ensureConversationAndPersistUserMessage(question: String) -> Int {
        guard let modelContext, let modelRemoteId = loadedModelId else { return 0 }

        let conversation: Conversation
        if let id = currentConversationId, let existing = fetchConversation(id: id) {
            conversation = existing
        } else {
            let title = makeTitle(from: question)
            let new = Conversation(title: title, modelRemoteId: modelRemoteId)
            modelContext.insert(new)
            currentConversationId = new.id
            conversation = new
        }

        let order = (conversation.messages.map { $0.order }.max() ?? -1) + 1
        let userMessage = PersistedChatMessage(role: .user, content: question, order: order)
        userMessage.conversation = conversation
        conversation.messages.append(userMessage)
        modelContext.insert(userMessage)
        try? modelContext.save()
        return order
    }

    private func persistAssistantMessage(content: String, thinking: String?, order: Int) {
        guard let modelContext,
              let id = currentConversationId,
              let conversation = fetchConversation(id: id) else { return }

        let message = PersistedChatMessage(role: .assistant, content: content, thinking: thinking, order: order)
        message.conversation = conversation
        conversation.messages.append(message)
        modelContext.insert(message)
        try? modelContext.save()
    }

    private func fetchConversation(id: UUID) -> Conversation? {
        guard let modelContext else { return nil }
        let descriptor = FetchDescriptor<Conversation>(predicate: #Predicate { $0.id == id })
        return (try? modelContext.fetch(descriptor))?.first
    }

    private func makeTitle(from question: String) -> String {
        let trimmed = question.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.count <= 50 { return trimmed }
        return String(trimmed.prefix(50)) + "…"
    }

    /// Parse thinking content from model response.
    /// Returns (thinking, answer) tuple.
    static func parseThinkingFromResponse(_ response: String) -> (thinking: String?, answer: String) {
        let patterns = [
            "<think>(.*?)</think>",
            "<thinking>(.*?)</thinking>",
            "\\[THINKING\\](.*?)\\[/THINKING\\]",
            "\\[THINK\\](.*?)\\[/THINK\\]",
        ]

        for pattern in patterns {
            guard let regex = try? NSRegularExpression(
                pattern: pattern,
                options: [.caseInsensitive, .dotMatchesLineSeparators]
            ) else { continue }

            let nsRange = NSRange(response.startIndex..., in: response)

            if let match = regex.firstMatch(in: response, range: nsRange),
               match.numberOfRanges > 1,
               let thinkingRange = Range(match.range(at: 1), in: response)
            {
                let thinking = String(response[thinkingRange])
                    .trimmingCharacters(in: .whitespacesAndNewlines)
                let answer = regex.stringByReplacingMatches(
                    in: response,
                    range: nsRange,
                    withTemplate: ""
                ).trimmingCharacters(in: .whitespacesAndNewlines)

                return (thinking.isEmpty ? nil : thinking, answer)
            }
        }

        return (nil, response)
    }
}
