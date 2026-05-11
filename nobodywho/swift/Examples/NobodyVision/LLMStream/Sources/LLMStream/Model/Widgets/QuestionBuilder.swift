import Foundation

struct QuestionBuilder {
    var input: StreamContent

    func add(question: Question, content: inout StreamContent, ids: inout IdentifierGenerator) {
        let last = content.items.last
        switch last?.value {
        case .questionGroup(var group):
            group.questions.append(.init(ids: &ids, value: question))
            content.replaceLastValue(.questionGroup(group))
        case .question(let previousQuestion):
            let questions = [previousQuestion, question].map { StreamContentItem(ids: &ids, value: $0) }
            let group = QuestionGroup(questions: questions)
            content.items.removeLast()
            add(group: group, content: &content, ids: &ids)
        default:
            content.items.append(StreamContent.Item(ids: &ids, value: .question(question)))
        }
    }

    func add(group: QuestionGroup, content: inout StreamContent, ids: inout IdentifierGenerator) {
        guard group.title == nil,
              let last = content.items.last,
              case .markdown(let entry) = last.value,
              let headingText = extractLastHeading(from: entry.content)
        else {
            content.items.append(StreamContent.Item(ids: &ids, value: .questionGroup(group)))
            return
        }

        let newEntry = entry.droppingLastHeading()
        if let newEntry {
            content.replaceLastValue(.markdown(newEntry))
        }

        var newGroup = group
        newGroup.title = headingText
        if newEntry == nil {
            content.replaceLastValue(.questionGroup(newGroup))
        } else {
            content.items.append(StreamContent.Item(ids: &ids, value: .questionGroup(newGroup)))
        }
    }

    func build(ids nestedIds: IdentifierGenerator) -> StreamContent {
        var ids = nestedIds
        var content = input
        content.items.removeAll(keepingCapacity: true)

        for item in input.items {
            switch item.value {
            case .xml(let xml):
                for element in xml {
                    if let question = QuestionParser(element: element).parse(ids: &ids) {
                        add(question: question, content: &content, ids: &ids)
                    } else if let group = QuestionGroupParser(element: element).parse(ids: &ids) {
                        add(group: group, content: &content, ids: &ids)
                    } else {
                        content.items.append(item)
                    }
                }
            default:
                content.items.append(item)
            }
        }

        return content
    }

    private func extractLastHeading(from text: String) -> String? {
        let lines = text.components(separatedBy: "\n")
        guard let lastNonEmpty = lines.last(where: { !$0.trimmingCharacters(in: .whitespaces).isEmpty })
        else { return nil }
        let trimmed = lastNonEmpty.trimmingCharacters(in: .whitespaces)
        guard let range = trimmed.range(of: #"^#+\s+"#, options: .regularExpression) else { return nil }
        return String(trimmed[range.upperBound...])
    }
}
