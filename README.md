# JSONValue

A small, dependency-free Swift type for arbitrary JSON values.

`JSONValue` is an `enum` that models only what JSON can represent: `null`, booleans, numbers, strings, arrays, and objects. It is designed for API responses with dynamic fields, query rows, preview arguments, and other payloads where a fixed `Codable` struct is impractical.

## Installation

```swift
dependencies: [
    .package(url: "https://github.com/avgx/JSONValue", branch: "main"),
],
targets: [
    .target(
        name: "YourTarget",
        dependencies: ["JSONValue"]
    ),
]
```

## Usage

```swift
import JSONValue

let row: [String: JSONValue] = [
    "event.id": "uuid-anonymized",
    "cloud.domain": 1274,
    "@count": 42,
]

let count = row["@count"]?.intValue
let domain = row["cloud.domain"]?.intValue

let filter: JSONValue = [
    "version": 0,
    "period": ["type": "today"],
]

let previewArgs: [JSONValue] = ["1 hour", "2026-05-18T00:00:00Z", 1000]
```

Supported conveniences:

- `Codable`, `Equatable`, `Sendable`
- `@dynamicMemberLookup` and subscripts for objects and arrays
- typed accessors: `stringValue`, `intValue`, `int64Value`, `doubleValue`, `numberValue`, `boolValue`, `arrayValue`, `objectValue`
- literals: `"text"`, `42`, `3.14`, `true`, `nil`, `["a", "b"]`, `["key": "value"]`
- bridging to and from `Codable` types (see below)

## Bridging to and from `Codable`

When part of the payload is dynamic (`JSONValue`) and part is a fixed model, convert across the boundary with `init(_:)` and `decode(_:)`:

```swift
struct Row: Codable, Equatable {
    let cloudDomain: Int
    let detectorType: String

    enum CodingKeys: String, CodingKey {
        case cloudDomain = "cloud.domain"
        case detectorType = "detector.type"
    }
}

// Encodable → JSONValue
let value = try JSONValue(Row(cloudDomain: 1274, detectorType: "faceAppeared"))
// same shape as a literal object:
// ["cloud.domain": 1274, "detector.type": "faceAppeared"]

// JSONValue → Decodable
let row = try value.decode(Row.self)
```

Primitives and collections work the same way:

```swift
try JSONValue(true)           // .bool(true)
try JSONValue("text")         // .string("text")
try JSONValue(42)             // .number(.int(42))
try JSONValue([1, 2, 3])      // .array([...])
try JSONValue(Optional<String>.none)  // .null

try JSONValue.bool(true).decode(Bool.self)  // true
```

Each call creates a fresh `JSONEncoder` and `JSONDecoder`. The encoder sets `outputFormatting` to `.withoutEscapingSlashes` so URL-like strings round-trip without `\/`. Other strategies (dates, key encoding) use Foundation defaults. Custom `CodingKeys` apply the same as in a normal `Codable` pipeline. Numbers follow the same int-vs-double rules as direct `JSONValue` decoding.

This is a convenience bridge, not a zero-cost path: each call encodes to `Data` and decodes again. For hot paths, prefer staying in `JSONValue` or decoding straight into your model from wire data.

## Numbers: `JSONNumber` and `.number`

JSON defines one `number` type. Earlier versions of this package exposed two top-level cases — `.integer(Int)` and `.double(Double)`. The current design uses a single case:

```swift
public enum JSONNumber: Equatable, Sendable, Codable {
    case int(Int64)
    case double(Double)
}

public enum JSONValue {
  // ...
  case number(JSONNumber)
}
```

### Why this shape

| Approach | Trade-off |
|----------|-----------|
| `.integer` + `.double` on `JSONValue` | Simple literals, but two top-level cases for one JSON type; `42` and `42.0` compared unequal in `==` |
| `.number(Double)` only | Minimal API, but large integers can lose precision |
| **`.number(JSONNumber)`** | Matches JSON semantics, keeps int vs fraction after decode, room to grow (e.g. `Decimal` later) |

`JSONNumber` uses `Int64` so large counts and IDs from API payloads stay exact. `JSONNumber.==` treats whole doubles as equal to their integer form (`42` == `42.0`), which makes tests and response diffing less surprising.

### Reading values (recommended)

Prefer accessors — they work no matter whether the decoder stored an int or a double:

```swift
row["@count"]?.intValue
row["rectangle.h"]?.doubleValue
row["cloud.domain"]?.int64Value
```

Pattern matching when you care about storage:

```swift
switch row["@count"] {
case .number(.int(let count)):
    ...
case .number(.double(let count)) where count.rounded() == count:
    ...
default:
    break
}
```

### Compatibility with `.integer` / `.double`

If you migrated from separate top-level cases, use this mapping:

