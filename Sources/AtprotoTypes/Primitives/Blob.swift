//
//  Blob.swift
//  AtprotoTypes
//
//  Pulled in by Anna Mistele on 3/3/26.
//  Created by Christopher Jr Riley on 5/20/24.
//

//Possible TODO: support legacy blob format

extension Atproto.Primitive {
	/// https://atproto.com/specs/blob
	public struct Blob: Sendable, Codable, Equatable {
		struct TypeValue: FixedString {
			static var fixedValue: String { "blob" }
		}

		//for encoding
		private let type = TypeValue()

		/// The strong reference of the blob.
		public let ref: Atproto.Primitive.Link

		/// The the MIME type.
		///
		/// This can be a `.jpg`, `.png`, and `.gif`.
		/// required not empty
		public let mimeType: String

		/// The size of the blob.
		public let size: Int

		enum CodingKeys: String, CodingKey {
			case type = "$type"
			case ref
			case mimeType
			case size
		}
	}
}
