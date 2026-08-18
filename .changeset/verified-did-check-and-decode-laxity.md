---
"@germ-network/atprototypes": minor
---

Two fixes to `Atproto.DIDDocument`:

`verified(expecting:did:)` shadowed its own `did:` parameter and never checked it, so the DID-matches-document-id check `Resolver.swift`'s own doc comment claims is enforced never actually ran. Both the synchronous and async (`verified(resolver:)`, now taking an optional `expectedDid:`) overloads check it and throw `documentIdMismatch` on a mismatch. Everywhere in the current call graph this was traced to be a provable no-op except one site (a plc.directory response accepted without comparing its `id` to the requested DID) — this closes that gap directly.

`DIDDocument`'s decode was stricter than the canonical schema: `@context`, `verificationMethod`, `service`, and `VerificationMethod.publicKeyMultibase` are now optional, `@context` accepts a bare string as well as an array, and `Service.serviceEndpoint` is now `URL?` (an object-shaped endpoint, or a string that doesn't parse as a `URL`, decodes to `nil` rather than failing the whole document). PLC-issued documents hid this — plc.directory emits one uniform, tool-generated shape — but did:web documents are self-hosted and far more likely to be minimal or hand-authored.
