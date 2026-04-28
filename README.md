This library provides types corresponding to [atproto](https://atproto.com) type definitions.


# Namespacing

* `Lexicon` namespace is only for lexicon types in reverse DNS format
* `Atproto` namespace for atproto-specific types or atproto variants
	* e.g. atproto DiD, as opposed to the broader DiD definition
	* `Atproto.Primitive` for atproto data in https://atproto.com/specs/data-model
		(links, bytes, blobs)
* Top-level namespace for types defined outside of Atproto

## Organization
* Lexicon folder is organized in reverse DNS, though we lazily truncate the directory tree if only a single type is present in a deep hierarchy

# Lexicon
We define a namespace for Lexicon type, but this repo is not intended to define and be up to date with
all lexicon types.

Applications are expected to define their own lexicon types, see [AtprotoOAuth](https://github.com/germ-network/AtprotoOAuth) for examples.

We intend to demonstrate codegen for defining swift types from lexicon.


### Linting and Practices
The repo has a .editorconfig and .swift-format setup. We use both swift
formatter and linter:
```
swift format . -ri && swift format lint . -r
```

We also use the [periphery static analyzer](https://github.com/peripheryapp/periphery) and have a configured `periphery.yml`