| Before | After |
|--------|-------|
| `.integer(1274)` | `.number(.int(1274))` or literal `1274` |
| `.double(0.25)` | `.number(.double(0.25))` or literal `0.25` |
| `case .integer(let v):` | `case .number(.int(let v)):` |
| `case .double(let v):` | `case .number(.double(let v)):` |
| `JSONValue.integer(42)` in maps | still supported via `JSONValue.integer(_:)` |
| `JSONValue.double(0.5)` | still supported via `JSONValue.double(_:)` |

Factory helpers remain for explicit construction in higher-order calls:

```swift
values.map(JSONValue.integer(_:))
Clause(field: "cloud.domain", op: "eq", value: JSONValue.integer(1274))
```

Integer parameters can often use implicit literals:

```swift
Clause(field: field, op: "eq", value: domainId)  // domainId: Int
```

Accessors `intValue`, `doubleValue`, and `int64Value` behave the same as before; only `switch` patterns and direct case construction need updating.

## Why `JSONValue` instead of `AnyCodable`?

`AnyCodable` (and similar wrappers around `Any`) are convenient for quick decoding, but they trade type safety and predictability for flexibility. `JSONValue` is a better default when JSON is part of your public API.

### 1. JSON-only domain

`JSONValue` can represent only valid JSON shapes.

| | `JSONValue` | `AnyCodable` |
|---|---|---|
| Storage | `enum` with explicit cases | `Any` |
| Allowed values | `null`, `Bool`, `JSONNumber`, `String`, arrays, objects | any Swift value that happened to be decoded |
| Invalid states | impossible at compile time | possible at runtime |

With `AnyCodable`, a value might be `Date`, `Data`, a custom struct, or another non-JSON type depending on encoder/decoder behavior. With `JSONValue`, if decoding succeeded, you know the payload is JSON-shaped.

### 2. Real `Equatable`

`JSONValue` is honestly `Equatable`. That matters for:

- tests with fixtures
- caching and deduplication
- diffing API responses

`AnyCodable` typically cannot provide meaningful `Equatable` without fragile runtime comparisons, or it uses `@unchecked` assumptions. Comparing two dynamic JSON trees via `Any` often devolves into reference identity or partial type checks.

### 3. `Sendable` without guessing

`JSONValue` is `Sendable` by design. All cases are value types with known contents, so passing decoded query rows across actors/tasks is straightforward.

`Any` is not `Sendable`. Wrappers around it usually need `@unchecked Sendable` and push thread-safety responsibility to callers.

### 4. Predictable decoding and encoding

`JSONValue` decodes through a closed set of JSON primitives and re-encodes the same shape. Numbers stay numbers, objects stay objects, `null` stays `null`.

`AnyCodable` must guess how to bridge each `Any` value back to JSON. That can produce subtle differences between decode and encode paths, especially for numeric types and nested collections.

### 5. Safer access patterns

`JSONValue` encourages explicit extraction:

```swift
if let count = row["@count"]?.intValue { ... }
```

`AnyCodable` encourages casting:

```swift
if let count = row["@count"]?.value as? Int { ... }
```

Casts fail silently when the runtime type is `Int` vs `Double` vs `NSNumber`. `JSONValue` accessors centralize that logic and handle `JSONNumber.int` / `JSONNumber.double` consistently.

### 6. Better fit for libraries

If your package exposes dynamic JSON in public types, consumers should not depend on an `Any`-based wrapper unless they want runtime casting in their code too.

Example:

```swift
public typealias QueryRow = [String: JSONValue]
```

Callers get a stable, documented contract. With `AnyCodable`, the same alias leaks implementation details and forces every client to reason about `Any`.

### When `AnyCodable` is still fine

`AnyCodable` can be acceptable when:

- JSON is decoded once and immediately converted into strongly typed models
- the wrapper never crosses module boundaries
- you do not need `Equatable`, `Sendable`, or reliable round-trip encoding

For long-lived dynamic JSON in models, tests, and networking layers, prefer `JSONValue`.

## Comparison at a glance

```swift
// AnyCodable-style access
let value: Any? = row["count"]?.value
let count = value as? Int

// JSONValue access
let count = row["count"]?.intValue
```

```swift
// JSONValue literals in tests
let body: JSONValue = [
    "table": "events",
    "limit": 5,
    "filter": ["period": ["type": "forever"]],
]
```

```swift
// Round-trip through a Codable model
let model = FilterRequest(table: "events", limit: 5)
let json = try JSONValue(model)
let again = try json.decode(FilterRequest.self)
```

## Inspired by

- old code
- https://github.com/rexmas/JSONValue
- https://github.com/edonv/JSONValue
- https://github.com/inekipelov/swift-json-value
- https://github.com/georgetchelidze/JSONValue

## License

MIT
