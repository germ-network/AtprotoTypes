---
"@germ-network/atprototypes": minor
---

In this PR:

- All XRPC calls get a `Parameters` type
- Procedures get an `Input` type
- We define an empty query params (which most procedures will use)
- Rename the xrpc` Result` to `Output`
- rename xrpc `acceptValue` -> `outputEncoding`
