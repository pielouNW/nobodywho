import Foundation

public struct QuestionGroup: Equatable, Sendable {
    public var title: String?
    public var questions: [StreamContentItem<Question>] = []
}

struct QuestionGroupParser {
    var element: XmlElement

    func parse(ids: inout IdentifierGenerator) -> QuestionGroup? {
        guard element.name == "SafeQuestionGroup" else { return nil }
        let title = element.attributes["title"]
        let questions = element.children.compactMap { QuestionParser(element: $0).parse(ids: &ids) }
        guard !questions.isEmpty else { return nil }
        let items = questions.map { StreamContentItem(ids: &ids, value: $0) }
        return QuestionGroup(title: title, questions: items)
    }
}
