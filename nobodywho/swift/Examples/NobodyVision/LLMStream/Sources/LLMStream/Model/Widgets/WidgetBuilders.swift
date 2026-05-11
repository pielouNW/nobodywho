import Foundation

public struct ContainerWidget: Equatable, Sendable {
    public var widgets: [StreamContentItem<Widget>] = []
    public var errors: [IdentifiableError] = []
}

public enum Widget: Equatable, Sendable {
    case trend(TrendWidget)
}

struct ContainerParser {
    var element: XmlElement

    func parse(ids: inout IdentifierGenerator) -> ContainerWidget? {
        guard element.name == "SafeContainer" else { return nil }
        var container = ContainerWidget()
        for child in element.children {
            do {
                if let widget = try WidgetParser(element: child).parse(ids: &ids) {
                    container.widgets.append(.init(ids: &ids, value: widget))
                }
            } catch {
                container.errors.append(IdentifiableError(ids: &ids, underlyingError: error))
            }
        }
        return container
    }
}

struct WidgetParser {
    var element: XmlElement

    func parse(ids: inout IdentifierGenerator) throws -> Widget? {
        guard element.name == "SafeViz",
              let name = element.attributes["name"]
        else { return nil }

        switch name {
        case "LIKB":
            if let trend = try TrendParser(element: element).parse(ids: &ids) {
                return .trend(trend)
            }
        default:
            break
        }
        return nil
    }
}

struct WidgetBuilder {
    var input: StreamContent

    func build(ids nestedIds: IdentifierGenerator) -> StreamContent {
        var ids = nestedIds
        var content = input
        content.items.removeAll(keepingCapacity: true)

        for item in input.items {
            switch item.value {
            case .xml(let elements):
                for element in elements {
                    do {
                        if var container = ContainerParser(element: element).parse(ids: &ids) {
                            content.errors.append(contentsOf: container.errors)
                            container.errors.removeAll()
                            content.items.append(.init(ids: &ids, value: .container(container)))
                        } else if let widget = try WidgetParser(element: element).parse(ids: &ids) {
                            content.items.append(.init(ids: &ids, value: .widget(widget)))
                        } else {
                            content.items.append(item)
                        }
                    } catch {
                        content.errors.append(IdentifiableError(ids: &ids, underlyingError: error))
                    }
                }
            default:
                content.items.append(item)
            }
        }

        return content
    }
}
