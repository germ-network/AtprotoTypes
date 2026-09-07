---
"@germ-network/atprototypes": patch
---

`RepoSigningKey(atprotoKeyIn:did:)` selected the `#atproto` verification method with `$0.id == "#atproto" || $0.id.hasSuffix("#atproto")`. The equality disjunct is dead: any id equal to `"#atproto"` also has that suffix, so the `hasSuffix` check alone decides every case. Simplified to the suffix match. Behavior-neutral — no change to which documents are accepted.
