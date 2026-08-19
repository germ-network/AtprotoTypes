---
"@germ-network/atprototypes": patch
---

`Atproto.DIDDocument.VerificationMethod`'s memberwise initializer is now public, matching its `Service` sibling. Only code inside this package could construct one, so a resolver adapter in another package that is handed a signing key directly rather than a DID document — Slingshot's `resolveMiniDoc`, which returns `signing_key` on the wire — had no way to publish it and shipped `verificationMethod: []`. `AtprotoTypesVerify`'s `RepoSigningKey` then refuses every document that resolver produces, and since `optimizedResolve` races it against plc.directory, whether a repo proof verifies depends on which resolver wins.
