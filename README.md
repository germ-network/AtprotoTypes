Primitive types for [atproto](https://atproto.com).

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