---
"@germ-network/atprototypes": minor
---

Add `Atproto.RecordSwap` and `PutRecord.Input.Schema.init(…, swap:)`, so a `putRecord` can send `swapRecord: null` (the Lexicon spec distinguishes null from omitted; the reference PDS reads null as "no record may exist"). The existing `swapRecord: CID?` init encodes as before.
