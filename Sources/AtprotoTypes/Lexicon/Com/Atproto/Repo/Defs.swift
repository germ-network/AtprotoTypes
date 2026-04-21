//
//  Defs.swift
//  AtprotoTypes
//
//  Created by Mark @ Germ on 4/20/26.
//

extension Lexicon.Com.Atproto.Repo {
	public enum Defs {
		public struct CommitMeta: Codable, Sendable {
			public let cid: Atproto.CID
			public let rev: Atproto.TID
			public init(cid: Atproto.CID, rev: Atproto.TID) {
				self.cid = cid
				self.rev = rev
			}
		}
	}
}
