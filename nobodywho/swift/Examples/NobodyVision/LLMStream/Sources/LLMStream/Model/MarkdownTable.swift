import Foundation

public struct MarkdownTable: Equatable, Sendable {
    public var cards: [StreamContentItem<Card>] = []
    public var maxRowCount: Int = 0

    public struct Card: Equatable, Sendable {
        public var rows: [StreamContentItem<Row>]
    }

    public struct Row: Equatable, Sendable {
        public var title: RowContent?
        public var value: RowContent?
    }

    public enum RowContent: Equatable, Sendable {
        case cell(CellContent)
    }

    public struct CellContent: Equatable, Sendable {
        public var value: String
    }
}

struct MarkdownTableBuilder {
    var raw: String

    func build(ids nestedIds: any IdentifierGenerator) -> MarkdownTable? {
        var ids = nestedIds
        let lines = raw.components(separatedBy: "\n")
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }

        guard lines.count >= 2 else { return nil }

        let rows = lines.compactMap { parseCells(from: $0) }
        guard rows.count >= 2 else { return nil }

        let isSeparator = rows[1].allSatisfy { cell in
            cell.trimmingCharacters(in: CharacterSet(charactersIn: "-: ")).isEmpty
        }
        guard isSeparator else { return nil }

        let headings = rows[0].map { MarkdownTable.RowContent.cell(.init(value: $0)) }
        var table = MarkdownTable()
        table.maxRowCount = headings.count

        for row in rows.dropFirst(2) {
            var card = MarkdownTable.Card(rows: [])
            for (index, cell) in row.enumerated() {
                var tableRow = MarkdownTable.Row()
                tableRow.title = headings[safe: index]
                tableRow.value = .cell(.init(value: cell))
                card.rows.append(.init(ids: &ids, value: tableRow))
            }
            table.cards.append(.init(ids: &ids, value: card))
        }

        if table.cards.isEmpty {
            var card = MarkdownTable.Card(rows: [])
            for heading in headings {
                var row = MarkdownTable.Row()
                row.title = heading
                row.value = .cell(.init(value: ""))
                card.rows.append(.init(ids: &ids, value: row))
            }
            table.cards.append(.init(ids: &ids, value: card))
        }

        return table
    }

    private func parseCells(from line: String) -> [String]? {
        guard line.hasPrefix("|") else { return nil }
        var parts = line.components(separatedBy: "|")
        if parts.first?.trimmingCharacters(in: .whitespaces).isEmpty == true {
            parts.removeFirst()
        }
        if parts.last?.trimmingCharacters(in: .whitespaces).isEmpty == true {
            parts.removeLast()
        }
        return parts.map { $0.trimmingCharacters(in: .whitespaces) }
    }
}
