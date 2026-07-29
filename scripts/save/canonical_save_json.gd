class_name CanonicalSaveJson
extends RefCounted

const FLOAT_DECIMAL_PLACES: int = 17


static func encode(value: Variant) -> String:
	return _encode(value, false)


static func encode_legacy(value: Variant) -> String:
	return _encode(value, true)


static func _encode(value: Variant, legacy_float_format: bool) -> String:
	match typeof(value):
		TYPE_NIL:
			return "null"
		TYPE_BOOL, TYPE_INT, TYPE_STRING:
			return JSON.stringify(value)
		TYPE_FLOAT:
			if is_nan(value) or is_inf(value):
				return ""
			if value == floorf(value):
				return str(int(value))
			if legacy_float_format:
				return JSON.stringify(value)
			return String.num(value, FLOAT_DECIMAL_PLACES)
		TYPE_STRING_NAME:
			return JSON.stringify(String(value))
		TYPE_ARRAY:
			var array_parts: PackedStringArray = []
			for item: Variant in value:
				var encoded_item: String = _encode(
					item,
					legacy_float_format
				)
				if encoded_item.is_empty():
					return ""
				array_parts.append(encoded_item)
			return "[" + ",".join(array_parts) + "]"
		TYPE_DICTIONARY:
			var key_lookup: Dictionary[String, Variant] = {}
			var keys: PackedStringArray = []
			for raw_key: Variant in value:
				if (
					typeof(raw_key) != TYPE_STRING
					and typeof(raw_key) != TYPE_STRING_NAME
				):
					return ""
				var key: String = String(raw_key)
				if key_lookup.has(key):
					return ""
				key_lookup[key] = raw_key
				keys.append(key)
			keys.sort()
			var object_parts: PackedStringArray = []
			for key: String in keys:
				var encoded_value: String = _encode(
					value[key_lookup[key]],
					legacy_float_format
				)
				if encoded_value.is_empty():
					return ""
				object_parts.append(
					JSON.stringify(key) + ":" + encoded_value
				)
			return "{" + ",".join(object_parts) + "}"
		_:
			return ""


static func sha256(value: Variant) -> String:
	var encoded: String = encode(value)
	return "" if encoded.is_empty() else encoded.sha256_text()


static func sha256_legacy(value: Variant) -> String:
	var encoded: String = encode_legacy(value)
	return "" if encoded.is_empty() else encoded.sha256_text()
