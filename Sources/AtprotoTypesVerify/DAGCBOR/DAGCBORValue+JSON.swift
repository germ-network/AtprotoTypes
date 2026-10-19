//
//  DAGCBORValue+JSON.swift
//  AtprotoTypesVerify
//
//  Created by Mark @ Germ on 10/18/26.
//

import AtprotoTypes
import Foundation

extension DAGCBORValue {
	public enum JSONError: Error, Equatable, LocalizedError {
		case unexpectedToken
		case unterminatedString
		case invalidEscape
		case invalidUnicodeEscape
		case invalidNumber(String)
		case duplicateKey(String)
		case trailingContent
		case nestingTooDeep

		public var errorDescription: String? {
			switch self {
			case .unexpectedToken: "Unexpected JSON token"
			case .unterminatedString: "Unterminated JSON string"
			case .invalidEscape: "Invalid JSON escape"
			case .invalidUnicodeEscape: "Invalid JSON \\u escape"
			case .invalidNumber(let text): "Invalid JSON number \(text)"
			case .duplicateKey(let key): "Duplicate JSON key \(key)"
			case .trailingContent: "Content after the JSON document"
			case .nestingTooDeep: "JSON nesting too deep"
			}
		}
	}

	///The IPLD data model value for a JSON document.
	///
	///Object key order survives the parse, and it matters in exactly one
	///direction. ``DAGCBOREncoder`` sorts map keys canonically whatever order it
	///is handed, so a CID or a signature computed from this value cannot depend
	///on the order the JSON text happened to use — which is the property the
	///whole verification rests on. Rendering a DID document does depend on it:
	///the directory emits `verificationMethod` and `service` in the order the
	///operation's object listed them, so the renderer reads this order rather
	///than a canonical one, and a single parsed value serves both.
	///
	///Strict, for the same reason the CBOR decoder is: JSON admits several
	///readings of one document — a duplicate key, content after the value, a
	///number the integer type cannot hold, a malformed escape, a raw control
	///byte — and anywhere two readings of one text can disagree is somewhere a
	///log can be made to mean two things.
	public static func parse(json text: String) throws -> DAGCBORValue {
		var scanner = JSONScanner(text)
		return try scanner.parseDocument()
	}

	///The JSON text for a value in the subset JSON and DAG-CBOR share, in the
	///order the value's maps hold.
	///
	///The inverse of ``parse(json:)``, and it exists for the same reason: a
	///fixture that builds an operation as a value still has to hand the
	///verifier the JSON text a source would serve, and serializing it any other
	///way would lose the key order the renderer reads.
	package func jsonText() -> String {
		var out = ""
		DAGCBORValue.appendJSON(self, to: &out)
		return out
	}

	private static func appendJSON(_ value: DAGCBORValue, to out: inout String) {
		switch value {
		case .null:
			out += "null"
		case .bool(let flag):
			out += flag ? "true" : "false"
		case .integer(let number):
			out += String(number)
		case .float(let number):
			out += String(number)
		case .string(let string):
			appendJSONString(string, to: &out)
		case .array(let items):
			out += "["
			for (offset, item) in items.enumerated() {
				if offset > 0 { out += "," }
				appendJSON(item, to: &out)
			}
			out += "]"
		case .map(let entries):
			out += "{"
			for (offset, entry) in entries.enumerated() {
				if offset > 0 { out += "," }
				appendJSONString(entry.key, to: &out)
				out += ":"
				appendJSON(entry.value, to: &out)
			}
			out += "}"
		//JSON cannot spell bytes or a link, so the two values outside the shared
		//subset take the DAG-JSON shapes that stand in for them — bytes as
		//standard base64 without padding, a link as its CID string.
		case .bytes(let data):
			let base64 = String(data.base64EncodedString().prefix { $0 != "=" })
			out += "{\"/\":{\"bytes\":\"" + base64 + "\"}}"
		case .link(let cid):
			out += "{\"/\":\"" + cid.string + "\"}"
		}
	}

	private static func appendJSONString(_ string: String, to out: inout String) {
		out += "\""
		for scalar in string.unicodeScalars {
			switch scalar {
			case "\"": out += "\\\""
			case "\\": out += "\\\\"
			case "\n": out += "\\n"
			case "\r": out += "\\r"
			case "\t": out += "\\t"
			case "\u{08}": out += "\\b"
			case "\u{0C}": out += "\\f"
			default:
				if scalar.value < 0x20 {
					out += String(format: "\\u%04x", scalar.value)
				} else {
					out.unicodeScalars.append(scalar)
				}
			}
		}
		out += "\""
	}
}

