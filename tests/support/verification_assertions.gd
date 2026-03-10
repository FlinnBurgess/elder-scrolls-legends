class_name VerificationAsserts
extends RefCounted


static func assert_true(condition: bool, message: String, failures: Array) -> bool:
	if condition:
		return true
	failures.append(message)
	return false


static func assert_equal(actual, expected, message: String, failures: Array) -> bool:
	if actual == expected:
		return true
	failures.append("%s\nExpected: %s\nActual: %s" % [message, _stable_string(expected), _stable_string(actual)])
	return false


static func assert_replay_contains_sequence(replay_signature: Array, expected_entries: Array, message: String, failures: Array) -> bool:
	var replay_index := 0
	for expected_entry in expected_entries:
		var found := false
		while replay_index < replay_signature.size():
			var actual_entry = replay_signature[replay_index]
			replay_index += 1
			if _value_contains(actual_entry, expected_entry):
				found = true
				break
		if not found:
			failures.append("%s\nExpected replay entry: %s\nActual replay: %s" % [message, _stable_string(expected_entry), _stable_string(replay_signature)])
			return false
	return true


static func _value_contains(actual, expected) -> bool:
	if typeof(expected) == TYPE_DICTIONARY:
		if typeof(actual) != TYPE_DICTIONARY:
			return false
		for key in expected.keys():
			if not actual.has(key) or not _value_contains(actual[key], expected[key]):
				return false
		return true
	if typeof(expected) == TYPE_ARRAY:
		if typeof(actual) != TYPE_ARRAY or actual.size() < expected.size():
			return false
		for index in range(expected.size()):
			if not _value_contains(actual[index], expected[index]):
				return false
		return true
	return actual == expected


static func _stable_string(value) -> String:
	match typeof(value):
		TYPE_DICTIONARY:
			var keys: Array = value.keys()
			keys.sort()
			var parts: Array = []
			for key in keys:
				parts.append("%s:%s" % [str(key), _stable_string(value[key])])
			return "{%s}" % ", ".join(parts)
		TYPE_ARRAY:
			var parts: Array = []
			for item in value:
				parts.append(_stable_string(item))
			return "[%s]" % ", ".join(parts)
		TYPE_STRING:
			return '"%s"' % String(value)
		_:
			return str(value)