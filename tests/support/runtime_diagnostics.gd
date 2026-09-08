class_name TestDiagnostics
extends Logger
## Test-only capture; expected diagnostics are explicit and counted per scope.

var entries: Array[Dictionary] = []
var _expected: Dictionary = {}
var _scope_start: int = 0
var _mutex := Mutex.new()
var _active := false


func start() -> void:
	if not _active:
		OS.add_logger(self)
		_active = true


func stop() -> void:
	if _active:
		OS.remove_logger(self)
		_active = false


func begin_scope(expected: Dictionary = {}) -> void:
	_mutex.lock()
	_scope_start = entries.size()
	_expected = expected.duplicate()
	_mutex.unlock()


func _log_error(
	function: String, file: String, line: int, code: String, rationale: String,
	_editor_notify: bool, error_type: int, _script_backtraces: Array[ScriptBacktrace]
) -> void:
	var message := rationale if not rationale.is_empty() else code
	var fatal := error_type != ERROR_TYPE_WARNING or "invariant" in message.to_lower()
	_mutex.lock()
	var expected := false
	for prefix in _expected:
		if int(_expected[prefix]) > 0 and message.begins_with(str(prefix)):
			_expected[prefix] -= 1
			expected = true
			break
	entries.append({
		"message": message, "file": file, "line": line, "function": function,
		"type": error_type, "fatal": fatal, "expected": expected,
	})
	_mutex.unlock()


func failures() -> Array:
	_mutex.lock()
	var out: Array = []
	for entry in entries.slice(_scope_start):
		if entry.fatal and not entry.expected:
			out.append(entry.duplicate())
	for prefix in _expected:
		if int(_expected[prefix]) > 0:
			out.append({"message": "Missing expected diagnostic: %s (%d)" % [prefix, _expected[prefix]]})
	_mutex.unlock()
	return out


func unexpected_count() -> int:
	_mutex.lock()
	var count := 0
	for entry in entries:
		if entry.fatal and not entry.expected:
			count += 1
	_mutex.unlock()
	return count
