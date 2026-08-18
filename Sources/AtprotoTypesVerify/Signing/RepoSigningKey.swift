//
//  RepoSigningKey.swift
//  AtprotoTypesVerify
//
//  Created by Mark @ Germ on 8/17/26.
//

import AtprotoTypes
import BaseX
import Crypto
import Foundation

///The repo's signing key, as the DID document publishes it: a multibase
///base58btc string wrapping a multicodec prefix and a compressed point.
///
///Two curves are in use across the network. P-256 is here; secp256k1 is what
///Bluesky's own PDS mints by default, and swift-crypto has no k256 at all, so
///this file carries a from-scratch, verify-only secp256k1 port
///(`Secp256k1.ECDSA`) alongside the P-256 path swift-crypto backs directly.
///See `docs/dependency-choices.md` for why that isn't an imported library.
public struct RepoSigningKey: Sendable {
	public enum Curve: Sendable, Equatable {
		case p256
		case secp256k1

		//multicodec, varint-encoded in the multibase payload
		static func named(_ code: UInt64) -> Curve? {
			switch code {
			case 0x1200: .p256
			case 0xe7: .secp256k1
			default: nil
			}
		}

		public var name: String {
			switch self {
			case .p256: "p256"
			case .secp256k1: "secp256k1"
			}
		}
	}

	public let curve: Curve
	///SEC1 compressed point, 33 bytes.
	public let compressedPoint: Data

	///Picks the `#atproto` verification method out of a DID document. atproto
	///documents may list several; the repo signing key is the one with that
	///fragment, and taking "the first one" instead would let a document with an
	///extra method up front decide what we check against.
	public init(atprotoKeyIn document: Atproto.DIDDocument, did: Atproto.DID) throws {
		guard
			let method = document.verificationMethod.first(where: {
				$0.id == "#atproto" || $0.id.hasSuffix("#atproto")
			})
		else {
			throw Atproto.Repo.ProofError.noAtprotoSigningKey
		}

		//a document that names someone else as controller of its signing key is
		//not making a claim about this DID's repo. An absent controller falls
		//back to the document's own id, per DID convention (no controller means
		//self-controlled) — never to a blanket skip, or a document paired with
		//the wrong `did` by a caller-side bug would pass whenever the method
		//simply omits the field, which is the common case for real documents.
		let controllerDID = method.controller.isEmpty ? document.id : method.controller
		guard controllerDID == did.rawValue else {
			throw Atproto.Repo.ProofError.signingKeyControllerMismatch
		}

		try self.init(multibase: method.publicKeyMultibase)
	}

	public init(multibase: String) throws {
		let trimmed =
			multibase.hasPrefix("did:key:")
			? String(multibase.dropFirst("did:key:".count))
			: multibase

		//`z` is multibase base58btc; nothing else appears in atproto documents
		guard trimmed.hasPrefix("z") else {
			throw Atproto.Repo.ProofError.badMultibaseKey
		}

		let decoded: Data
		do {
			decoded = try BaseX.decode(String(trimmed.dropFirst()), as: .base58BTC)
		} catch {
			throw Atproto.Repo.ProofError.badMultibaseKey
		}

		var reader = ByteReader(decoded)
		let code = try reader.readUnsignedVarint()
		guard let curve = Curve.named(code) else {
			throw Atproto.Repo.ProofError.unsupportedCurve("multicodec 0x\(String(code, radix: 16))")
		}

		let pointLength = reader.remaining
		let point = Data(try reader.read(pointLength))
		//compressed form only: 0x02 or 0x03 then a 32-byte x
		guard point.count == 33, point.first == 0x02 || point.first == 0x03 else {
			throw Atproto.Repo.ProofError.badMultibaseKey
		}

		self.curve = curve
		self.compressedPoint = point
	}

	///Verifies a 64-byte compact `r ‖ s` signature over `message`, hashing with
	///SHA-256 as the repo format specifies.
	public func verify(signature: Data, over message: Data) throws {
		guard signature.count == 64 else {
			throw Atproto.Repo.ProofError.badSignatureLength(signature.count)
		}

		switch curve {
		case .secp256k1:
			//same low-S rule as p256, against this curve's own order — atproto
			//requires it network-wide, not just for the curve swift-crypto backs
			guard Self.isLowS(Array(signature.suffix(32)), order: Self.secp256k1Order) else {
				throw Atproto.Repo.ProofError.nonCanonicalSignature
			}

			let digest = SHA256.hash(data: message)
			guard
				Secp256k1.ECDSA.verify(
					signature: signature, digest: Data(digest), compressedPublicKey: compressedPoint)
			else {
				throw Atproto.Repo.ProofError.signatureDidNotVerify
			}

		case .p256:
			//atproto requires low-S. swift-crypto will happily verify the
			//high-S twin, so rejecting malleated signatures is on us: without
			//it two distinct byte strings both "prove" one commit.
			guard Self.isLowS(Array(signature.suffix(32)), order: Self.p256Order) else {
				throw Atproto.Repo.ProofError.nonCanonicalSignature
			}

			let key: P256.Signing.PublicKey
			let parsed: P256.Signing.ECDSASignature
			do {
				key = try P256.Signing.PublicKey(
					compressedRepresentation: compressedPoint
				)
				parsed = try P256.Signing.ECDSASignature(rawRepresentation: signature)
			} catch {
				throw Atproto.Repo.ProofError.badMultibaseKey
			}

			guard key.isValidSignature(parsed, for: message) else {
				throw Atproto.Repo.ProofError.signatureDidNotVerify
			}
		}
	}

	///Exposed beyond this module (package-wide, not public) so fixture-building
	///test support in AtprotoTypesVerifyMocks — which needs to fold a signature
	///to its low- or high-S twin — shares the same threshold rather than
	///risking a second, driftable copy of it.
	package static let p256Order: [UInt8] = [
		0xFF, 0xFF, 0xFF, 0xFF, 0x00, 0x00, 0x00, 0x00,
		0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF,
		0xBC, 0xE6, 0xFA, 0xAD, 0xA7, 0x17, 0x9E, 0x84,
		0xF3, 0xB9, 0xCA, 0xC2, 0xFC, 0x63, 0x25, 0x51,
	]

	///Derived from `Secp256k1.Scalar.order` rather than transcribed as a
	///second hex constant — one order to keep in sync with the curve
	///parameters, not two.
	package static let secp256k1Order: [UInt8] = Secp256k1.Limbs256.bigEndianBytes(
		Secp256k1.Scalar.order)

	///`s <= n/2`. The half-order is derived from the order rather than written
	///out, so there is one constant to check against the curve parameters
	///instead of two.
	package static func isLowS(_ s: [UInt8], order: [UInt8]) -> Bool {
		let half = halved(order)
		guard s.count == half.count else { return false }
		for (lhs, rhs) in zip(s, half) where lhs != rhs {
			return lhs < rhs
		}
		return true
	}

	static func halved(_ bytes: [UInt8]) -> [UInt8] {
		var out = [UInt8](repeating: 0, count: bytes.count)
		var carry: UInt8 = 0
		for index in bytes.indices {
			out[index] = (bytes[index] >> 1) | (carry << 7)
			carry = bytes[index] & 1
		}
		return out
	}
}
