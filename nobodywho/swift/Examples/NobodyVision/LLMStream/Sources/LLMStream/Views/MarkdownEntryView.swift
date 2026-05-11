import SwiftUI
import Textual

struct MarkdownEntryView: View {
    let entry: MarkdownEntry
    @State var isCollapsed: Bool = false

    var body: some View {
        let text = isCollapsed ? (entry.collapsed ?? entry.content) : entry.content
        StructuredText(markdown: text)
            .onTapGesture {
                if entry.collapsable {
                    isCollapsed.toggle()
                }
            }
    }
}
