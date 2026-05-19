import Foundation
import Testing
@testable import JSONValue

@Test func decodesJSONPrimitives() throws {
    let json = """
    {
      "nullField": null,
      "boolField": true,
      "intField": 1274,
      "doubleField": 0.23851851851851846,
      "stringField": "faceAppeared",
      "arrayField": [1, "a"],
      "objectField": { "nested": 42 }
    }
    """
    let value = try JSONDecoder().decode(JSONValue.self, from: Data(json.utf8))

    #expect(value["nullField"] == .null)
    #expect(value["boolField"] == .bool(true))
    #expect(value["intField"] == .number(.int(1274)))
    #expect(value["doubleField"] == .number(.double(0.23851851851851846)))
    #expect(value["stringField"] == .string("faceAppeared"))
    #expect(value["arrayField"] == .array([.number(.int(1)), .string("a")]))
    #expect(value["objectField"] == .object(["nested": .number(.int(42))]))
}

@Test func encodesNumbersPreservingStorage() throws {
    let value: JSONValue = [
        "count": .number(.int(20_678_750)),
        "ratio": .number(.double(0.5)),
    ]

    let data = try JSONEncoder().encode(value)
    let object = try JSONSerialization.jsonObject(with: data) as? [String: Any]

    #expect(object?["count"] as? Int == 20_678_750)
    #expect(object?["ratio"] as? Double == 0.5)
}

@Test func integerAndDoubleLiterals() {
    let intLiteral: JSONValue = 42
    let doubleLiteral: JSONValue = 3.14

    #expect(intLiteral == .number(.int(42)))
    #expect(doubleLiteral == .number(.double(3.14)))
}

@Test func compatibilityFactoriesMatchLiterals() {
    #expect(JSONValue.integer(1274) == .number(.int(1274)))
    #expect(JSONValue.double(0.25) == .number(.double(0.25)))
}

@Test func accessorsReadNumbersRegardlessOfStorage() {
    let intNumber: JSONValue = .number(.int(1274))
    let doubleWhole: JSONValue = .number(.double(1274))
    let fraction: JSONValue = .number(.double(0.23851851851851846))

    #expect(intNumber.intValue == 1274)
    #expect(intNumber.int64Value == 1274)
    #expect(intNumber.doubleValue == 1274)

    #expect(doubleWhole.intValue == 1274)
    #expect(doubleWhole.int64Value == 1274)
    #expect(doubleWhole.doubleValue == 1274)

    #expect(fraction.intValue == nil)
    #expect(fraction.int64Value == nil)
    #expect(fraction.doubleValue == 0.23851851851851846)
}

@Test func jsonNumberEquatableTreatsWholeDoublesAsIntegers() {
    #expect(JSONNumber.int(42) == JSONNumber.double(42))
    #expect(JSONNumber.int(42) != JSONNumber.double(42.5))
    #expect(JSONValue.number(.int(42)) == JSONValue.number(.double(42)))
}

@Test func roundTripQueryStyleRow() throws {
    let row: JSONValue = [
        "cloud.domain": 1274,
        "@count": 42,
        "rectangle.h": 0.23851851851851846,
        "detector.type": "faceAppeared",
    ]

    let data = try JSONEncoder().encode(row)
    let decoded = try JSONDecoder().decode(JSONValue.self, from: data)

    #expect(decoded["cloud.domain"]?.intValue == 1274)
    #expect(decoded["@count"]?.intValue == 42)
    #expect(decoded["rectangle.h"]?.doubleValue == 0.23851851851851846)
    #expect(decoded["detector.type"]?.stringValue == "faceAppeared")
    #expect(decoded == row)
}

@Test func dynamicMemberLookupReadsNestedFields() {
    let value: JSONValue = [
        "filter": [
            "period": ["type": "today"],
        ],
    ]

    #expect(value.filter?["period"]?["type"]?.stringValue == "today")
}

@Test func decodesLargeInteger() throws {
    let json = #"{"count":20678750}"#
    let value = try JSONDecoder().decode(JSONValue.self, from: Data(json.utf8))

    #expect(value["count"] == .number(.int(20_678_750)))
    #expect(value["count"]?.int64Value == 20_678_750)
}

