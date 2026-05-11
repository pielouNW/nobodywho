import Foundation

struct MarkdownBuilder {
    var rawMarkdown: any StringProtocol

    struct Content {
        var items: [StreamContentItem<StreamItemValue>] = []

        mutating func append(table: MarkdownTable, ids: inout any IdentifierGenerator) {
            items.append(StreamContentItem<StreamItemValue>(ids: &ids, value: .markdownTable(table)))
        }

        mutating func append(markdown: MarkdownEntry, ids: inout any IdentifierGenerator) {
            items.append(StreamContentItem<StreamItemValue>(ids: &ids, value: .markdown(markdown)))
        }
    }

    mutating func cleanup() {
        rawMarkdown = rawMarkdown.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    func build(ids nestedIds: IdentifierGenerator) -> Content {
        var ids = nestedIds
        var content = Content()
        let segments = splitIntoSegments(String(rawMarkdown))
        var markdownBuilder = MarkdownEntryBuilder()

        for segment in segments {
            switch segment {
            case .text(let text):
                if markdownBuilder.rawText.isEmpty {
                    markdownBuilder.rawText = text
                } else {
                    markdownBuilder.rawText += "\n\n" + text
                }
            case .table(let tableText):
                if let entry = markdownBuilder.build() {
                    content.append(markdown: entry, ids: &ids)
                    markdownBuilder = MarkdownEntryBuilder()
                }
                if let table = MarkdownTableBuilder(raw: tableText).build(ids: ids.nested()) {
                    content.append(table: table, ids: &ids)
                }
            }
        }

        markdownBuilder.cleanup()
        if let entry = markdownBuilder.build() {
            content.append(markdown: entry, ids: &ids)
        }

        return content
    }

    private enum Segment {
        case text(String)
        case table(String)
    }

    private func splitIntoSegments(_ text: String) -> [Segment] {
        let lines = text.components(separatedBy: "\n")
        var segments: [Segment] = []
        var currentTextLines: [String] = []
        var currentTableLines: [String] = []
        var inTable = false

        for line in lines {
            let isTableLine = line.trimmingCharacters(in: .whitespaces).hasPrefix("|")

            if isTableLine {
                if !inTable {
                    let flushed = currentTextLines.joined(separator: "\n").trimmingCharacters(in: .whitespacesAndNewlines)
                    if !flushed.isEmpty {
                        segments.append(.text(flushed))
                    }
                    currentTextLines = []
                    inTable = true
                }
                currentTableLines.append(line)
            } else {
                if inTable {
                    segments.append(.table(currentTableLines.joined(separator: "\n")))
                    currentTableLines = []
                    inTable = false
                }
                currentTextLines.append(line)
            }
        }

        if inTable {
            segments.append(.table(currentTableLines.joined(separator: "\n")))
        } else {
            let flushed = currentTextLines.joined(separator: "\n").trimmingCharacters(in: .whitespacesAndNewlines)
            if !flushed.isEmpty {
                segments.append(.text(flushed))
            }
        }

        return segments
    }
}
