//
//  PLCOperationEncodingTests.swift
//  AtprotoTypesVerifyTests
//
//  Created by Mark @ Germ on 10/18/26.
//

import AtprotoTypes
import AtprotoTypesVerify
import Foundation
import Testing

@Suite("did:plc operation encoding")
struct PLCOperationEncodingTests {
	///Re-encoding an operation's JSON text has to reproduce the bytes its CID
	///addresses, for every entry of every captured log. This is the load-bearing
	///step: the CID is recomputed rather than taken from the log, so a log whose
	///operation text and CID disagree cannot pass, and an encoder that disagrees
	///with the directory's about DAG-CBOR would fail every entry.
	@Test
	func everyEntryReencodesToItsCID() throws {
		for name in PLCVector.names {
			let vector = try PLCVector.load(name)
			for entry in vector.entries {
				let value = try DAGCBORValue.parse(json: entry.operationJSON)
				let bytes = DAGCBOREncoder.encode(value)
				let cid = try ContentIdentifier.compute(
					codec: .dagCBOR, block: bytes)
				#expect(cid.atprotoCID == entry.cid, "\(name): \(entry.cid.rawValue)")
			}
		}
	}

	///The parse keeps the operation object's key order. Hashing must not depend
	///on it — the encoder sorts — but rendering does: the directory emits
	///`verificationMethod` and `service` in the order the operation listed them,
	///so an order-normalizing parse would silently reorder a rendered document.
	@Test
	func parsingKeepsObjectKeyOrder() throws {
		let value = try DAGCBORValue.parse(json: #"{"zz":1,"a":2,"m":3}"#)
		guard case .map(let entries) = value else {
			Issue.record("expected a map")
			return
		}
		#expect(entries.map(\.key) == ["zz", "a", "m"])
	}

	///Two readings of one text is two meanings for one log, so the parse is
	///strict: duplicate keys, trailing content and a truncated string are all
	///refused rather than resolved. (That an *operation* has to be an object is
	///`Atproto.PLC.VerifyError.operationNotAMap`, not a JSON rule — the parse
	///reads any JSON document, and only the operation layer knows it wants a
	///map.)
	@Test
	func malformedOperationJSONIsRefused() throws {
		#expect(throws: DAGCBORValue.JSONError.duplicateKey("a")) {
			_ = try DAGCBORValue.parse(json: #"{"a":1,"a":2}"#)
		}
		#expect(throws: DAGCBORValue.JSONError.trailingContent) {
			_ = try DAGCBORValue.parse(json: #"{"a":1} {}"#)
		}
		#expect(throws: DAGCBORValue.JSONError.unterminatedString) {
			_ = try DAGCBORValue.parse(json: #"{"a":"oops}"#)
		}
	}
}
