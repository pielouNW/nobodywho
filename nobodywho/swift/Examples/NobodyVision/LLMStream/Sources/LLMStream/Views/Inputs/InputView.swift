import SwiftUI

struct InputView: View {
    @Environment(\.streamContentInputHandler) var handler

    var input: Input

    var body: some View {
        switch input.content {
        case .hidden:
            EmptyView()
        case .button(let name):
            InputButtonView(name: name) {
                handler(input)
            }
            .padding(.horizontal)
        case .appearance:
            AppearanceInputView(input: input)
                .padding(.horizontal)
        }
    }
}

struct InputButtonView: View {
    var name: String
    var onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            Text(name)
                .font(.headline)
                .foregroundStyle(Color(uiColor: .systemBackground))
                .frame(maxWidth: .infinity)
                .padding()
                .frame(height: 44)
                .background(Color(uiColor: .label))
                .cornerRadius(12)
        }
    }
}
