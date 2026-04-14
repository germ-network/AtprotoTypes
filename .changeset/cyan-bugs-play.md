---
"@germ-network/atprototypes": minor
---

A significant package change:
- move most types under the `Atproto` namespace
- Add a mock types target to isolate mock generation from the primary package.
	- Tests can import the AtprotoTypesMocks package
	- Clients can similarly define their own *Mocks target importing `AtprotoTypesMocks`
- Remove boilerplate encoding by defining a `FixedString` protocol
- Adjust our types so that `NSID` represents a structure of the NSID data type, but we have separate
types representing the use of an NSID as a collection id or xrpc endpoint id.
