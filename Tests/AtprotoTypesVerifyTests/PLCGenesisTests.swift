//
//  PLCGenesisTests.swift
//  AtprotoTypesVerifyTests
//
//  Created by Mark @ Germ on 10/18/26.
//

import AtprotoTypes
import AtprotoTypesVerify
import AtprotoTypesVerifyMocks
import Foundation
import Testing

@Suite("did:plc genesis")
struct PLCGenesisTests {
	///The DID is derived from the genesis operation's own bytes, so a log whose
	///first entry does not hash to the DID it is claimed for is not that DID's
	///log — which is the whole of the identifier's self-certification.
	@Test
	func aCurrentFormatGenesisHashesToTheDID() throws {
		let vector = try PLCVector.load(PLCVector.currentFormat)
		let verified = try Atproto.PLC.Verifier().verifyLog(
			did: vector.did, entries: vector.entries)
		#expect(verified.did == vector.did)
	}

	///A legacy `create` genesis hashes as itself, not as the regular operation
	///it converts to, so the conversion cannot be applied before the hash —
	///and those DIDs are permanent, because the identifier is the hash.
	@Test
	func aLegacyCreateGenesisHashesToTheDID() throws {
		let vector = try PLCVector.load(PLCVector.legacyGenesis)
		let verified = try Atproto.PLC.Verifier().verifyLog(
			did: vector.did, entries: vector.entries)
		#expect(verified.did == vector.did)
	}

	///A well-formed genesis presented under someone else's DID is refused. The
	///signature verifies and every CID is self-consistent; only the hash is
	///wrong, which is exactly the forgery the DID derivation exists to stop.
	@Test
	func aGenesisThatDoesNotHashToTheDIDIsRefused() throws {
		let scenario = PLCScenario()
		let genesis = try scenario.signed(prev: nil)
		let entry = try PLCFixture.entry(genesis)
		let wrongDID = try Atproto.DID(string: "did:plc:aaaaaaaaaaaaaaaaaaaaaaaa")

		#expect {
			_ = try Atproto.PLC.Verifier().verifyLog(did: wrongDID, entries: [entry])
		} throws: { isCase("genesisDoesNotHashToTheDID")($0) }
	}

	///A log with no operations has no genesis, so there is nothing for the DID
	///to be the hash of — a truncation all the way down rather than a log.
	@Test
	func anEmptyLogIsRefused() throws {
		let did = try Atproto.DID(string: "did:plc:ewvi7nxzyoun6zhxrhs64oiz")

		#expect {
			_ = try Atproto.PLC.Verifier().verifyLog(did: did, entries: [])
		} throws: { isCase("emptyLog")($0) }
	}

	///The first operation is the genesis, and a genesis points at nothing. One
	///that carries a `prev` is an update wearing the first slot, which the
	///verifier has to refuse rather than take as a starting point.
	@Test
	func aGenesisWithAPrevIsRefused() throws {
		let scenario = PLCScenario()
		let pointedAt = try scenario.signed(prev: nil)
		let genesis = try scenario.signed(prev: try PLCFixture.cid(pointedAt))
		let did = try PLCFixture.genesisDID(genesis)

		#expect {
			_ = try Atproto.PLC.Verifier().verifyLog(
				did: did, entries: [try PLCFixture.entry(genesis)])
		} throws: { isCase("genesisHasNonNilPrev")($0) }
	}

	///A legacy `create` that carries a predecessor is refused. The format always
	///writes `prev` as an explicit null, so one that does not is not a genesis —
	///and reading the field is what lets the genesis rule catch it rather than
	///the conversion quietly dropping it.
	@Test
	func aLegacyCreateCarryingAPrevIsRefused() throws {
		let value = try DAGCBORValue.parse(
			json: """
				{"type":"create",\
				"signingKey":"did:key:zQ3shP5TBe1sQfSttXty15FAEHV1DZgcxRZNxvEWnPfLFwLxJ",\
				"recoveryKey":"did:key:zQ3shhCGUqDKjStzuDxPkTxN6ujddP4RkEKJJouJGRRkaLGbg",\
				"handle":"example.test","service":"https://pds.example.test",\
				"prev":"bafyreieibu2mtgsovktnswo6l7dv4i4ztioutzpsy7wsasmbznzqxkpyje",\
				"sig":""}
				""")
		let did = try PLCFixture.genesisDID(value)

		#expect {
			_ = try Atproto.PLC.Verifier().verifyLog(
				did: did, entries: [try PLCFixture.entry(value)])
		} throws: { isCase("genesisHasNonNilPrev")($0) }
	}
}
