---
"@germ-network/atprototypes": minor
---

`AtprotoTypesVerify` now verifies secp256k1 repo commit signatures, not just P-256 — a from-scratch, verify-only Swift port (field/scalar arithmetic, Jacobian point operations, SEC1 decompression, ECDSA), since most Bluesky accounts sign with this curve and swift-crypto has no k256 support. Checked against Wycheproof's secp256k1 test vectors and a P256K-backed differential oracle in `AtprotoTypesVerifyTests` (test-only dependency; nothing new ships in the product). `AtprotoTypesVerifyMocks`'s fixture signer is now a protocol (`RepoFixtureSigningKey`) instead of concrete P256, so a consumer's tests can build synthetic k256 repos too.
