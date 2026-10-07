class_name DispenserBox
extends Node3D

const CHUTE_DIRS: Array[Vector3] = [
	Vector3(0, 0, 1),   # 0: North (+Z in room space)
	Vector3(1, 0, 0),   # 1: East (+X in room space)
	Vector3(0, 0, -1),  # 2: South (-Z in room space)
	Vector3(-1, 0, 0)   # 3: West (-X in room space)
]

const CHUTE_NAMES: Array[String] = ["ChuteN", "ChuteE", "ChuteS", "ChuteW"]
const HOLE_NAMES: Array[String] = ["HoleN", "HoleE", "HoleS", "HoleW"]

var _cycle_idx: int = 0
var allowed_chute_indices: Array[int] = [0, 1, 2, 3]

func configure_allowed_chutes(allowed: Array[int]) -> void:
	allowed_chute_indices = allowed
	for i in range(4):
		var is_enabled = (i in allowed)
		var chute_node = get_node_or_null(CHUTE_NAMES[i])
		if chute_node:
			chute_node.visible = is_enabled
		var hole_node = get_node_or_null(HOLE_NAMES[i])
		if hole_node:
			hole_node.visible = is_enabled

func get_next_chute_ejection(custom_step: int = -1) -> Dictionary:
	if allowed_chute_indices.is_empty():
		allowed_chute_indices = [0, 1, 2, 3]
		
	var pool_idx = (_cycle_idx if custom_step < 0 else custom_step) % allowed_chute_indices.size()
	if custom_step < 0:
		_cycle_idx = (_cycle_idx + 1) % allowed_chute_indices.size()
		
	var idx = allowed_chute_indices[pool_idx]
	var dir = CHUTE_DIRS[idx]
	var mouth_offset = Vector3(dir.x * 0.88, -0.06, dir.z * 0.88)
	var spawn_pos = global_position + mouth_offset
	
	trigger_chute_recoil(idx)
	
	return {
		"position": spawn_pos,
		"direction": dir,
		"chute_index": idx
	}

func trigger_chute_recoil(idx: int) -> void:
	if idx < 0 or idx >= CHUTE_NAMES.size(): return
	var chute_node = get_node_or_null(CHUTE_NAMES[idx])
	if not chute_node: return
	
	var tw = create_tween()
	var base_scale = Vector3.ONE
	tw.tween_property(chute_node, "scale", Vector3(1.15, 1.15, 1.15), 0.04).set_trans(Tween.TRANS_QUAD)
	tw.tween_property(chute_node, "scale", base_scale, 0.14).set_trans(Tween.TRANS_ELASTIC)
