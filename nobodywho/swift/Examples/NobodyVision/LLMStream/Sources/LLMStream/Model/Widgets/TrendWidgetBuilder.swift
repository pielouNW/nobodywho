import Foundation

public struct TrendWidget: Equatable, Sendable, Decodable {
    public var riskScenarioName: String?
    public var trendData: [TrendData]?

    public struct TrendData: Equatable, Sendable, Decodable {
        public var eventLikelihood: Double?
        public var timestamp: Date?

        enum CodingKeys: String, CodingKey {
            case eventLikelihood
            case timestamp
        }

        public init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            eventLikelihood = try container.decodeIfPresent(Double.self, forKey: .eventLikelihood)
            timestamp = try? container.decodeIfPresent(Date.self, forKey: .timestamp)
        }
    }
}

struct TrendParser {
    var element: XmlElement

    func parse(ids nestedIds: inout IdentifierGenerator) throws -> TrendWidget? {
        let summaryElement = element.children.first { $0.name == "SafeVizSummary" }
        guard let summary = summaryElement?.text, !summary.isEmpty else { return TrendWidget() }
        let validJson: String
        if summaryElement?.completed == true {
            validJson = summary
        } else {
            validJson = JsonCompleter().complete(json: summary)
        }
        return try JSONDecoder.default.decode(TrendWidget.self, from: Data(validJson.utf8))
    }
}
