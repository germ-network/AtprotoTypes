---
"@germ-network/atprototypes": minor
---

An `OptionalResultRequest` (getRecord, getBlob, resolveHandle) types a 404 whose body names one of its `notFoundCodes` as `.xrpcError(status: .notFound, …)`, as it already typed the 400. tranquil PDSes send a missing record as `404 RecordNotFound`, which surfaced as `.unrecognized(404)`. Adds the `ResponseParsing.notFoundErrors` requirement, defaulted.
