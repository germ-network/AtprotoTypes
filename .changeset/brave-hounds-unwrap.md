---
"@germ-network/atprototypes": patch
---

Fix the build: `AtprotoTypesVerify`'s `RepoSigningKey` still unwrapped `DIDDocument.verificationMethod` and `VerificationMethod.publicKeyMultibase` as non-optional after they became optional in the canonical-schema relaxation. Both absent cases now refuse with `noAtprotoSigningKey`, matching the existing empty-list behaviour, with regression tests for each.
