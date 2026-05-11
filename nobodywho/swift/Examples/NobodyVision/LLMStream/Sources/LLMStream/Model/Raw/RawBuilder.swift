struct RawBuilder {
    var buffer: String = ""

    struct Content {
        var items: [StreamContentItem<ContinuousItem>] = []
        var eom: Bool = false

        mutating func append(markdown: some StringProtocol, finished: Bool, ids: inout IdentifierGenerator) {
            let item = ContinuousItem(finished: finished || eom, value: .markdown(String(markdown)))
            items.append(StreamContentItem<ContinuousItem>(ids: &ids, value: item))
        }

        mutating func append(xml: [XmlElement], finished: Bool, ids: inout IdentifierGenerator) {
            let item = ContinuousItem(finished: finished || eom, value: .xml(xml))
            items.append(StreamContentItem<ContinuousItem>(ids: &ids, value: item))
        }

        mutating func append(error: Error, finished: Bool, ids: inout IdentifierGenerator) {
            let item = ContinuousItem(
                finished: finished || eom,
                value: .error(IdentifiableError(ids: &ids, underlyingError: error))
            )
            items.append(StreamContentItem<ContinuousItem>(ids: &ids, value: item))
        }
    }

    struct ContinuousItem: Equatable {
        var finished: Bool
        var value: Item
    }

    enum Item: Equatable {
        case markdown(String)
        case xml([XmlElement])
        case error(IdentifiableError)
    }

    func build() -> Content {
        var ids: any IdentifierGenerator = IncrementalIdentifierGenerator.create()
        var content = Content()
        var buffer = self.buffer

        let eomIndex = buffer.firstRange(of: "<eom>")?.lowerBound
        if let eomIndex {
            let remainingCount = buffer.distance(from: eomIndex, to: buffer.endIndex)
            buffer.removeLast(remainingCount)
            content.eom = true
        }

        while !buffer.isEmpty {
            do {
                let tagNameMatch = try startOfXmlPattern.firstMatch(in: buffer)
                var markdownEndIndex = tagNameMatch?.range.lowerBound ?? buffer.endIndex

                if !content.eom && markdownEndIndex == buffer.endIndex && buffer.last == "<" {
                    markdownEndIndex = buffer.index(before: markdownEndIndex)
                }

                let length = buffer.distance(from: buffer.startIndex, to: markdownEndIndex)
                if length > 0 {
                    let markdown = buffer.prefix(upTo: markdownEndIndex)
                    let finished = markdownEndIndex != buffer.endIndex
                    content.append(markdown: markdown, finished: finished, ids: &ids)
                    buffer.removeSubrange(buffer.startIndex..<markdownEndIndex)
                }

                guard let tagNameInput = tagNameMatch?.output.1 else { break }
                let tagName = String(tagNameInput)
                var endOfXml = buffer.firstRange(of: endOfCompactXmlPattern(tagName: tagName))?.upperBound
                    ?? buffer.firstRange(of: endOfXmlPattern(tagName: tagName))?.upperBound
                    ?? buffer.endIndex

                if endOfXml >= buffer.endIndex {
                    endOfXml = buffer.index(before: buffer.endIndex)
                }

                let rawXml = buffer.prefix(through: endOfXml)
                buffer.removeSubrange(buffer.startIndex...endOfXml)

                let xmlParser = XmlParser(string: rawXml)
                let (elements, error) = xmlParser.parse()
                let finished = endOfXml != buffer.endIndex
                if let elements {
                    content.append(xml: elements, finished: finished, ids: &ids)
                }
                if let error {
                    throw error
                }
            } catch {
                content.append(error: error, finished: !buffer.isEmpty, ids: &ids)
                break
            }
        }

        return content
    }

    private let startOfXmlPattern = /<(\w+)\b/
    private func endOfCompactXmlPattern(tagName: String) -> Regex<AnyRegexOutput> {
        try! Regex("<\(tagName)\\b[^>]*/>")
    }
    private func endOfXmlPattern(tagName: String) -> Regex<AnyRegexOutput> {
        try! Regex("</\(tagName)>")
    }
}
