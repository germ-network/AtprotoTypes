---
"@germ-network/atprototypes": patch
---

add JSONDecoder.atproto (dataDecodingStrategy .atprotoBase64) accepting the data model's unpadded base64, route XRPC response parsing through it, and emit $bytes unpadded
