extends RefCounted

static func press(target: Node3D, offset := Vector3(0, 0, 0.04)) -> void:
	if not is_instance_valid(target): return
	if not target.has_meta("control_rest"):
		target.set_meta("control_rest", target.position)
	if target.has_meta("control_tween"):
		var old = target.get_meta("control_tween")
		if old is Tween and old.is_valid(): old.kill()
	var rest: Vector3 = target.get_meta("control_rest")
	var tween := target.create_tween()
	target.set_meta("control_tween", tween)
	tween.tween_property(target, "position", rest + offset, 0.07).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	tween.tween_property(target, "position", rest, 0.17).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)

static func sound(source: Node3D, kind: String) -> void:
	var main = source.get_node_or_null("/root/Main")
	if main and main.sound_manager:
		main.sound_manager.play_interaction(kind, source.global_position)
