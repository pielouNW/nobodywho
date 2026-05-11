import Foundation

public struct MarkdownEntry: Equatable, Sendable {
    public var content: String
    public var collapsed: String?
    public var collapsable: Bool { collapsed != nil }

    func droppingLastHeading() -> MarkdownEntry? {
        var lines = content.components(separatedBy: "\n")
        while let last = lines.last, last.trimmingCharacters(in: .whitespaces).isEmpty {
            lines.removeLast()
        }
        guard !lines.isEmpty else { return nil }
        lines.removeLast()
        let text = lines.joined(separator: "\n").trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return nil }
        return MarkdownEntry(content: text, collapsed: nil)
    }
}

struct MarkdownEntryBuilder {
    var rawText: String = ""

    mutating func cleanup() {
        var lines = rawText.components(separatedBy: "\n")
        while let last = lines.last {
            let trimmed = last.trimmingCharacters(in: .whitespaces)
            guard trimmed.contains("|") else { break }
            lines.removeLast()
        }
        rawText = lines.joined(separator: "\n")
    }

    func build() -> MarkdownEntry? {
        let text = rawText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return nil }
        var collapsed = makeCollapsed(from: text)
        if text.count <= (collapsed?.count ?? 0) + 20 {
            collapsed = nil
        }
        return MarkdownEntry(content: text, collapsed: collapsed)
    }

    private func makeCollapsed(from text: String) -> String? {
        let lines = text.components(separatedBy: "\n")
        var sections: [[String]] = []
        var currentSection: [String] = []

        for line in lines {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            let isHeading = trimmed.range(of: #"^#+\s"#, options: .regularExpression) != nil
            if isHeading && !currentSection.isEmpty {
                sections.append(currentSection)
                currentSection = [line]
            } else {
                currentSection.append(line)
            }
        }
        if !currentSection.isEmpty {
            sections.append(currentSection)
        }

        var resultParts: [String] = []
        var didTruncateAny = false

        for sectionLines in sections {
            var resultLines: [String] = []
            var inParagraph = false
            var didTruncate = false
            var i = 0

            while i < sectionLines.count {
                let line = sectionLines[i]
                let trimmed = line.trimmingCharacters(in: .whitespaces)
                let isHeading = trimmed.range(of: #"^#+\s"#, options: .regularExpression) != nil

                if isHeading {
                    resultLines.append(line)
                    i += 1
                } else if !inParagraph && trimmed.isEmpty {
                    i += 1
                } else if !inParagraph && !trimmed.isEmpty {
                    inParagraph = true
                    resultLines.append(line)
                    i += 1
                } else if inParagraph && trimmed.isEmpty {
                    let remaining = sectionLines[(i + 1)...]
                    if !remaining.allSatisfy({ $0.trimmingCharacters(in: .whitespaces).isEmpty }) {
                        didTruncate = true
                        didTruncateAny = true
                    }
                    break
                } else {
                    resultLines.append(line)
                    i += 1
                }
            }

            if resultLines.count < sectionLines.count && !didTruncate {
                didTruncate = true
                didTruncateAny = true
            }

            var sectionStr = resultLines.joined(separator: "\n")
            if didTruncate {
                sectionStr += " .."
            }
            resultParts.append(sectionStr)
        }

        guard didTruncateAny else { return nil }
        return resultParts.joined(separator: "\n\n")
    }
}
