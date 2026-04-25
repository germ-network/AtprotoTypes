//
//  Primitive.swift
//  AtprotoTypes
//
//  Created by Mark @ Germ on 4/13/26.
//

//https://atproto.com/specs/data-model#data-types
extension Atproto {
	public enum Primitive {
		//boolean <> Swift boolean
		//integer (signed, 64-bit) <> Int64
		//string (Unicode, UTF-8) <> String (see lexicon String)
		//no floats
		//bytes <> Primitive.Bytes
		//cid-link <> Primitive.Link
		//array <> array, may need a prototol to allow heterogenous
		//object <> ...
		//blob: <> Primitive.Blob
	}
}
