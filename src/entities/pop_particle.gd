extends CPUParticles3D

static var _particle_mat_cache: Dictionary = {}

func init(color: Color, tier: int = 1, kind: String = "normal") -> void:
	var tint := color
	var glow := 0.0
	match kind:
		"bomb":
			tint = Color(1.0, 0.34, 0.08)
			amount = 18
			lifetime = 0.38
			initial_velocity_min = 4.0
			initial_velocity_max = 7.0
			glow = 2.0
		"air":
			tint = Color(0.65, 0.94, 1.0)
			amount = 12
			lifetime = 0.32
			gravity = Vector3.ZERO
			initial_velocity_max = 6.0
			glow = 0.6
		"gold", "bonus_coin", "bonus_magnet":
			tint = Color("b98cff") if kind == "bonus_magnet" else Color(1.0, 0.78, 0.16)
			amount = 16
			lifetime = 0.55
			spread = 65.0
			gravity = Vector3(0, -3, 0)
			glow = 1.5
		"electric", "cryo":
			amount = 12
			lifetime = 0.3
			glow = 1.2
		_:
			amount = 8 if tier < 10 else 12
	var key := tint.to_html(false) + kind
	var mat: StandardMaterial3D = _particle_mat_cache.get(key)
	if not mat:
		mat = StandardMaterial3D.new()
		mat.albedo_color = tint
		mat.roughness = 0.45
		mat.shading_mode = BaseMaterial3D.SHADING_MODE_PER_VERTEX
		mat.emission_enabled = glow > 0.0
		mat.emission = tint
		mat.emission_energy_multiplier = glow
		_particle_mat_cache[key] = mat
	material_override = mat
	cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	if kind in ["bomb", "air", "electric", "bonus_coin", "bonus_magnet"]:
		_add_ripple(tint, 2.0 if kind == "bomb" else 2.8)
	if kind == "normal":
		lifetime = 0.28
		initial_velocity_min = 2.8
		initial_velocity_max = 4.5
		angular_velocity_min = -180.0
		angular_velocity_max = 180.0
	emitting = true
	get_tree().create_timer(lifetime + 0.08).timeout.connect(queue_free)

func _add_ripple(color: Color, radius: float) -> void:
	var ring := MeshInstance3D.new()
	var mesh_ring := TorusMesh.new()
	mesh_ring.inner_radius = 0.94
	mesh_ring.outer_radius = 1.0
	mesh_ring.rings = 32
	mesh_ring.ring_segments = 6
	ring.mesh = mesh_ring
	ring.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var mat := StandardMaterial3D.new()
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.albedo_color = Color(color, 0.55)
	ring.material_override = mat
	add_child(ring)
	ring.scale = Vector3.ONE * 0.15
	var tween := create_tween().set_parallel(true)
	tween.tween_property(ring, "scale", Vector3.ONE * radius, 0.28).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween.tween_property(mat, "albedo_color:a", 0.0, 0.28)
