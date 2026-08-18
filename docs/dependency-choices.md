# Why `AtprotoTypesVerify` implements its own primitives

This target hand-rolls DAG-CBOR, CID, CAR framing, MST proof walking, and
secp256k1 verification rather than importing them. That is a deliberate and
recurring question, so this records the reasoning and — more usefully — what
would change it.

The general rule: **prefer a dependency**, unless it cannot express a property
this target's correctness depends on. Every case below fails for a specific,
checkable reason, not a general preference for owning code.

Two constraints apply throughout:

- **The shipped product is pure Swift with no C dependencies.** A
  space-constrained consumer (an App Clip) links `AtprotoTypes` but never this
  target, and the boundary is enforced in CI. A C-backed dependency also
  widens the audit surface of a security check.
- **This is a verifier.** It answers "does this proof hold", so leniency is a
  correctness bug, not a convenience. Anywhere two distinct byte strings can
  decode to the same value, content-addressing stops binding and the proof
  stops proving anything.

## DAG-CBOR

Candidates: [`nnabeyang/swift-cbor`][swift-cbor] (already in the wider
dependency graph, so adopting it would cost nothing) and
[`thecoolwinter/CBOR`][cbor], which ships explicit `DAGCBORDecoder` /
`DAGCBOREncoder` types.

**Strictness is not the blocker.** Both enforce a real DAG-CBOR profile —
definite lengths, minimal integer encodings, string-only map keys, canonical
key order, duplicate-key rejection, tag allow-lists, float64-only. swift-cbor
0.1.0 in particular exposes `Options.deterministicCbor` and a matching decode
option set. Earlier versions did not, and that is worth knowing if this
question is revisited against stale information.

**The blocker is that both are Codable-only.** Neither exposes a schemaless
value tree: swift-cbor's `CborValue` is internal, with no public API returning
it, and `thecoolwinter/CBOR` has no public value enum at all.

A generic tree is not a stylistic preference here. The commit signature is
computed over the commit map **with `sig` removed**, so verification has to
rebuild that preimage and re-encode it canonically. Decoding into a
`Commit: Codable` struct silently drops any field the struct does not model —
so the first time a PDS writes a field we did not anticipate, the re-encoded
preimage would differ from the signed bytes and **every proof would fail**.
The same applies to MST nodes and, more sharply, to records: lexicon data is
arbitrary by definition.

Round-tripping through a value tree makes `encode(decode(bytes)) == bytes` a
property we can test directly, and lets one comparison rule serve both decode
validation and canonical encoding.

**What would change this:** either library exposing a public value tree
(swift-cbor promoting `CborValue`, say), or a DAG-CBOR package built around
one.

## CID

Candidate: [`swift-libp2p/swift-cid`][swift-cid] — real, maintained, pure
Swift, and from the same organisation as `swift-bases`, which this package
already depends on. This is the closest call of the five.

It is declined because it reaches CID through `swift-multihash`, which depends
on **CryptoSwift**. That would pull a general-purpose pure-Swift crypto
library into the graph to compute SHA-256, when this target already links
swift-crypto and hashes every CAR block through it. Two crypto implementations
for one hash is a worse audit story and slower, and the package documents
breaking changes across minor versions while pre-1.0.

The narrowness of `ContentIdentifier` is also load-bearing rather than
incidental: CIDv1 only, two codecs, sha2-256 only, minimal varints required,
CIDv0 rejected outright. A general-purpose library accepts the whole
multiformats space by design, so each of those restrictions would have to be
re-imposed at the call site anyway.

**What would change this:** `swift-multihash` dropping CryptoSwift in favour
of swift-crypto, or a CID package that accepts an injected hash function.

## CAR

No Swift CAR package exists. The implementations that turned up are an app, a
GPL-licensed subdirectory of an unrelated monorepo that SPM cannot depend on
directly, and library code that does not fit this use.

Notably, the closest reference implementation **never recomputes a block's CID**
— it trusts the archive's own claims about what each block is. That check, done
at load time rather than lookup time, is the single property the rest of the
proof walk rests on, so adopting that code would have meant deleting the reason
the file exists.

## MST

atproto's Merkle Search Tree has protocol-specific semantics: node depth from
the count of leading zero bits in the SHA-256 of the key, and keys stored
compressed against the previous key's shared prefix. A generic Merkle-tree
library cannot satisfy this; only an atproto-specific implementation would.

Searching Swift broadly surfaces essentially one MST implementation, and it
enumerates whole repositories rather than checking inclusion proofs, with no
key-ordering validation — meaning a forged tree shape passes it. Inclusion
proof checking is exactly what this target needs.

## secp256k1

swift-crypto has no secp256k1 at all, and most atproto accounts sign with it,
so this cannot simply be skipped.

The one mature Swift option wraps Bitcoin Core's C `libsecp256k1`, which
conflicts with the no-C constraint above. It *is* used — as a differential
test oracle in `AtprotoTypesVerifyTests`, never in a shipped product — which
gives the from-scratch implementation an independent implementation to check
against, alongside the Wycheproof vector suite.

The port is **verify-only and deliberately not constant-time**: every value it
touches (public keys, signatures, message digests) is public, so there is no
secret whose timing could leak. That property is what makes a from-scratch
implementation defensible, and it is why the arithmetic files must never grow
a signing path — a private key there would invalidate the reasoning that
permits this code to exist.

**What would change this:** a maintained, pure-Swift secp256k1 verifier.

[swift-cbor]: https://github.com/nnabeyang/swift-cbor
[cbor]: https://github.com/thecoolwinter/CBOR
[swift-cid]: https://github.com/swift-libp2p/swift-cid
