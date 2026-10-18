//
//  PLCLogVerifier.swift
//  AtprotoTypesVerify
//
//  Created by Mark @ Germ on 10/18/26.
//

import AtprotoTypes
import Foundation

extension Atproto.PLC {
	///The verifying conformer. A consumer that wants a served log checked
	///injects this at its composition root; a space-constrained one injects
	///`Atproto.PLC.LogUnavailable` and never links this module.
	///
	///What this establishes that reading a served document cannot: the document
	///follows from bytes the DID's own rotation keys signed, so a relay can
	///withhold or truncate a log but cannot forge one. The relay's word for a
	///document is a claim about the directory; a verified log is a claim the
	///device checked itself.
	public struct Verifier: LogVerifying {
		public init() {}

		public func verifyLog(
			did: Atproto.DID,
			entries: [Atproto.PLC.LogEntry]
		) throws -> Atproto.PLC.VerifiedDocument {
			// build: parse each entry, recompute its CID, check the genesis
			// hash, walk the live prev chain, verify each signature under the
			// rotation keys the previous operation established, and render the
			// document from the last live operation
			throw VerifyError.notImplemented
		}
	}
}
