//
//  PLCVectors.swift
//  AtprotoTypesVerifyTests
//
//  Created by Mark @ Germ on 10/18/26.
//

import AtprotoTypes
import Foundation

///The captured `did:plc` logs and the documents `plc.directory` serves for
///them. Where each one came from, and what it is here to pin, is in
///`Resources/plc/PROVENANCE.md`.
///
///A peer's output, not the method specification's: these say what a directory
///happens to serve, which is what "reproduces the document" means and all it
///means. Anything the specification settles is settled by its text, not here.
struct PLCVector {
	let did: Atproto.DID
	let entries: [Atproto.PLC.LogEntry]
	let document: Atproto.DIDDocument

	///A genesis in the deprecated legacy `create` format.
	static let legacyGenesis = "legacy-genesis"

	///A genesis in the current `plc_operation` format.
	static let currentFormat = "current-format"

	///An operation that changes its own `rotationKeys`.
	static let keyRotation = "key-rotation"

	static let names = [legacyGenesis, currentFormat, keyRotation]

	static func load(_ name: String) throws -> PLCVector {
		guard
			let url = Bundle.module.url(
				forResource: name, withExtension: "json", subdirectory: "plc")
		else {
			throw Errors.missingVector(name)
		}
		let root = try JSONSerialization.jsonObject(with: try Data(contentsOf: url))
		guard let object = root as? [String: Any] else {
			throw Errors.malformedVector(name)
		}
		guard let didString = object["did"] as? String else {
			throw Errors.malformedVector(name)
		}
		guard let rawEntries = object["entries"] as? [[String: Any]] else {
			throw Errors.malformedVector(name)
		}
		guard let rawDocument = object["document"] else {
			throw Errors.malformedVector(name)
		}

		return PLCVector(
			did: try Atproto.DID(string: didString),
			entries: try rawEntries.map { entry in
				guard
					let cid = entry["c"] as? String,
					let operationJSON = entry["o"] as? String,
					let nullified = entry["n"] as? Bool
				else {
					throw Errors.malformedVector(name)
				}
				return try Atproto.PLC.LogEntry(
					cid: cid,
					operationJSON: operationJSON,
					nullified: nullified
				)
			},
			document: try JSONDecoder().decode(
				Atproto.DIDDocument.self,
				from: try JSONSerialization.data(withJSONObject: rawDocument)
			)
		)
	}

	enum Errors: Error {
		case missingVector(String)
		case malformedVector(String)
	}
}
