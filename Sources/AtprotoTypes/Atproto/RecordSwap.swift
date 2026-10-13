//
//  RecordSwap.swift
//  AtprotoTypes
//

import Foundation

extension Atproto {
	/// A non-nil `swapRecord` on `com.atproto.repo.putRecord`. The lexicon lists
	/// `swapRecord` as `nullable`, and the Lexicon spec (`object`) holds that "there
	/// is a semantic difference in data between omitting a field; including the
	/// field with the value `null`" — so `absent` is sent as JSON `null`, and an
	/// omitted swap is `nil` at the call site, never a case here.
	///
	/// The reference PDS (bluesky-social/atproto, `formatCommit`) treats `null` as
	/// "no record may exist at this key" and rejects the write with `InvalidSwap`
	/// otherwise; that meaning is the PDS's, not the lexicon's.
	public enum RecordSwap: Sendable, Hashable {
		case absent
		case record(Atproto.CID)
	}
}
