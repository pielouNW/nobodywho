//
//  ChatSession.swift
//  NobodyWatch Watch App
//

import NobodyWho
import NobodyWatchUI
import SwiftUI

@Observable class ChatSession {
    var messages: [ChatMessage] = []
    var inputText: String = ""
    var isLoading: Bool = false
    var errorLoadingModel: Bool = false
    var errorMessage: String?
    var modelLoaded: Bool = false
    var chat: Chat?

    func loadModel(path: String) {
        isLoading = true
        errorLoadingModel = false
        Task.detached {
            do {
                initLogging()
                // useGpu: false — Metal is not available on watchOS
                let model = try NobodyWho.loadModel(path: path, useGpu: false, mmprojPath: nil)
                let config = ChatConfig(
                    contextSize: 2048,
                    systemPrompt: "You are a helpful assistant. Keep answers short.",
                    allowThinking: false
                )
                let chatInstance = try Chat(model: model, config: config)

                await MainActor.run {
                    self.chat = chatInstance
                    self.modelLoaded = true
                    self.isLoading = false
                }
            } catch {
                print("Unexpected loadModel error: \(error).")
                await MainActor.run {
                    self.errorLoadingModel = true
                    self.isLoading = false
                }
            }
        }
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
