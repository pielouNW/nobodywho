//
//  ChatView.swift
//  NobodyWatch Watch App
//

import ValkyrieUI
import SwiftUI

struct ChatView: View {
    @Bindable var session: ChatSession
    private let scrollTimer = Timer.publish(every: 0.3, on: .main, in: .common).autoconnect()

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
                .onReceive(scrollTimer) { _ in
                    if session.messages.last?.isStreaming == true {
                        withAnimation {
                            proxy.scrollTo(session.messages.last?.id, anchor: .bottom)
                        }
                    }
                }
                .onChange(of: session.isLoading) {
                    if session.isLoading {
                        withAnimation {
                            proxy.scrollTo(session.messages.last?.id, anchor: .bottom)
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
