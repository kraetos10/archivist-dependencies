import Foundation

/// A pending child-mode PIN check, presented as a sheet by the add-channel
/// and add-playlist forms. `Purpose` says which action runs once the PIN is
/// confirmed.
public struct ChildModePinRequest: Equatable, Identifiable, Sendable {
    public enum Purpose: Equatable, Sendable {
        case subscribe
        case createCustom
    }

    public let expectedPin: String
    public let purpose: Purpose

    public var id: Purpose { purpose }

    public init(
        expectedPin: String,
        purpose: Purpose
    ) {
        self.expectedPin = expectedPin
        self.purpose = purpose
    }
}