///A strict JSON reader over the UTF-8 bytes of the text.
///
///Hand-written rather than `JSONSerialization`, which loses object key order
///(it hands back a dictionary) and silently keeps the last of a set of
///duplicate keys — both of which are exactly the disagreements this parse
///exists to refuse.
private struct JSONScanner {
	private let bytes: [UInt8]
	private var index = 0

	///Matches the CBOR decoder's ceiling, so a deeply nested document is
	///refused by both layers at the same point.
	private static let maxDepth = 128

	init(_ text: String) {
		bytes = Array(text.utf8)
	}

	mutating func parseDocument() throws -> DAGCBORValue {
		skipWhitespace()
		let value = try parseValue(depth: 0)
		skipWhitespace()
		guard index == bytes.count else {
			throw DAGCBORValue.JSONError.trailingContent
		}
		return value
	}

	private func peek() -> UInt8? {
		index < bytes.count ? bytes[index] : nil
	}

	private func isDigit(_ byte: UInt8?) -> Bool {
		guard let byte else { return false }
		return byte >= 0x30 && byte <= 0x39
	}

	private mutating func skipWhitespace() {
		while let byte = peek() {
			switch byte {
			case 0x20, 0x09, 0x0A, 0x0D: index += 1
			default: return
			}
		}
	}

	private mutating func parseValue(depth: Int) throws -> DAGCBORValue {
		guard depth < Self.maxDepth else {
			throw DAGCBORValue.JSONError.nestingTooDeep
		}
		guard let byte = peek() else {
			throw DAGCBORValue.JSONError.unexpectedToken
		}
		switch byte {
		case UInt8(ascii: "{"): return try parseObject(depth: depth)
		case UInt8(ascii: "["): return try parseArray(depth: depth)
		case UInt8(ascii: "\""): return .string(try parseString())
		case UInt8(ascii: "t"):
			try expectLiteral("true")
			return .bool(true)
		case UInt8(ascii: "f"):
			try expectLiteral("false")
			return .bool(false)
		case UInt8(ascii: "n"):
			try expectLiteral("null")
			return .null
		case UInt8(ascii: "-"), 0x30...0x39:
			return try parseNumber()
		default:
			throw DAGCBORValue.JSONError.unexpectedToken
		}
	}

	private mutating func parseObject(depth: Int) throws -> DAGCBORValue {
		index += 1
		var entries: [(key: String, value: DAGCBORValue)] = []
		var seen: Set<String> = []
		skipWhitespace()
		if peek() == UInt8(ascii: "}") {
			index += 1
			return .map(entries)
		}
		while true {
			skipWhitespace()
			guard peek() == UInt8(ascii: "\"") else {
				throw DAGCBORValue.JSONError.unexpectedToken
			}
			let key = try parseString()
			guard seen.insert(key).inserted else {
				throw DAGCBORValue.JSONError.duplicateKey(key)
			}
			skipWhitespace()
			guard peek() == UInt8(ascii: ":") else {
				throw DAGCBORValue.JSONError.unexpectedToken
			}
			index += 1
			skipWhitespace()
			entries.append((key: key, value: try parseValue(depth: depth + 1)))
			skipWhitespace()
			if peek() == UInt8(ascii: ",") {
				index += 1
			} else if peek() == UInt8(ascii: "}") {
				index += 1
				return .map(entries)
			} else {
				throw DAGCBORValue.JSONError.unexpectedToken
			}
		}
	}

	private mutating func parseArray(depth: Int) throws -> DAGCBORValue {
		index += 1
		var items: [DAGCBORValue] = []
		skipWhitespace()
		if peek() == UInt8(ascii: "]") {
			index += 1
			return .array(items)
		}
		while true {
			skipWhitespace()
			items.append(try parseValue(depth: depth + 1))
			skipWhitespace()
			if peek() == UInt8(ascii: ",") {
				index += 1
			} else if peek() == UInt8(ascii: "]") {
				index += 1
				return .array(items)
			} else {
				throw DAGCBORValue.JSONError.unexpectedToken
			}
		}
	}

	private mutating func parseString() throws -> String {
		index += 1
		var out = ""
		while true {
			guard let byte = peek() else {
				throw DAGCBORValue.JSONError.unterminatedString
			}
			if byte == UInt8(ascii: "\"") {
				index += 1
				return out
			}
			if byte == UInt8(ascii: "\\") {
				index += 1
				try appendEscape(to: &out)
				continue
			}
			guard byte >= 0x20 else {
				throw DAGCBORValue.JSONError.invalidEscape
			}
			let start = index
			while let inner = peek(),
				inner != UInt8(ascii: "\""), inner != UInt8(ascii: "\\"),
				inner >= 0x20
			{
				index += 1
			}
			out += String(decoding: bytes[start..<index], as: UTF8.self)
		}
	}

