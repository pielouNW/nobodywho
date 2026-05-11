import SwiftUI
import Foundation

public struct StreamContentItemView: View {
    let item: StreamContentItem<StreamItemValue>
    let padded: Bool

    public init(item: StreamContentItem<StreamItemValue>, padded: Bool = true) {
        self.item = item
        self.padded = padded
    }

    public var body: some View {
        switch item.value {
        case .markdown(let entry):
            MarkdownEntryView(entry: entry)
                .padding(.horizontal, padded ? 16 : 0)
        case .markdownTable(let table):
            MarkdownTableView(table: table)
        case .question(let question):
            SingleQuestionView(question: question)
                .padding(.horizontal, padded ? 16 : 0)
        case .questionGroup(let group):
            QuestionGroupView(group: group)
        case .widget(let widget):
            WidgetView(widget: widget)
                .padding(.horizontal, padded ? 16 : 0)
        case .container(let container):
            ContainerWidgetView(container: container)
        case .input(let input):
            InputView(input: input)
        case .xml:
            EmptyView()
        }
    }
}

extension EnvironmentValues {
    @Entry public var streamContentInputHandler: (Input) -> Void = { _ in }
    @Entry public var streamContentActionHandler: StreamContentActionHandler = .init(
        markAsExecuted: { _ in },
        canExecute: { _ in true },
        setColorScheme: { _ in }
    )
}

public struct StreamContentActionHandler {
    public var markAsExecuted: (Input) -> Void
    public var canExecute: (Input) -> Bool
    public var setColorScheme: (ColorScheme) -> Void

    public init(
        markAsExecuted: @escaping (Input) -> Void,
        canExecute: @escaping (Input) -> Bool,
        setColorScheme: @escaping (ColorScheme) -> Void
    ) {
        self.markAsExecuted = markAsExecuted
        self.canExecute = canExecute
        self.setColorScheme = setColorScheme
    }
}

public struct StreamContentView: View {
    public let content: StreamContent

    public init(content: StreamContent) {
        self.content = content
    }

    public var body: some View {
        LazyVStack(alignment: .leading, spacing: 12) {
            ForEach(content.items) { item in
                StreamContentItemView(item: item)
            }
        }
        .animation(.default, value: content.items)
        .padding(.bottom, 88)
    }
}
