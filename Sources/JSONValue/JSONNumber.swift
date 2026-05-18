import Foundation

/// A JSON number stored as either an integer or a floating-point value.
///
/// JSON defines a single `number` type; Swift needs distinct representations for
/// integers and fractions. `JSONNumber` keeps that distinction after decoding.
public enum JSONNumber: Sendable {
    case int(Int64)
    case double(Double)
}

extension JSONNumber: Codable {
    public init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()

        if let value = try? container.decode(Int64.self) {
            self = .int(value)
        } else if let value = try? container.decode(Double.self) {
            self = .double(value)
        } else if let value = try? container.decode(Int.self) {
            self = .int(Int64(value))
        } else {
            throw DecodingError.unsupportedJSONValue(in: container)
        }
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()

        switch self {
        case .int(let value):
            try container.encode(value)
        case .double(let value):
            try container.encode(value)
        }
    }
}

extension JSONNumber: Equatable {
    public static func == (lhs: JSONNumber, rhs: JSONNumber) -> Bool {
        switch (lhs, rhs) {
        case (.int(let left), .int(let right)):
            return left == right
        case (.double(let left), .double(let right)):
            return left == right
        case (.int(let left), .double(let right)):
            return numericEqual(int: left, double: right)
        case (.double(let left), .int(let right)):
            return numericEqual(int: right, double: left)
        }
    }

    private static func numericEqual(int: Int64, double: Double) -> Bool {
        guard double.isFinite else { return false }
        let rounded = double.rounded()
        guard rounded == double else { return false }
        guard rounded >= Double(Int64.min), rounded <= Double(Int64.max) else { return false }
        return Int64(rounded) == int
    }
}

public extension JSONNumber {
    var intValue: Int? {
        switch self {
        case .int(let value):
            return Int(exactly: value)
        case .double(let value):
            return Int(exactly: value)
        }
    }

    var int64Value: Int64? {
        switch self {
        case .int(let value):
            return value
        case .double(let value):
            guard value.isFinite, value.rounded() == value else { return nil }
            guard value >= Double(Int64.min), value <= Double(Int64.max) else { return nil }
            return Int64(value)
        }
    }

    var doubleValue: Double {
        switch self {
        case .int(let value):
            return Double(value)
        case .double(let value):
            return value
        }
    }
}
