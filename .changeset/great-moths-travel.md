---
"AtprotoTypes": patch
---

Screen PDS endpoint hosts without Network.framework, so the package builds on
Linux and Android. The IPv4, IPv6 and v4-in-v6 readings are unchanged on Apple
platforms; `IPv4Address`'s permissive grammar is now reimplemented and pinned by
tests, and `inet_aton`/`inet_pton` come from whichever libc the target has.
