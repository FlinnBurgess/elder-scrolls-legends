class_name DeckStrategyCode
extends RefCounted

## Encode/decode a deck strategy as a shareable code.
##
## The strategy schema is heterogeneous and structured, so dense base-26 like
## DeckCode is impractical. Format: prefix "SS1:" + base64(JSON(strategy)).
## Compact enough to copy/paste, robust to any rule shape, version-tagged.
##
## On decode, callers should re-validate the result against the target deck so
## dangling card references surface in the strategy editor's warning banner.

const PREFIX := "SS1:"


static func encode(strategy: Dictionary) -> Dictionary:
	var json_text := JSON.stringify(strategy)
	var bytes := json_text.to_utf8_buffer()
	var b64 := Marshalls.raw_to_base64(bytes)
	return {"code": PREFIX + b64, "error": ""}


static func decode(code: String) -> Dictionary:
	var trimmed := code.strip_edges()
	if not trimmed.begins_with(PREFIX):
		return {"strategy": {}, "error": "Invalid strategy code: must start with '%s'" % PREFIX}
	var b64 := trimmed.substr(PREFIX.length())
	var bytes := Marshalls.base64_to_raw(b64)
	if bytes == null or bytes.is_empty():
		return {"strategy": {}, "error": "Strategy code payload is empty or malformed."}
	var json_text := bytes.get_string_from_utf8()
	if json_text.is_empty():
		return {"strategy": {}, "error": "Strategy code payload is not valid UTF-8."}
	var json := JSON.new()
	var err := json.parse(json_text)
	if err != OK:
		return {"strategy": {}, "error": "Strategy code JSON parse failed: %s" % json.get_error_message()}
	if typeof(json.data) != TYPE_DICTIONARY:
		return {"strategy": {}, "error": "Strategy code did not decode to a dictionary."}
	var strategy: Dictionary = json.data
	if not strategy.has("rules"):
		strategy["rules"] = []
	return {"strategy": strategy, "error": ""}
