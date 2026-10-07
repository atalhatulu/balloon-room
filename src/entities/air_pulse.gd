extends Node3D

func _ready() -> void:
	# World-space rings originate at the glove and travel along the aim direction.
	# One short-lived node per input; the cooldown bounds simultaneous effects.
	for i in range(3):
		var ring := MeshInstance3D.new()
		var mesh_ring := TorusMesh.new()
		mesh_ring.inner_radius = 0.91
		mesh_ring.outer_radius = 1.0
		mesh_ring.rings = 32
		mesh_ring.ring_segments = 5
		ring.mesh = mesh_ring
		ring.rotation.x = PI / 2.0
		ring.scale = Vector3.ONE * 0.06
		ring.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		var mat := StandardMaterial3D.new()
		mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		mat.albedo_color = Color(0.65, 0.93, 1.0, 0.26)
		ring.material_override = mat
		add_child(ring)
		var tween := create_tween()
		tween.tween_interval(i * 0.035)
		tween.tween_property(ring, "position:z", -4.5, 0.30).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		tween.parallel().tween_property(ring, "scale", Vector3.ONE * 0.95, 0.30)
		tween.parallel().tween_property(mat, "albedo_color:a", 0.0, 0.30)
	get_tree().create_timer(0.45).timeout.connect(queue_free)
