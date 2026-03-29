class_name PuzzleCodec
extends RefCounted

## Encodes and decodes puzzle configurations as shareable strings.
##
## Two formats are supported, chosen automatically on encode:
## - "PZ:" prefix + raw JSON (when shorter)
## - "PZB:" prefix + base64-encoded JSON (when shorter)

const PREFIX_RAW := "PZ:"
const PREFIX_B64 := "PZB:"


static func encode(config: Dictionary) -> String:
	var json_str := JSON.stringify(config)
	var b64_str := Marshalls.raw_to_base64(json_str.to_utf8_buffer())
	var raw_code := PREFIX_RAW + json_str
	var b64_code := PREFIX_B64 + b64_str
	if raw_code.length() <= b64_code.length():
		return raw_code
	return b64_code


static func decode(code: String) -> Dictionary:
	if code.begins_with(PREFIX_RAW):
		var json_str := code.substr(PREFIX_RAW.length())
		return _parse_json(json_str)
	elif code.begins_with(PREFIX_B64):
		var b64_str := code.substr(PREFIX_B64.length())
		var decoded_bytes := Marshalls.base64_to_raw(b64_str)
		if decoded_bytes.is_empty():
			return {"config": {}, "error": "Failed to decode base64 data."}
		var json_str := decoded_bytes.get_string_from_utf8()
		return _parse_json(json_str)
	else:
		return {"config": {}, "error": "Invalid puzzle code: must start with 'PZ:' or 'PZB:'."}


static func _parse_json(json_str: String) -> Dictionary:
	var parsed = JSON.parse_string(json_str)
	if typeof(parsed) != TYPE_DICTIONARY:
		return {"config": {}, "error": "Invalid puzzle code: JSON did not parse into a dictionary."}
	return {"config": parsed, "error": ""}