	private mutating func appendEscape(to out: inout String) throws {
		guard let escape = peek() else {
			throw DAGCBORValue.JSONError.unterminatedString
		}
		index += 1
		switch escape {
		case UInt8(ascii: "\""): out += "\""
		case UInt8(ascii: "\\"): out += "\\"
		case UInt8(ascii: "/"): out += "/"
		case UInt8(ascii: "b"): out += "\u{08}"
		case UInt8(ascii: "f"): out += "\u{0C}"
		case UInt8(ascii: "n"): out += "\n"
		case UInt8(ascii: "r"): out += "\r"
		case UInt8(ascii: "t"): out += "\t"
		case UInt8(ascii: "u"): try appendUnicodeEscape(to: &out)
		default: throw DAGCBORValue.JSONError.invalidEscape
		}
	}

	private mutating func appendUnicodeEscape(to out: inout String) throws {
		let first = try readHexQuad()
		if first >= 0xD800 && first <= 0xDBFF {
			guard peek() == UInt8(ascii: "\\") else {
				throw DAGCBORValue.JSONError.invalidUnicodeEscape
			}
			index += 1
			guard peek() == UInt8(ascii: "u") else {
				throw DAGCBORValue.JSONError.invalidUnicodeEscape
			}
			index += 1
			let second = try readHexQuad()
			guard second >= 0xDC00 && second <= 0xDFFF else {
				throw DAGCBORValue.JSONError.invalidUnicodeEscape
			}
			let combined = 0x1_0000 + ((first - 0xD800) << 10) + (second - 0xDC00)
			guard let scalar = Unicode.Scalar(combined) else {
				throw DAGCBORValue.JSONError.invalidUnicodeEscape
			}
			out.unicodeScalars.append(scalar)
			return
		}
		guard let scalar = Unicode.Scalar(first) else {
			throw DAGCBORValue.JSONError.invalidUnicodeEscape
		}
		out.unicodeScalars.append(scalar)
	}

	private mutating func readHexQuad() throws -> UInt32 {
		var value: UInt32 = 0
		for _ in 0..<4 {
			guard let byte = peek() else {
				throw DAGCBORValue.JSONError.invalidUnicodeEscape
			}
			index += 1
			let digit: UInt32
			switch byte {
			case 0x30...0x39: digit = UInt32(byte - 0x30)
			case 0x61...0x66: digit = UInt32(byte - 0x61 + 10)
			case 0x41...0x46: digit = UInt32(byte - 0x41 + 10)
			default: throw DAGCBORValue.JSONError.invalidUnicodeEscape
			}
			value = (value << 4) | digit
		}
		return value
	}

	private mutating func parseNumber() throws -> DAGCBORValue {
		let start = index
		if peek() == UInt8(ascii: "-") { index += 1 }
		guard let leading = peek(), isDigit(leading) else {
			throw DAGCBORValue.JSONError.invalidNumber(token(from: start))
		}
		if leading == 0x30 {
			index += 1
		} else {
			while isDigit(peek()) { index += 1 }
		}
		var isFractional = false
		if peek() == UInt8(ascii: ".") {
			isFractional = true
			index += 1
			guard isDigit(peek()) else {
				throw DAGCBORValue.JSONError.invalidNumber(token(from: start))
			}
			while isDigit(peek()) { index += 1 }
		}
		if peek() == UInt8(ascii: "e") || peek() == UInt8(ascii: "E") {
			isFractional = true
			index += 1
			if peek() == UInt8(ascii: "+") || peek() == UInt8(ascii: "-") { index += 1 }
			guard isDigit(peek()) else {
				throw DAGCBORValue.JSONError.invalidNumber(token(from: start))
			}
			while isDigit(peek()) { index += 1 }
		}
		let text = token(from: start)
		if isFractional {
			guard let value = Double(text), value.isFinite else {
				throw DAGCBORValue.JSONError.invalidNumber(text)
			}
			return .float(value)
		}
		//an integer the IPLD data model cannot hold is refused rather than
		//reinterpreted as a float, so a number never silently changes type
		guard let value = Int64(text) else {
			throw DAGCBORValue.JSONError.invalidNumber(text)
		}
		return .integer(value)
	}

	private func token(from start: Int) -> String {
		String(decoding: bytes[start..<index], as: UTF8.self)
	}

	private mutating func expectLiteral(_ literal: String) throws {
		let expected = Array(literal.utf8)
		guard index + expected.count <= bytes.count,
			Array(bytes[index..<(index + expected.count)]) == expected
		else {
			throw DAGCBORValue.JSONError.unexpectedToken
		}
		index += expected.count
	}
}
