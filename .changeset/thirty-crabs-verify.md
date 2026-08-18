---
"@germ-network/atprototypes": minor
---

Add `AtprotoTypesVerify` and `AtprotoTypesVerifyMocks`: CAR framing, DAG-CBOR, MST proof walking, CID recomputation, and P-256 repo commit-signature verification, plus fixture-building support for building synthetic signed repos in tests. Additive products — a consumer that never links the new products pays nothing for their existing (e.g. an App Clip target). The existing `AtprotoTypes` target gains one small addition of its own: an `Atproto.Repo` seam (`RecordPath`, `Proof`, `ProofVerifying`, `ProofUnavailable`) cheap enough for a space-constrained consumer to link even when it doesn't want the verifier itself.
