protocol IdentifierGenerator {
    typealias ID = String
    mutating func callAsFunction() -> IdentifierGenerator.ID
    mutating func nested() -> IdentifierGenerator
}

struct IncrementalIdentifierGenerator: IdentifierGenerator {
    private var prefix: String
    private var id: Int = 0
    private var nestedId: Int = 0
    typealias ID = String

    private init(prefix: String) {
        self.prefix = prefix
    }

    static func create() -> IncrementalIdentifierGenerator {
        return IncrementalIdentifierGenerator(prefix: "")
    }

    mutating func callAsFunction() -> ID {
        nestedId = 0
        id += 1
        return "\(prefix)\(id)"
    }

    mutating func nested() -> IdentifierGenerator {
        nestedId += 1
        return Self(prefix: "\(prefix).\(id)-\(nestedId).")
    }
}
