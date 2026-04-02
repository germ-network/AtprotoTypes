# @germ-network/atprototypes

## 0.1.2

### Patch Changes

- [#9](https://github.com/germ-network/AtprotoTypes/pull/9) [`1c53ffa`](https://github.com/germ-network/AtprotoTypes/commit/1c53ffa69759fd022ca5fbf82a34d50da6c8244d) Thanks [@germ-mark](https://github.com/germ-mark)! - add a public init for Atproto.DiDDocument

## 0.1.1

### Patch Changes

- [#7](https://github.com/germ-network/AtprotoTypes/pull/7) [`4f3cc4b`](https://github.com/germ-network/AtprotoTypes/commit/4f3cc4bf65ab21834c2dfc74e1ffdc3779a567c0) Thanks [@germ-mark](https://github.com/germ-mark)! - correctly point to version 0.1.1 of GermConvenience instead of a branch

## 0.1.0

### Minor Changes

- [#2](https://github.com/germ-network/AtprotoTypes/pull/2) [`6f0e4cd`](https://github.com/germ-network/AtprotoTypes/commit/6f0e4cd2370dcf27d5ec9a5a856ca1aacefe597c) Thanks [@germ-mark](https://github.com/germ-mark)! - In this PR:

  - All XRPC calls get a `Parameters` type
  - Procedures get an `Input` type
  - We define an empty query params (which most procedures will use)
  - Rename the xrpc` Result` to `Output`
  - rename xrpc `acceptValue` -> `outputEncoding`

### Patch Changes

- [#3](https://github.com/germ-network/AtprotoTypes/pull/3) [`1326dc1`](https://github.com/germ-network/AtprotoTypes/commit/1326dc1004b61ed3f39a887e986a6d58408774f1) Thanks [@germ-mark](https://github.com/germ-mark)! - stacking on top of PR2, narrow xrpc response parsing for

  - the error codes defined in the api spec
  - the error values defined in lexicon
  - the error schema defined for atproto xrpc (https://atproto.com/specs/xrpc#error-responses)
