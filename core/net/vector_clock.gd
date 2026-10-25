class_name VectorClock
extends RefCounted

## Vector Clock implementation for causal ordering in distributed UniCORE network.
## Maintains logical time across peers and detects causal precedence / concurrency.

var _clock: Dictionary = {} # peer_id (int) -> counter (int)

func increment(peer_id: int) -> void:
	var current: int = get_counter(peer_id)
	_clock[peer_id] = current + 1
	if _clock.has(str(peer_id)):
		_clock.erase(str(peer_id))

func get_clock() -> Dictionary:
	return _clock.duplicate()

func get_counter(peer_id: int) -> int:
	if _clock.has(peer_id):
		return int(_clock[peer_id])
	if _clock.has(str(peer_id)):
		return int(_clock[str(peer_id)])
	return 0

func merge(other_dict: Dictionary) -> void:
	for k in other_dict:
		var peer_id: int = int(k)
		var remote_val: int = int(other_dict[k])
		var local_val: int = get_counter(peer_id)
		_clock[peer_id] = maxi(local_val, remote_val)
		if _clock.has(str(peer_id)):
			_clock.erase(str(peer_id))

func is_concurrent(other_dict: Dictionary) -> bool:
	return not _is_le(_clock, other_dict) and not _is_le(other_dict, _clock)

func is_before(other_dict: Dictionary) -> bool:
	return _is_le(_clock, other_dict) and not _is_le(other_dict, _clock)

func to_dict() -> Dictionary:
	return _clock.duplicate()

static func from_dict(d: Dictionary) -> RefCounted:
	var script: GDScript = load("res://core/net/vector_clock.gd")
	var vc = script.new()
	vc.merge(d)
	return vc

func duplicate_clock() -> RefCounted:
	var script: GDScript = get_script()
	var copy = script.new()
	copy._clock = _clock.duplicate()
	return copy

func _is_le(a: Dictionary, b: Dictionary) -> bool:
	for k in a:
		var peer_id: int = int(k)
		var val_a: int = int(a[k])
		if val_a <= 0:
			continue
		var val_b: int = 0
		if b.has(peer_id):
			val_b = int(b[peer_id])
		elif b.has(str(peer_id)):
			val_b = int(b[str(peer_id)])
		if val_a > val_b:
			return false
	return true
