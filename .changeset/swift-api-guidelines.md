---
"@germ-network/atprototypes": minor
---

Align public API names with Swift conventions, including `queryItems` and `rawValue`, while retaining deprecated compatibility accessors where practical. `QueryParametrizable` conformers must now implement `queryItems`; existing calls to `asQueryItems()` remain available as a deprecated forwarding method.
