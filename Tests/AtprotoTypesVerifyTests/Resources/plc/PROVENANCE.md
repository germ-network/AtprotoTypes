# `did:plc` log vectors — where these came from

Captured 2026-10-18 from the public `plc.directory` API. The `did:plc` method
specification (v0.3.0) publishes no operation-log test vectors, so these are
the only oracle available for "the verifier reproduces the document the
directory serves" — and they are a **peer**, not the specification. The
specification is what the verification rules come from; these files only pin
what a directory happens to serve.

Each file is one DID:

```json
{
  "did": "did:plc:…",
  "source": "https://plc.directory/did:plc:…",
  "fetchedAt": "2026-10-18",
  "entries": [ { "c": "<cid>", "o": "<operation JSON text>", "n": false } ],
  "document": { …the document GET /{did} served }
}
```

- `entries` is `GET /{did}/log/audit`, oldest first. `c` is the operation's
  `cid`, `o` its `operation` serialized back to JSON text **in the order the
  directory served its keys**, `n` its `nullified` flag. `o` is text because
  that is what the PMR envelope carries and what the verifier re-encodes.
- `document` is `GET /{did}` verbatim.

| file | DID | what it pins |
|---|---|---|
| `legacy-genesis.json` | `did:plc:yk4dd2qkboz2yv6tpubpc6co` | a genesis in the deprecated legacy `create` format — the DID is derived from that format's bytes, and the document from the conversion |
| `current-format.json` | `did:plc:ewvi7nxzyoun6zhxrhs64oiz` | a genesis in the current `plc_operation` format |
| `key-rotation.json` | `did:plc:l3rouwludahu3ui3bt66mfvj` | an operation that changes its `rotationKeys` — the case that distinguishes "signed by the previous operation's keys" from "signed by its own" |

`yk4dd2qkboz2yv6tpubpc6co` and `ewvi7nxzyoun6zhxrhs64oiz` are the DIDs the
method specification itself uses as examples.

There is deliberately **no P-256 vector**. Every P-256 `#atproto` key on the
directory belongs to a single squatting campaign against one prominent name, so
checking one in would tie this repository to that account for no gain. The
curve-dependent `@context` rule is pinned directly against the renderer instead,
and the directory's own behaviour for a P-256 key was observed on those
campaign DIDs during planning.
