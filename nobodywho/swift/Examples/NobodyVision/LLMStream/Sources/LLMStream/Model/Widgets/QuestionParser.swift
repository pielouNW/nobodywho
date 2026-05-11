import Foundation

public struct Question: Equatable, Sendable {
    public var text: String
}

struct QuestionParser {
    var element: XmlElement

    func parse(ids: inout IdentifierGenerator) -> Question? {
        guard element.name == "SafeQuestion", !element.text.isEmpty else { return nil }
        return Question(text: element.text)
    }
}
