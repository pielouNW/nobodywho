import Foundation

struct OptionParser {
    var element: XmlElement

    func parse(ids: inout IdentifierGenerator, options: inout Options) -> Bool {
        guard element.name == "SafeOption" else { return false }
        let name = element.attributes["name"]
        let value = element.attributes["value"]
        guard let name, let value else { return false }

        switch name {
        case "page.control":
            guard let data = PageControlValue(rawValue: value) else { return false }
            options.page.control = data
            return true
        default:
            return false
        }
    }
}
