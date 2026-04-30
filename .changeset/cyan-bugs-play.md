---
"@germ-network/atprototypes": minor
---

# Renaming
- collect most types under the `Atproto` namespace
- reserve `Lexicon` namespace for Lexicon definitions
- Adopt nested naming where appropriate
    - e.g. XRPCRequest -> XRPC.Request

# Mocks
- make a new `AtprotoTypesMocks` target
    - This way, Tests and Previews can import 
- keep the `Mockable` target separate as it may get broken out into a higher package if needed in shared libraries
- Downstream adopters can similarly make their own Mock target

# Protocol Changes
**Raw Representable** Many types here are represented over the wire as strings, but have restrictions applied at parse time. Each of them had boilerplate code to encode and decode from a bare String value in a JSON object

In this PR, we conform these types to `RawRepresentable` (implicitly String), getting compiler synthesis of encoding and decoding.

This also standardizes our accessor for the underlying string value as `.rawValue`. Unfortunately it also changes us to a failable  initializer (`init?`) instead of throwing. 
- `Atproto.AnyRecordKey` shows how we still implement a throwing initializer and add logging to convert it to a failable init.

**FixedString**
- There are a number of situations where we want to decode a fixed value from JSON. e.g. `literal:self`. This doesn't map neatly to our synthesized coding. The previous implementation correctly encoded the fixed value, but never checked equality on decode, and adding it manually would be more boilerplate.

What we needed was a type that would only successfully decode to the fixed string value. The default implementation of `Decode` for the protocol `FixedString` implements this check once. 

**NSID**
NSID was previously typealiased as a string. While deferring further structure checking of NSID, we
- define it as a concrete type to leave room for future structure checking
- Separately define types for where NSID is used
    - `RecordId` and `Xrpc.EndpointId` protocols where NSID is used as format. Both are encoded (the former in the encoding of a record, the latter in the encoding of a procedure Input), so it's useful to conform it to `FixedString` to facilitate coding and decoding
