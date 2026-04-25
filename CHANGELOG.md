# @germ-network/atprototypes

## 0.3.4

### Patch Changes

- [#31](https://github.com/germ-network/AtprotoTypes/pull/31) [`d591b88`](https://github.com/germ-network/AtprotoTypes/commit/d591b88d848ebd92e5b9d007ad3626452afd2bd7) Thanks [@anna-germ](https://github.com/anna-germ)! - Adjust datetime formatting rules

## 0.3.3

### Patch Changes

- [#29](https://github.com/germ-network/AtprotoTypes/pull/29) [`357543e`](https://github.com/germ-network/AtprotoTypes/commit/357543e67eee86f672d88051492c0ed723026f0d) Thanks [@anna-germ](https://github.com/anna-germ)! - Add Datetime object for ISO 8601 encoding

## 0.3.2

### Patch Changes

- [#27](https://github.com/germ-network/AtprotoTypes/pull/27) [`edd73f8`](https://github.com/germ-network/AtprotoTypes/commit/edd73f8cc74432ebc959aa7651e4eafdf59c818c) Thanks [@germ-mark](https://github.com/germ-mark)! - correctly parse bare data when result is a Data

## 0.3.1

### Patch Changes

- [#24](https://github.com/germ-network/AtprotoTypes/pull/24) [`7fd9ad0`](https://github.com/germ-network/AtprotoTypes/commit/7fd9ad0ddb245d937acebf26d14a403e6b919b57) Thanks [@anna-germ](https://github.com/anna-germ)! - Remove at:// from DID Doc handle getter

## 0.3.0

### Minor Changes

- [#21](https://github.com/germ-network/AtprotoTypes/pull/21) [`abb4eaa`](https://github.com/germ-network/AtprotoTypes/commit/abb4eaacbb0aaed5fa9ed587781fec9cd267da7e) Thanks [@germ-mark](https://github.com/germ-mark)! - remove duplicate AtIdentifier.Handle typealias

- [#21](https://github.com/germ-network/AtprotoTypes/pull/21) [`3405f4b`](https://github.com/germ-network/AtprotoTypes/commit/3405f4bd684a205395d7bffdfca78f650dca5f77) Thanks [@germ-mark](https://github.com/germ-mark)! - fix schema for Lexicon.Com.Atproto.Repo.DeleteRecord to specify required rkey

## 0.2.3

### Patch Changes

- [#19](https://github.com/germ-network/AtprotoTypes/pull/19) [`289cc57`](https://github.com/germ-network/AtprotoTypes/commit/289cc5759dd28284942b6ea0097e55af388b4d2f) Thanks [@germ-mark](https://github.com/germ-mark)! - Make LexiconBytes' CodingKeys public
  Make LiteralRecordKey Equatable
  Add default implementation of Codable to LiteralRecordKey
  Import HTTPTypes as a dependency
  Add LiteralRecordKey tests

## 0.2.2

### Patch Changes

- [#17](https://github.com/germ-network/AtprotoTypes/pull/17) [`2676c83`](https://github.com/germ-network/AtprotoTypes/commit/2676c831876836d61c504b40c0c6e4079ed7b195) Thanks [@germ-mark](https://github.com/germ-mark)! - allow PutRecordResult encoding, access to PutRecord Input Schema properties for testing, remove duplicate PutRecord lexicon definiton

## 0.2.1

### Patch Changes

- [#13](https://github.com/germ-network/AtprotoTypes/pull/13) [`b23c992`](https://github.com/germ-network/AtprotoTypes/commit/b23c99210d22187d6b1aa115fb1f167405cc89ce) Thanks [@anna-germ](https://github.com/anna-germ)! - Add AT URI type

- [#13](https://github.com/germ-network/AtprotoTypes/pull/13) [`0746bcc`](https://github.com/germ-network/AtprotoTypes/commit/0746bcc67b2ccbbdce8629d84300c47a82c30422) Thanks [@anna-germ](https://github.com/anna-germ)! - Make AtIdentifier Decodable

- [#15](https://github.com/germ-network/AtprotoTypes/pull/15) [`17e2176`](https://github.com/germ-network/AtprotoTypes/commit/17e21768474c3c80ed960b9d2fa6b975855c7891) Thanks [@germ-mark](https://github.com/germ-mark)! - Add a DefaultableRecordKey protocol for literal and TID record keys

- [#14](https://github.com/germ-network/AtprotoTypes/pull/14) [`eff8af3`](https://github.com/germ-network/AtprotoTypes/commit/eff8af3b115ae848fac1ce0ca82c05cf359bac4c) Thanks [@germ-mark](https://github.com/germ-mark)! - Change to a RecordKey Protocol, which has
  - a LiteralRecordKey protocol for literals
  - conformance for the AnyRecordKey, NSID, and TID Record key types

## 0.2.0

### Minor Changes

- [#11](https://github.com/germ-network/AtprotoTypes/pull/11) [`36c5500`](https://github.com/germ-network/AtprotoTypes/commit/36c5500959137da32d8ec8cbe9e00dfd4991725a) Thanks [@anna-germ](https://github.com/anna-germ)! - Add support for deleting records from repos

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

- [#11](https://github.com/germ-network/AtprotoTypes/pull/11) [`586171e`](https://github.com/germ-network/AtprotoTypes/commit/586171e020d409644ebfb4ce92773e893774b380) Thanks [@anna-germ](https://github.com/anna-germ)! - Add record key struct and replace record key typealias

### Patch Changes

- [#11](https://github.com/germ-network/AtprotoTypes/pull/11) [`290c344`](https://github.com/germ-network/AtprotoTypes/commit/290c3447e2c24ffa6545fde353ab574f43636e71) Thanks [@anna-germ](https://github.com/anna-germ)! - Add Atproto TID type

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
