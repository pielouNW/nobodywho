//
//  NobodyWatchApp.swift
//  NobodyWatch Watch App
//
//  Created by pierre on 20/03/2026.
//

import SwiftUI
import SwiftData

@main
struct NobodyWatch_Watch_AppApp: App {
    var body: some Scene {
        WindowGroup {
            NavigationStack {
                ModelsView()
            }
        }
        .modelContainer(for: DownloadedModel.self)
    }
}
