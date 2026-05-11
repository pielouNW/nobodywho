import Foundation

public struct Options: Equatable, Sendable {
    public var page = Page()

    public struct Page: Equatable, Sendable {
        public var control: PageControlValue?
    }
}

public enum PageControlValue: String, Equatable, Sendable {
    case submit
}

struct OptionBuilder {
    var input: StreamContent

    func build(ids nestedIds: IdentifierGenerator) -> StreamContent {
        var ids = nestedIds
        var content = input
        content.items.removeAll(keepingCapacity: true)

        for item in input.items {
            switch item.value {
            case .xml(let xml):
                for element in xml {
                    let parsed = OptionParser(element: element).parse(ids: &ids, options: &content.options)
                    if !parsed {
                        content.items.append(item)
                    }
                }
            default:
                content.items.append(item)
            }
        }

        return content
    }
}
