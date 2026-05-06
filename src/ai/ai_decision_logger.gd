class_name AIDecisionLogger
extends RefCounted

## Dedicated log file for AI-decision telemetry. One line per call to
## `ISMCTSMatchPolicy.choose_action`, plus optional sub-event lines (e.g.
## per-MCTS-iteration breadcrumbs if requested).
##
## File path:
##   res://ai_decisions.log   (when running from the editor)
##   user://ai_decisions.log  (when running an exported build)
##
## File is wiped at the start of each match via `start_match()`. Lines are
## flushed eagerly so an inspector can `tail -f` while a match is in
## progress.
##
## Format: human-readable key=value pairs, one decision per line:
##   [iso_timestamp] turn=4 player=player_2 surface=12 path=mcts_converged ...
##
## Thread safety: `log_decision` may be called from the ISMCTS worker thread,
## so file access is guarded by a Mutex even though writes are typically
## sequential.

# Computed lazily — `OS.has_feature` isn't a compile-time constant in GDScript.
static var LOG_PATH: String = ""

static var _file: FileAccess = null
static var _mutex: Mutex = Mutex.new()
static var _enabled: bool = true


static func _resolve_log_path() -> String:
	if LOG_PATH.is_empty():
		LOG_PATH = "res://ai_decisions.log" if OS.has_feature("editor") else "user://ai_decisions.log"
	return LOG_PATH


static func is_enabled() -> bool:
	return _enabled


static func set_enabled(enabled: bool) -> void:
	_enabled = enabled


## Open a fresh log file for a new match. Call from MatchScreen on match
## start. Closes any prior file.
static func start_match() -> void:
	_mutex.lock()
	if _file != null:
		_file.close()
		_file = null
	if _enabled:
		var path := _resolve_log_path()
		_file = FileAccess.open(path, FileAccess.WRITE)
		if _file == null:
			push_error("AIDecisionLogger: cannot open %s for writing" % path)
		else:
			_file.store_line("=== AI DECISION LOG === %s" % Time.get_datetime_string_from_system())
			_file.flush()
	_mutex.unlock()


## Record a decision. `fields` is a flat Dictionary of primitive values; key
## ordering is preserved in the output line (insertion order).
static func log_decision(fields: Dictionary) -> void:
	if not _enabled:
		return
	_mutex.lock()
	if _file == null:
		# No active match log — fall back to printing.
		print("[AI_DECISION] %s" % _format(fields))
		_mutex.unlock()
		return
	var ts := Time.get_datetime_string_from_system()
	_file.store_line("[%s] %s" % [ts, _format(fields)])
	_file.flush()
	_mutex.unlock()


## Free-form log line (used for sub-events / breadcrumbs that don't fit the
## decision schema).
static func log_event(message: String) -> void:
	if not _enabled:
		return
	_mutex.lock()
	if _file == null:
		_mutex.unlock()
		return
	var ts := Time.get_datetime_string_from_system()
	_file.store_line("[%s] %s" % [ts, message])
	_file.flush()
	_mutex.unlock()


static func close() -> void:
	_mutex.lock()
	if _file != null:
		_file.close()
		_file = null
	_mutex.unlock()


static func _format(fields: Dictionary) -> String:
	var parts: PackedStringArray = PackedStringArray()
	for key in fields.keys():
		var value = fields[key]
		var rendered: String
		match typeof(value):
			TYPE_BOOL:
				rendered = "true" if value else "false"
			TYPE_FLOAT:
				rendered = "%.3f" % float(value)
			TYPE_STRING:
				# Quote if there's whitespace.
				if " " in value or "\t" in value:
					rendered = "\"%s\"" % str(value).replace("\"", "\\\"")
				else:
					rendered = str(value)
			_:
				rendered = str(value)
		parts.append("%s=%s" % [str(key), rendered])
	return " ".join(parts)
