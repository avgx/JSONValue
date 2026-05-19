import Foundation

/// A transport type for arbitrary JSON values.
@dynamicMemberLookup
public enum JSONValue: Codable, Equatable, Sendable {
    case null
    case bool(Bool)
    case string(String)
    case number(JSONNumber)
    case array([JSONValue])
    case object([String: JSONValue])

    public init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()

        if container.decodeNil() {
            self = .null
        } else if let value = try? container.decode(Bool.self) {
            self = .bool(value)
        } else if let value = try? container.decode(Int.self) {
            self = .number(.int(Int64(value)))
        } else if let value = try? container.decode(Int64.self) {
            self = .number(.int(value))
        } else if let value = try? container.decode(Double.self) {
            self = .number(.double(value))
        } else if let value = try? container.decode(String.self) {
            self = .string(value)
        } else if let value = try? container.decode([String: JSONValue].self) {
            self = .object(value)
        } else if let value = try? container.decode([JSONValue].self) {
            self = .array(value)
        } else {
            throw DecodingError.unsupportedJSONValue(in: container)
        }
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()

        switch self {
        case .null:
            try container.encodeNil()
        case .bool(let value):
            try container.encode(value)
        case .string(let value):
            try container.encode(value)
        case .number(let value):
            try container.encode(value)
        case .array(let value):
            try container.encode(value)
        case .object(let value):
            try container.encode(value)
        }
    }
}

// MARK: - Compatibility with `.integer` / `.double` top-level cases

public extension JSONValue {
    /// Builds a JSON integer value. Prefer literals (`42`) or `.number(.int(...))` in new code.
    static func integer(_ value: Int) -> JSONValue {
        .number(.int(Int64(value)))
    }

    /// Builds a JSON floating-point value. Prefer literals (`3.14`) or `.number(.double(...))` in new code.
    static func double(_ value: Double) -> JSONValue {
        .number(.double(value))
    }
}

public extension JSONValue {
    subscript(key: String) -> JSONValue? {
        guard case .object(let object) = self else {
            return nil
        }

        return object[key]
    }

    subscript(index: Int) -> JSONValue? {
        guard case .array(let array) = self, array.indices.contains(index) else {
            return nil
        }

        return array[index]
    }

    subscript(dynamicMember member: String) -> JSONValue? {
        self[member]
    }

    var boolValue: Bool? {
        if case .bool(let value) = self { return value }
        return nil
    }

    var stringValue: String? {
        if case .string(let value) = self { return value }
        return nil
    }

    var intValue: Int? {
        guard case .number(let value) = self else { return nil }
        return value.intValue
    }

    var int64Value: Int64? {
        guard case .number(let value) = self else { return nil }
        return value.int64Value
    }

    var doubleValue: Double? {
        guard case .number(let value) = self else { return nil }
        return value.doubleValue
    }

    var numberValue: JSONNumber? {
        if case .number(let value) = self { return value }
        return nil
    }

    var arrayValue: [JSONValue]? {
        if case .array(let value) = self { return value }
        return nil
    }

    var objectValue: [String: JSONValue]? {
        if case .object(let value) = self { return value }
        return nil
    }
}

extension JSONValue: ExpressibleByStringLiteral {
    public init(stringLiteral value: String) {
        self = .string(value)
    }
}

extension JSONValue: ExpressibleByExtendedGraphemeClusterLiteral {
    public init(extendedGraphemeClusterLiteral value: String) {
        self = .string(value)
    }
}

extension JSONValue: ExpressibleByUnicodeScalarLiteral {
    public init(unicodeScalarLiteral value: String) {
        self = .string(value)
    }
}

extension JSONValue: ExpressibleByIntegerLiteral {
    public init(integerLiteral value: Int) {
        self = .number(.int(Int64(value)))
    }
}

extension JSONValue: ExpressibleByFloatLiteral {
    public init(floatLiteral value: Double) {
        self = .number(.double(value))
    }
}

extension JSONValue: ExpressibleByBooleanLiteral {
    public init(booleanLiteral value: Bool) {
        self = .bool(value)
    }
}

extension JSONValue: ExpressibleByArrayLiteral {
    public init(arrayLiteral elements: JSONValue...) {
        self = .array(elements)
    }
}

extension JSONValue: ExpressibleByDictionaryLiteral {
    public init(dictionaryLiteral elements: (String, JSONValue)...) {
        self = .object(Dictionary(uniqueKeysWithValues: elements))
    }
}

extension JSONValue: ExpressibleByNilLiteral {
    public init(nilLiteral: ()) {
        self = .null
    }
}

public extension DecodingError {
    static func unsupportedJSONValue(in container: any SingleValueDecodingContainer) -> DecodingError {
        .dataCorruptedError(in: container, debugDescription: "Unsupported JSON value")
    }
}

public extension JSONValue {
    func decode<T: Decodable>(_ type: T.Type) throws -> T {
        let encoder = JSONEncoder()
        encoder.outputFormatting = .withoutEscapingSlashes
        let data = try encoder.encode(self)
        return try JSONDecoder().decode(T.self, from: data)
    }
}

public extension JSONValue {
    init<T: Encodable>(_ value: T) throws {
        let encoder = JSONEncoder()
        encoder.outputFormatting = .withoutEscapingSlashes
        let data = try encoder.encode(value)
        self = try JSONDecoder().decode(JSONValue.self, from: data)
    }
}