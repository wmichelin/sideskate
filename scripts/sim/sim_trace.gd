class_name SimTrace
extends RefCounted
## Bounded diagnostic history; complete recording is an explicit opt-in.
## final_hash() hashes the current complete gameplay snapshot on demand.
## replay_hashes() covers only retained diagnostic frames, in chronological order.
## An explicit recording independently preserves all events (or streams to JSONL).

const RECENT_FRAME_LIMIT := 180
var model_hash: String = ""
var capacity: int = RECENT_FRAME_LIMIT:
	set(value):
		capacity = maxi(value, 0)
		_frames.clear()
		_head = 0
var total_frames: int = 0
var total_ticks: int = 0
var frames: Array:
	get:
		if _head == 0:
			return _frames.duplicate()
		return _frames.slice(_head) + _frames.slice(0, _head)
var recording: bool = false
var recording_error: String = ""
var _frames: Array = []
var _head: int = 0
var _sim: WeakRef
var _recording: Dictionary = {}
var _stream: FileAccess
var _path: String = ""
var _event_count: int = 0
var _last_recorded_hash: String = ""
var _stream_bytes_expected: int = 0


func _init(hash_str: String = "", sim: PlayerSim = null) -> void:
	model_hash = hash_str
	if sim != null:
		_sim = weakref(sim)
	if not OS.is_debug_build() or "--no-debug-tools" in OS.get_cmdline_user_args():
		capacity = 0


func capture_event(sim: PlayerSim, kind: String, delta: float = 0.0) -> Dictionary:
	if capacity <= 0 and not recording:
		return {"kind": kind}
	var event := {"kind": kind, "input": sim.input_snapshot(), "delta": delta}
	if recording:
		event["tuning"] = sim.tuning_snapshot()
	return event


func record(sim: PlayerSim, event: Dictionary) -> void:
	total_frames += 1
	if event.get("kind") == "tick":
		total_ticks += 1
	if capacity > 0:
		# Retain typed values without serializing/hash-allocating every debug tick.
		# The ring never shifts its existing entries.
		var frame := {
			"index": total_frames - 1, "tick": sim.state.tick,
			"event": event.duplicate(true), "snapshot": sim.gameplay_snapshot(),
		}
		if _frames.size() < capacity:
			_frames.append(frame)
		else:
			_frames[_head] = frame
			_head = (_head + 1) % capacity
	elif not _frames.is_empty():
		_frames.clear()
		_head = 0
	if recording:
		_event_count += 1
		var saved := event.duplicate(true)
		saved["index"] = _event_count
		saved["hash"] = sim.gameplay_hash()
		_last_recorded_hash = saved.hash
		if _stream != null:
			_write({"event": saved})
		else:
			_recording.events.append(saved)


func final_hash() -> String:
	var sim: PlayerSim = _sim.get_ref() if _sim != null else null
	if sim != null:
		return sim.gameplay_hash()
	var retained := frames
	return PlayerSim.snapshot_hash(retained[-1].snapshot) if not retained.is_empty() else ""


func replay_hashes() -> PackedStringArray:
	var out := PackedStringArray()
	for frame in frames:
		out.append(PlayerSim.snapshot_hash(frame.snapshot))
	return out


func start_recording(sim: PlayerSim, path: String = "") -> bool:
	if recording:
		return false
	recording_error = ""
	_path = path
	if not path.is_empty():
		_stream = FileAccess.open(path, FileAccess.WRITE)
		if _stream == null:
			recording_error = "Cannot open recording: %s (%s)" % [path, FileAccess.get_open_error()]
			return false
	_event_count = 0
	_stream_bytes_expected = 0
	_last_recorded_hash = sim.gameplay_hash()
	_recording = {
		"version": SimSnapshot.VERSION, "model_hash": model_hash,
		"engine_version": Engine.get_version_info().string,
		"initial": sim.gameplay_snapshot(), "events": [],
	}
	recording = true
	if _stream != null:
		_write({"header": _recording})
	return recording_error.is_empty()


func stop_recording() -> Dictionary:
	if not recording:
		return {}
	var sim: PlayerSim = _sim.get_ref() if _sim != null else null
	# Input/tuning can change between the last physics tick and stopping a
	# recording (for example while paused). Preserve that pending command too.
	if sim != null and sim.gameplay_hash() != _last_recorded_hash:
		record(sim, capture_event(sim, "input"))
	_recording["event_count"] = _event_count
	_recording["final_hash"] = final_hash()
	if _stream != null:
		_write({"footer": {
			"event_count": _event_count, "final_hash": _recording.final_hash,
		}})
		_stream.flush()
		if _stream.get_error() != OK or _stream.get_length() != _stream_bytes_expected:
			recording_error = "Recording flush failed: %s" % _path
		_stream = null
	recording = false
	var result := _recording
	_recording = {}
	result["error"] = recording_error
	result["path"] = _path
	return result


