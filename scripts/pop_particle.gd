extends CPUParticles3D

static var _particle_mat_cache: Dictionary = {}

func init(color: Color) -> void:
	var key = color.to_html(false)
	var mat: StandardMaterial3D = _particle_mat_cache.get(key)
	if not mat:
		mat = StandardMaterial3D.new()
		mat.albedo_color = color
		mat.roughness = 0.5
		mat.shading_mode = BaseMaterial3D.SHADING_MODE_PER_VERTEX
		_particle_mat_cache[key] = mat
		
	material_override = mat
	emitting = true
	
	var timer = get_tree().create_timer(lifetime + 0.05)
	timer.timeout.connect(queue_free)
