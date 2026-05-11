import Foundation

public struct StreamContent: Equatable, Sendable {
    public var items: [Item] = []
    public var finished: Bool = false
    public var errors: [IdentifiableError] = []
    public var options = Options()

    public typealias Item = StreamContentItem<StreamItemValue>

    mutating func replaceLastValue(_ newValue: StreamItemValue) {
        items[safe: items.count - 1]?.value = newValue
    }

    public func inputs(submit: Input? = nil) -> [String: String] {
        var form: [String: String] = [:]
        for item in items {
            switch item.value {
            case .input(let input):
                switch input.content {
                case .hidden:
                    form[input.name] = input.value
                case .button where input.name == submit?.name:
                    form[input.name] = input.value
                default:
                    continue
                }
            default:
                continue
            }
        }
        return form
    }
}

public struct StreamContentItem<Value: Equatable>: Identifiable, Equatable {
    public var id: String
    public var value: Value

    init(ids: inout IdentifierGenerator, value: Value) {
        self.id = ids()
        self.value = value
    }
}

extension StreamContentItem: Sendable where Value: Sendable {}

public enum StreamItemValue: Equatable, Sendable {
    case markdown(MarkdownEntry)
    case markdownTable(MarkdownTable)
    case question(Question)
    case questionGroup(QuestionGroup)
    case xml([XmlElement])
    case widget(Widget)
    case container(ContainerWidget)
    case input(Input)
}