func _write(data: Dictionary) -> void:
	var encoded := SimSnapshot.encode(data)
	_stream_bytes_expected += encoded.to_utf8_buffer().size() + 1
	_stream.store_line(encoded)
	if _stream.get_error() != OK:
		recording_error = "Recording write failed: %s" % _path


static func read_recording(path: String) -> Dictionary:
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		return {"error": "Cannot read recording: %s" % path}
	var result := {}
	var complete := false
	while file.get_position() < file.get_length():
		var row := SimSnapshot.decode(file.get_line())
		if complete or row.size() != 1:
			return {"error": "Invalid recording row"}
		if result.is_empty() and row.has("header"):
			if not row.header is Dictionary or not row.header.get("events") is Array \
					or not row.header.events.is_empty():
				return {"error": "Invalid recording header"}
			result = row.header
		elif not result.is_empty() and row.has("event"):
			if not row.event is Dictionary:
				return {"error": "Invalid recording event"}
			result.events.append(row.event)
		elif not result.is_empty() and row.has("footer"):
			if not row.footer is Dictionary:
				return {"error": "Invalid recording footer"}
			result.merge(row.footer, true)
			complete = true
		else:
			return {"error": "Invalid recording order"}
	if not complete:
		return {"error": "Recording is incomplete (missing footer)"}
	return result


## Replays against an already compiled identical model and compares every event,
## including commands between ticks. Global tunables are restored before return.
static func replay(data: Dictionary, sim: PlayerSim) -> Dictionary:
	if not str(data.get("error", "")).is_empty():
		return {"ok": false, "error": data.error}
	if data.get("version") != SimSnapshot.VERSION or sim.model == null \
			or data.get("model_hash") != sim.model.model_hash:
		return {"ok": false, "error": "Recording version/model mismatch"}
	if data.get("engine_version") != Engine.get_version_info().string:
		return {"ok": false, "error": "Recording engine version mismatch"}
	if not data.get("initial") is Dictionary or not data.get("events") is Array \
			or data.get("event_count", -1) != data.events.size():
		return {"ok": false, "error": "Recording is incomplete"}
	var saved_tuning := sim.tuning_snapshot()
	var result := _replay_events(data, sim)
	sim.apply_tuning(saved_tuning)
	return result


static func _replay_events(data: Dictionary, sim: PlayerSim) -> Dictionary:
	if not sim.restore_snapshot(data.initial):
		return {"ok": false, "error": "Invalid recording initial state"}
	var index := 0
	for event in data.events:
		index += 1
		if not event is Dictionary or event.get("index") != index \
				or not event.get("input") is Dictionary or not event.get("tuning") is Dictionary:
			return {"ok": false, "index": index, "error": "Invalid recording event"}
		if event.get("kind") not in ["input", "tick", "fall", "respawn"]:
			return {"ok": false, "index": index, "error": "Unknown recording command"}
		if event.kind == "tick" and (not event.get("delta") is float \
				or not is_finite(event.delta) or event.delta <= 0.0):
			return {"ok": false, "index": index, "error": "Invalid physics delta"}
		if not SimSnapshot.same_shape(event.input, sim.input_snapshot()) \
				or not SimSnapshot.all_numbers_finite(event.input) \
				or not sim.apply_tuning(event.tuning):
			return {"ok": false, "index": index, "error": "Invalid recording input/tuning"}
		sim.restore_input(event.input)
		match event.get("kind"):
			"input":
				pass # Input/tuning were applied above; do not advance physics.
			"tick":
				sim.tick(event.delta)
			"fall":
				sim.begin_fall()
			"respawn":
				sim.respawn()
		if sim.gameplay_hash() != event.get("hash"):
			return {"ok": false, "index": index, "error": "Gameplay checkpoint mismatch"}
	var hash_str := sim.gameplay_hash()
	if hash_str != data.get("final_hash"):
		return {"ok": false, "index": index, "error": "Final gameplay checkpoint mismatch"}
	return {
		"ok": true, "events": index, "final_hash": hash_str,
		"final_snapshot": sim.gameplay_snapshot(),
	}
