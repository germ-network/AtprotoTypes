---
"@germ-network/atprototypes": patch
---

We must always verify the handle we get back from the did doc.

To do this:
* we make the parsed handle a private `unverifiedDidDoc` getter
* we define a `Atproto.DiDDoc.Verified`  object that contains the bare doc, a verified handle, and (for convenience), a typed DiD
* We provide an asynchronous verifier taking a resolve closure, as well as a synchronous verifier if we started from a handle and already resolved it to the did.

The async verifier requires a call to a handle resolver (to DiD), so we add the `com.atproto.identity.resolveHandle` lexicon)

We also add a protocol for XRPC requests that define "NotFound" error codes, so we can share code (implemented in https://github.com/germ-network/AtprotoClient/pull/25) among calls that catch the specified "not found" errors and return an optional result
