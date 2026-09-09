---
"@germ-network/atprototypes": minor
---

`ProofVerifying.verifyRecordProof` now returns `Atproto.Repo.RecordProof` (`.present(Proof)` / `.absent`) instead of `Proof`. A validly-signed MST proof that a record is *not* in the repo at a path is a successful verification, not a failure — the commit is signed and DID-matched, and the MST proves the path empty. Previously this case threw `AtprotoTypesVerify`'s `ProofError.recordNotInTree`, a concrete error type no base-module caller can catch by type; now a caller distinguishes proof-of-absence from a verification failure without importing the verify module at all. Every other outcome (malformed proof, bad signature, wrong DID, incomplete CAR) still throws.
