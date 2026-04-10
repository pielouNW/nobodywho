//
//  ModelLoadingView.swift
//  NobodyWatch Watch App
//
//  Created by pierre on 20/03/2026.
//

import NobodyWatchUI
import SwiftUI

struct ModelLoadingView: View {
    let modelPath: String
    @State private var session = ChatSession()

    var body: some View {
        Group {
            if session.modelLoaded {
                ChatView(session: session)
            } else {
                LoadingView(hasError: session.errorLoadingModel, errorMessage: "Failed to load model. Please try again.") {
                    session.loadModel(path: modelPath)
                }
            }
        }
        .onDisappear {
            session.unloadModel()
        }
    }
}
