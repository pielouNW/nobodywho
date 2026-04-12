//
//  InfoView.swift
//  NobodyWatch Watch App
//

import SwiftUI

struct InfoView: View {
    var body: some View {
        List {
            Text("This app was made by Pierre Bresson, using NobodyWho inference engine. LLMs are downloaded from Hugging Face.")
                .listRowBackground(Color.clear)
                .padding(.bottom, 8)

            ShareLink(item: URL(string: "https://pierre.bresson.io/")!) {
                Label("Pierre Bresson", systemImage: "globe")
            }

            ShareLink(item: URL(string: "https://github.com/nobodywho-ooo/nobodywho")!) {
                Label("NobodyWho", systemImage: "chevron.left.forwardslash.chevron.right")
            }

            ShareLink(item: URL(string: "https://huggingface.co/")!) {
                Label("Hugging Face", systemImage: "face.smiling")
            }
        }
        .navigationTitle("Info")
    }
}
