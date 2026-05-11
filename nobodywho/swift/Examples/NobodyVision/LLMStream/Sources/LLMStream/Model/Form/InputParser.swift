import Foundation

public struct Input: Equatable, Sendable {
    public let name: String
    public let value: String?
    public let content: InputContent
}

public enum InputContent: Equatable, Sendable {
    case hidden
    case button(name: String)
    case appearance(text: String, runImmediately: Bool, ready: Bool)
}

struct InputParser {
    var element: XmlElement

    func parse(ids: inout IdentifierGenerator) -> Input? {
        guard element.name == "SafeInput" else { return nil }
        let name = element.attributes["name"]
        let rawType = element.attributes["type"]
        guard let name, let rawType else { return nil }

        switch rawType {
        case "hidden":
            return .init(name: name, value: element.attributes["value"], content: .hidden)
        case "button":
            let label = element.text
            guard !label.isEmpty else { return nil }
            return .init(name: name, value: element.attributes["value"], content: .button(name: label))
        case "appearance":
            let runImmediately = element.attributes["runImmediately"]?.lowercased() == "true"
            return .init(
                name: name,
                value: element.attributes["value"],
                content: .appearance(text: element.text, runImmediately: runImmediately, ready: element.completed)
            )
        default:
            return nil
        }
    }
}
