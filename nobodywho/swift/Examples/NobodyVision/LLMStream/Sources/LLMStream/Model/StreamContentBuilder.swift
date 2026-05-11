import Foundation

public struct StreamContentBuilder {
    public var buffer: String

    public init(buffer: String = "") {
        self.buffer = buffer
    }

    func buildContent(raw: RawBuilder.Content, ids nestedIds: IdentifierGenerator) -> StreamContent {
        var ids = nestedIds
        var content = StreamContent()
        content.finished = raw.eom

        for rawItem in raw.items {
            switch rawItem.value.value {
            case .markdown(let markdown):
                var builder = MarkdownBuilder(rawMarkdown: markdown)
                if content.finished {
                    builder.cleanup()
                }
                content.items.append(contentsOf: builder.build(ids: ids.nested()).items)
            case .xml(let xml):
                content.items.append(.init(ids: &ids, value: .xml(xml)))
            case .error(let error):
                if rawItem.value.finished {
                    content.errors.append(error)
                }
            }
        }
        return content
    }

    public func build() -> StreamContent {
        let raw = RawBuilder(buffer: buffer).build()
        var ids: any IdentifierGenerator = IncrementalIdentifierGenerator.create()
        var content = buildContent(raw: raw, ids: ids.nested())
        content = OptionBuilder(input: content).build(ids: ids.nested())
        content = InputBuilder(input: content).build(ids: ids.nested())
        content = QuestionBuilder(input: content).build(ids: ids.nested())
        content = WidgetBuilder(input: content).build(ids: ids.nested())
        return content
    }
}
