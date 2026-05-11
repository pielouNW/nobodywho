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
        let selectedChatModel = router.selectedChatModel
        let selectedConversationId = router.selectedConversationId

        NavigationSplitView {
            List {
                if let selectedChatModel {
                    SidebarModelRow(name: selectedChatModel.name, author: selectedChatModel.author, sizeGB: selectedChatModel.sizeGB).padding(.top, 16)
                }
                Section("Chats") {
                    SidebarChatRow(
                        title: "New chat",
                        icon: "square.and.pencil",
                        isSelected: selectedConversationId == nil
                    ) {
                        selectNewChat()
                    }
                    if let selectedChatModel {
                        ConversationsList(modelRemoteId: selectedChatModel.remoteId, onSelect: select)
                    }
                }
            }
            .environment(\.defaultMinListRowHeight, 2)
        } detail: {
            if let selectedChatModel {
                ChatDetailView(session: session, model: selectedChatModel)
                    .id(selectedChatModel.remoteId)
                    .toolbar {
                        if selectedConversationId != nil {
                            ToolbarItem(placement: .topBarTrailing) {
                                Button(role: .destructive) {
                                    deleteCurrentConversation()
                                } label: {
                                    Label("Delete conversation", systemImage: "trash")
                                }
                                .disabled(session.isStreaming)
                            }
                        }
                    }
            }
        }
        .onAppear {
            session.modelContext = modelContext
        }
        .onChange(of: session.currentConversationId) { _, newValue in
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

private struct ConversationsList: View {
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
    @State private var isNearBottom: Bool = true

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
                        VStack(alignment: .leading, spacing: 12) {
                            ForEach(session.messages) { message in
                                MessageBubble(message: message)
                                    .id(message.id)
                            }
                            if let errorMessage = session.errorMessage {
                                Text(errorMessage)
                                    .font(.caption)
                                    .foregroundStyle(.red)
                            }
                        }
                        .padding(.vertical, 6)
                        .padding(.horizontal, 16)
                    }
                    .defaultScrollAnchor(.bottom)
                    .onScrollGeometryChange(for: Bool.self) { geo in
                        let distance = geo.contentSize.height - geo.contentOffset.y - geo.containerSize.height
                        return distance < 200
                    } action: { _, newValue in
                        isNearBottom = newValue
                    }
                    .onChange(of: session.messages.last?.content) {
                        if isNearBottom, let lastId = session.messages.last?.id {
                            proxy.scrollTo(lastId, anchor: .bottom)
                        }
                    }
                    .onChange(of: session.messages.count) {
                        isNearBottom = true
                        if let lastId = session.messages.last?.id {
                            proxy.scrollTo(lastId, anchor: .bottom)
                        }
                    }
                    .onChange(of: session.isStreaming) { _, newValue in
                        if !newValue, let last = session.messages.last {
                            print(last.content)
                        }
                    }
                }

                InputBar(isLoading: session.isStreaming) { question in
                    session.ask(question)
                }
            }
        }
        .frame(minWidth: 400, minHeight: 500)
        .onAppear {
            session.loadModel(model)
        }
    }
}
