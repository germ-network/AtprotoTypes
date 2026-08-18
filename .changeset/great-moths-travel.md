---
"@germ-network/atprototypes": patch
---

Screen PDS endpoint hosts without Network.framework, so the package builds on
Linux and Android. Readings are unchanged on Apple platforms: dotted quads go
through a reimplementation of `IPv4Address`'s grammar pinned by tests, every
other v4 shape defers to the platform's `inet_aton` exactly as `IPv4Address`
did, and IPv6 moves to `inet_pton`.
