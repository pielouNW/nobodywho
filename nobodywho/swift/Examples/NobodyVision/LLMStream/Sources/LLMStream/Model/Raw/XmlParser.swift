import Foundation

final class XmlParser: NSObject, XMLParserDelegate {
    private var current: RawXmlElement?
    let string: any StringProtocol

    init(string: some StringProtocol) {
        self.string = string
    }

    func parse() -> ([XmlElement]?, Error?) {
        let parser = XMLParser(data: Data(string.utf8))
        parser.shouldResolveExternalEntities = false
        parser.externalEntityResolvingPolicy = .never
        parser.delegate = self
        let root = RawXmlElement()
        current = root
        parser.parse()
        current = nil
        let children = root.build().children
        return (children, parser.parserError)
    }

    public func parser(
        _ parser: XMLParser,
        didEndElement elementName: String,
        namespaceURI: String?,
        qualifiedName qName: String?
    ) {
        self.current = self.current?.pop(elementName)
    }

    public func parser(
        _ parser: XMLParser,
        didStartElement elementName: String,
        namespaceURI: String?,
        qualifiedName qName: String?,
        attributes attributeDict: [String: String] = [:]
    ) {
        self.current = self.current?.push(elementName)
        self.current?.attributes = attributeDict
    }

    func parser(_ parser: XMLParser, foundCharacters string: String) {
        self.current?.text += string
    }
}

public struct XmlElement: Equatable {
    public var name: String?
    public var text: String = ""
    public var attributes: [String: String] = [:]
    public var children: [XmlElement] = []
    public var completed: Bool = false
}

extension XmlElement: Sendable {}

private final class RawXmlElement {
    weak var parent: RawXmlElement?
    var name: String?
    var text: String = ""
    var attributes: [String: String] = [:]
    var children: [RawXmlElement] = []
    var completed: Bool = false

    init(_ parent: RawXmlElement? = nil, name: String = "") {
        self.parent = parent
        self.name = name
    }

    func push(_ elementName: String) -> RawXmlElement {
        let child = RawXmlElement(self, name: elementName)
        children.append(child)
        return child
    }

    func pop(_ elementName: String) -> RawXmlElement? {
        assert(elementName == self.name)
        completed = true
        return self.parent
    }

    func build() -> XmlElement {
        var element = XmlElement()
        element.name = name
        element.text = text
        element.attributes = attributes
        element.children = children.map { $0.build() }
        element.completed = completed
        return element
    }
}
