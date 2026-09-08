class_name SimSnapshot
extends RefCounted
## Version 1 canonical data uses sorted string dictionary keys and Godot 4's
## little-endian Variant encoding (objects forbidden). Scalar floats retain
## IEEE-754 binary64 precision, vectors retain the engine's component precision;
## INF sentinels survive unchanged. There is no decimal quantization and no
## promise of identical physics across engine versions or architectures.
## JSON transport wraps those bytes in base64 rather than losing Vector types,
## large integers or the air_peak_height = -INF sentinel in JSON numbers.

const VERSION := 1
const ENCODING := "godot4-variant-le-base64"


static func fields(object: Object, names: Array) -> Dictionary:
	var out := {}
	for key in names:
		var value: Variant = object.get(key)
		out[key] = value.duplicate(true) if value is Array or value is Dictionary else value
	return out


static func restore_fields(object: Object, data: Dictionary, names: Array) -> void:
	for key in names:
		if data.has(key):
			var value: Variant = data[key]
			object.set(key, value.duplicate(true) if value is Array or value is Dictionary else value)


static func canonical(value: Variant) -> Variant:
	if value is Dictionary:
		var keys: Array = value.keys()
		keys.sort()
		var out := {}
		for key in keys:
			out[key] = canonical(value[key])
		return out
	if value is Array:
		var out := []
		for item in value:
			out.append(canonical(item))
		return out
	return value


## Boundary validation before restoring versioned data. Arrays have variable
## length (checkpoint history/events); their entries are validated by callers.
static func same_shape(value: Variant, expected: Variant) -> bool:
	if typeof(value) != typeof(expected):
		return false
	if value is Dictionary:
		if value.size() != expected.size():
			return false
		for key in expected:
			if not value.has(key) or not same_shape(value[key], expected[key]):
				return false
	return true


## Transported gameplay data contains scalar/vector numbers inside dictionaries
## and arrays. Callers must handle any field-specific sentinel before this check.
static func all_numbers_finite(value: Variant) -> bool:
	if value is float:
		return is_finite(value)
	if value is Vector2 or value is Vector3:
		return value.is_finite()
	if value is Dictionary:
		for key in value:
			if not all_numbers_finite(value[key]):
				return false
	elif value is Array:
		for item in value:
			if not all_numbers_finite(item):
				return false
	return true


static func digest(data: Dictionary) -> String:
	var ctx := HashingContext.new()
	ctx.start(HashingContext.HASH_SHA256)
	ctx.update(var_to_bytes(canonical(data)))
	return ctx.finish().hex_encode()


static func encode(data: Dictionary) -> String:
	var encoded := Marshalls.raw_to_base64(var_to_bytes(canonical(data)))
	return JSON.stringify({
		"version": VERSION, "encoding": ENCODING,
		"data": encoded, "data_sha256": encoded.sha256_text(),
	})


static func decode(text: String) -> Dictionary:
	var envelope: Variant = JSON.parse_string(text)
	if not envelope is Dictionary or envelope.get("version") != VERSION \
			or envelope.get("encoding") != ENCODING or not envelope.get("data") is String \
			or envelope.get("data_sha256") != envelope.data.sha256_text():
		return {}
	var bytes := Marshalls.base64_to_raw(envelope.data)
	if bytes.size() < 8 or bytes.decode_u32(0) != TYPE_DICTIONARY:
		return {}
	# bytes_to_var never instantiates objects (unlike bytes_to_var_with_objects).
	var data: Variant = bytes_to_var(bytes)
	return data if data is Dictionary else {}
