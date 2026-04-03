---
"@germ-network/atprototypes": minor
---

Add support for deleting records from repos

This adds support for the com.atproto.repo.deleteRecord lexicon procedure. When using this package with AtprotoClient, the following code can be used to delete a record from the authenticated account's repository:

```
try await call(
	Lexicon.App.Bsky.Actor.GetProfile.self,
	parameters: .init(
		repo: .did(did),
		rkey: rkey
	)
)
```

