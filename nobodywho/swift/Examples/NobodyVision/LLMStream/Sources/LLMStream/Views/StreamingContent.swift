import SwiftUI

public struct StreamingContent: View {
    let text: String
    let isStreaming: Bool

    @State private var content: StreamContent = StreamContent()

    public init(_ text: String, isStreaming: Bool = false) {
        self.text = text
        self.isStreaming = isStreaming
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            ForEach(content.items) { item in
                StreamContentItemView(item: item, padded: false)
            }
        }
        .animation(isStreaming ? .default : nil, value: content.items)
        .onChange(of: text, initial: true) { _, newText in
            content = StreamContentBuilder(buffer: newText).build()
        }
    }
}
