import SwiftUI

struct InfoView: View {
    var body: some View {
        List {
            Text("This app is made by NobodyWho.\n\nNobodyWho is an open-source library designed to run LLMs locally and efficiently on any device.\n\nLLMs are downloaded from Hugging Face.")
                .listRowBackground(Color.clear)
                .padding(.bottom, 8)

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

#Preview {
    NavigationStack {
        InfoView()
    }
}
