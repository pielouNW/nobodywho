struct InputBuilder {
    var input: StreamContent

    func add(input: Input, content: inout StreamContent, ids: inout IdentifierGenerator) {
        content.items.append(StreamContent.Item(ids: &ids, value: .input(input)))
    }

    func build(ids nestedIds: IdentifierGenerator) -> StreamContent {
        var ids = nestedIds
        var content = input
        content.items.removeAll(keepingCapacity: true)

        for item in input.items {
            switch item.value {
            case .xml(let xml):
                for element in xml {
                    let parsed = InputParser(element: element).parse(ids: &ids)
                    if let parsed {
                        add(input: parsed, content: &content, ids: &ids)
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
}
