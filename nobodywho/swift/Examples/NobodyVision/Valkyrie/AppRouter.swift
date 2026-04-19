//
//  AppRouter.swift
//  Valkyrie
//

import Foundation

enum AppTab: Hashable {
    case models, chat
}

@Observable
final class AppRouter {
    var selectedTab: AppTab = .models
    var selectedChatModel: DownloadedModel?
    /// `nil` means the "New chat" row is selected.
    var selectedConversationId: UUID?

    private static let selectedModelKey = "selectedModelRemoteId"

    func selectModel(_ model: DownloadedModel) {
        selectedChatModel = model
        UserDefaults.standard.set(model.remoteId, forKey: Self.selectedModelKey)
    }

    func clearSelectedModel() {
        selectedChatModel = nil
        UserDefaults.standard.removeObject(forKey: Self.selectedModelKey)
        if selectedTab == .chat {
            selectedTab = .models
        }
    }

    func restoreSelection(from models: [DownloadedModel]) {
        guard selectedChatModel == nil else { return }
        guard let remoteId = UserDefaults.standard.object(forKey: Self.selectedModelKey) as? Int else { return }
        if let model = models.first(where: { $0.remoteId == remoteId }) {
            selectedChatModel = model
            selectedTab = .chat
        }
    }
}