@Test func decodePrimitiveTypes() throws {
    #expect(try JSONValue.bool(true).decode(Bool.self) == true)
    #expect(try JSONValue.string("faceAppeared").decode(String.self) == "faceAppeared")
    #expect(try JSONValue.number(.int(1274)).decode(Int.self) == 1274)
    #expect(try JSONValue.number(.double(0.25)).decode(Double.self) == 0.25)
    #expect(try JSONValue.null.decode(String?.self) == nil)
}

@Test func decodeDecodableStruct() throws {
    struct Row: Decodable, Equatable {
        let cloudDomain: Int
        let detectorType: String

        enum CodingKeys: String, CodingKey {
            case cloudDomain = "cloud.domain"
            case detectorType = "detector.type"
        }
    }

    let value: JSONValue = [
        "cloud.domain": 1274,
        "detector.type": "faceAppeared",
    ]

    #expect(
        try value.decode(Row.self)
            == Row(cloudDomain: 1274, detectorType: "faceAppeared")
    )
}

@Test func decodeArray() throws {
    let numbers: JSONValue = [.number(.int(1)), .number(.int(2)), .number(.int(3))]
    let strings: JSONValue = [.string("a"), .string("b")]
    let mixed: JSONValue = [.number(.int(1)), .string("a")]

    #expect(try numbers.decode([Int].self) == [1, 2, 3])
    #expect(try strings.decode([String].self) == ["a", "b"])
    #expect((try mixed.decode([JSONValue].self)) == [.number(.int(1)), .string("a")])
}

@Test func decodeThrowsForTypeMismatch() throws {
    let value: JSONValue = .string("not a number")

    #expect(throws: (any Error).self) {
        try value.decode(Int.self)
    }
}

@Test func initFromEncodablePrimitiveTypes() throws {
    let boolValue = try JSONValue(true)
    let stringValue = try JSONValue("faceAppeared")
    let intValue = try JSONValue(1274)
    let doubleValue = try JSONValue(0.25)
    let nullValue = try JSONValue(Optional<String>.none)

    #expect(boolValue == .bool(true))
    #expect(stringValue == .string("faceAppeared"))
    #expect(intValue == .number(.int(1274)))
    #expect(doubleValue == .number(.double(0.25)))
    #expect(nullValue == .null)
}

@Test func initFromEncodableStruct() throws {
    struct Row: Encodable, Equatable {
        let cloudDomain: Int
        let detectorType: String

        enum CodingKeys: String, CodingKey {
            case cloudDomain = "cloud.domain"
            case detectorType = "detector.type"
        }
    }

    let expected: JSONValue = [
        "cloud.domain": 1274,
        "detector.type": "faceAppeared",
    ]

    #expect(
        try JSONValue(Row(cloudDomain: 1274, detectorType: "faceAppeared"))
            == expected
    )
}

@Test func initFromEncodableArray() throws {
    #expect(try JSONValue([1, 2, 3]) == .array([.number(.int(1)), .number(.int(2)), .number(.int(3))]))
    #expect(try JSONValue(["a", "b"]) == .array([.string("a"), .string("b")]))
}

@Test func initFromEncodableRoundTripsWithDecode() throws {
    struct Row: Codable, Equatable {
        let cloudDomain: Int
        let detectorType: String

        enum CodingKeys: String, CodingKey {
            case cloudDomain = "cloud.domain"
            case detectorType = "detector.type"
        }
    }

    let model = Row(cloudDomain: 1274, detectorType: "faceAppeared")
    let value = try JSONValue(model)

    #expect(try value.decode(Row.self) == model)
}

@Test func urlRoundTripsThroughBridgingWithoutEscapedSlashes() throws {
    let url = URL(string: "https://example.com/api/v1/items")!
    let value = try JSONValue(url)

    #expect(value == .string("https://example.com/api/v1/items"))
    #expect(try value.decode(URL.self) == url)

    let encoder = JSONEncoder()
    encoder.outputFormatting = .withoutEscapingSlashes
    let wireJSON = String(decoding: try encoder.encode(value), as: UTF8.self)
    #expect(!wireJSON.contains("\\/"))
}
