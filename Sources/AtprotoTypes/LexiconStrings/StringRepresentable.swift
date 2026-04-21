//
//  StringRepresentable.swift
//  AtprotoTypes
//
//  Created by Mark @ Germ on 4/20/26.
//

import Foundation
import Logging

///Many types in Atproto are represented by strings with additional constraints
///We want automatically synthesized Codable from RawRepresentable<String>,
///but prefer a throwing init
extension Atproto {
	public protocol StringRepresentable: RawRepresentable<String> {
		init(string: String) throws
	}
}

//default implementation of RawRepresentable<String> init?
extension Atproto.StringRepresentable {
	public init?(rawValue: String) {
		do {
			try self.init(string: rawValue)
		} catch {
			Logger(label: "Atproto.StringRepresentable")
				.notice(
					"Failed to initialize \(Self.Type.self) from \(rawValue)"
				)
			return nil
		}
	}
}
