//
//  InputBar.swift
//  ValkyrieUI
//

import SwiftUI

public struct InputBar: View {
    let isLoading: Bool
    let onSend: (String) -> Void
    @State private var text: String = ""

    public init(isLoading: Bool, onSend: @escaping (String) -> Void) {
        self.isLoading = isLoading
        self.onSend = onSend
    }

    public var body: some View {
        HStack {
            TextField("Ask something...", text: $text)
                .textFieldStyle(.roundedBorder)
                .onSubmit(send)

            Button(action: send) {
                Image(systemName: "arrow.up.circle.fill")
                    .font(.title2)
            }
            .disabled(text.isEmpty || isLoading)
        }
        .padding()
    }

    private func send() {
        let input = text
        text = ""
        onSend(input)
    }
}

#Preview("InputBar") {
    InputBar(isLoading: false) { _ in }
}
