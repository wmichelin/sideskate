class_name SimTrace
extends RefCounted
## Deterministic tick trace for replay / golden hashes.


var model_hash: String = ""
var frames: Array = []


func _init(hash_str: String = "") -> void:
	model_hash = hash_str


func record(state: SimState, wish: Vector2, action: bool) -> void:
	frames.append({
		"tick": state.tick,
		"hash": state.state_hash(),
		"wish": wish,
		"action": action,
		"mode": state.mode,
		"pos": state.position,
	})


func final_hash() -> String:
	if frames.is_empty():
		return ""
	return str(frames[frames.size() - 1].hash)


func replay_hashes() -> PackedStringArray:
	var out := PackedStringArray()
	for f in frames:
		out.append(str(f.hash))
	return out
