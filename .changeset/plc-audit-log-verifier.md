---
"@germ-network/atprototypes": minor
---

Add a `did:plc` audit-log verifier: `Atproto.PLC.LogVerifying` in `AtprotoTypes` (the injection seam, with `Atproto.PLC.LogUnavailable` as the refuse-by-default conformer), and the real verifier in `AtprotoTypesVerify`. Given the signed operation log a relay serves, it checks that the genesis operation hashes to the DID, that every entry's CID is the SHA-256 of its DAG-CBOR bytes, that the `prev` chain is unbroken, and that every signature verifies under a rotation key the log itself established — then renders the document the last live operation implies. `AtprotoTypesVerifyMocks` gains `PLCFixture` for building such logs in a consumer's tests.
