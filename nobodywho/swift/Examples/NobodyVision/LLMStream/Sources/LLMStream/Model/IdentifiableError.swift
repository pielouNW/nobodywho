import Foundation

public struct IdentifiableError: Identifiable, Equatable, Sendable {
    public var id: String
    public var underlyingError: Error

    init(ids: inout IdentifierGenerator, underlyingError: Error) {
        self.id = ids()
        self.underlyingError = underlyingError
    }

    public static func == (lhs: IdentifiableError, rhs: IdentifiableError) -> Bool {
        lhs.id == rhs.id
    }

    public func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
}
