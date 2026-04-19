//
//  ChatView.swift
//  Valkyrie
//

import Combine
import NobodyWho
import SwiftData
import SwiftUI
import ValkyrieUI

struct ChatView: View {
    @Environment(AppRouter.self) private var router
    @Environment(\.modelContext) private var modelContext
    @State private var session = ChatSession()

    var body: some View {
        NavigationSplitView {
            List {
                if let model = router.selectedChatModel {
                    SidebarModelRow(name: model.name, author: model.author, sizeGB: model.sizeGB).padding(.top, 16)
                }
                Section("Chats") {
                    SidebarChatRow(
                        title: "New chat",
                        icon: "square.and.pencil",
                        isSelected: router.selectedConversationId == nil
                    ) {
                        selectNewChat()
                    }
                    if let model = router.selectedChatModel {
                        ConversationList(modelRemoteId: model.remoteId, onSelect: select)
                    }
                }
            }
            .environment(\.defaultMinListRowHeight, 2)
        } detail: {
            if let selectedModel = router.selectedChatModel {
                ChatDetailView(session: session, model: selectedModel)
                    .id(selectedModel.remoteId)
                    .toolbar {
                        if router.selectedConversationId != nil {
                            ToolbarItem(placement: .topBarTrailing) {
                                Button(role: .destructive) {
                                    deleteCurrentConversation()
                                } label: {
                                    Label("Delete conversation", systemImage: "trash")
                                }
                            }
                        }
                    }
            }
        }
        .onAppear {
            session.modelContext = modelContext
        }
        .onChange(of: session.currentConversationId) { _, newValue in
            // When ChatSession creates a conversation (first message in New chat), sync the router.
            if router.selectedConversationId != newValue {
                router.selectedConversationId = newValue
            }
        }
    }

    private func selectNewChat() {
        router.selectedConversationId = nil
        session.startNewChat()
    }

    private func select(_ conversation: Conversation) {
        router.selectedConversationId = conversation.id
        session.loadConversation(conversation)
    }

    private func deleteCurrentConversation() {
        guard let id = router.selectedConversationId else { return }
        let descriptor = FetchDescriptor<Conversation>(predicate: #Predicate { $0.id == id })
        guard let conversation = (try? modelContext.fetch(descriptor))?.first else { return }
        modelContext.delete(conversation)
        try? modelContext.save()
        selectNewChat()
    }
}

private struct ConversationList: View {
    @Environment(AppRouter.self) private var router
    @Query private var conversations: [Conversation]
    let onSelect: (Conversation) -> Void

    init(modelRemoteId: Int, onSelect: @escaping (Conversation) -> Void) {
        self.onSelect = onSelect
        _conversations = Query(
            filter: #Predicate<Conversation> { $0.modelRemoteId == modelRemoteId },
            sort: [SortDescriptor(\Conversation.createdAt, order: .reverse)]
        )
    }

    var body: some View {
        ForEach(conversations) { conversation in
            SidebarChatRow(
                title: conversation.title,
                isSelected: router.selectedConversationId == conversation.id
            ) {
                onSelect(conversation)
            }
        }
    }
}

private struct ChatDetailView: View {
    @Bindable var session: ChatSession
    let model: DownloadedModel
    private let scrollTimer = Timer.publish(every: 0.3, on: .main, in: .common).autoconnect()

    var body: some View {
        VStack(spacing: 0) {
            if !session.modelLoaded {
                VStack(spacing: 12) {
                    if session.errorLoadingModel {
                        Image(systemName: "exclamationmark.triangle")
                            .font(.largeTitle)
                            .foregroundStyle(.red)
                        Text("Failed to load model")
                            .font(.title3)
                        Button("Retry") {
                            session.loadModel(model)
                        }
                    } else {
                        ProgressView()
                            .scaleEffect(1.5)
                        Text("Loading \(model.name)…")
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
            session.loadModel(model)
        }
    }
}
