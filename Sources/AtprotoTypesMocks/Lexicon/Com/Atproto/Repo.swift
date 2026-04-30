//
//  Repo.swift
//  AtprotoTypesMocks
//
//  Created by Mark @ Germ on 4/12/26.
//

import AtprotoTypes
import Foundation
import Mockable

extension Lexicon.Com.Atproto.Repo.GetRecord.Output: Mockable where Result: Mockable {
	public static func mock() throws -> Self {
		.init(
			uri: .mock(),
			cid: Atproto.CID.mock().string,
			value: try .mock()
		)
	}
}

extension Lexicon.Com.Atproto.Repo.DeleteRecord.Output: Mockable {
	public static func mock() throws -> Lexicon.Com.Atproto.Repo.DeleteRecordOutput {
		.init(commit: .init(cid: .mock(), rev: .mock()))
	}
}

extension Lexicon.Com.Atproto.Repo.ListRecords.Output: Mockable where Result: Mockable {
	public static func mock() throws -> Self {
		.init(
			cursor: UUID().uuidString,
			records: [
				.init(
					uri: .mock(),
					cid: Atproto.CID.mock(),
					value: try .mock()
				)
			]
		)
	}
}

extension Lexicon.Com.Atproto.Repo.PutRecord.Output: Mockable {
	public static func mock() throws -> Lexicon.Com.Atproto.Repo.PutRecordOutput {
		.init(
			uri: "example",
			cid: "example",
			commit: try .mock(),
			validationStatus: .unknown
		)
	}
}

extension Lexicon.Com.Atproto.Repo.Defs.CommitMeta: Mockable {
	public static func mock() throws -> Lexicon.Com.Atproto.Repo.Defs.CommitMeta {
		.init(
			cid: .mock(),
			rev: .mock()
		)
	}
}
