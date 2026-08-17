---
"@germ-network/atprototypes": minor
---

Add `AtprotoTypesVerify` and `AtprotoTypesVerifyMocks`: CAR framing, DAG-CBOR, MST proof walking, CID recomputation, and P-256 repo commit-signature verification, plus fixture-building support for building synthetic signed repos in tests. Additive products — nothing in the existing `AtprotoTypes` target changes, and a consumer that never links the new products pays nothing for their existing (e.g. an App Clip target).
