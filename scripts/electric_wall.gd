extends Node3D

@export var is_active: bool = false
@export var level: int = 1

# EMP Zap radius (horizontal reach) and vertical room-high ceiling reach
var zap_radii: Array[float] = [0.0, 5.0, 7.0, 9.5, 12.5, 16.0, 21.0]
var zap_heights: Array[float] = [0.0, 8.0, 11.0, 14.0, 18.0, 22.0, 28.0]
var cooldown_intervals: Array[float] = [0.0, 2.2, 1.7, 1.3, 0.95, 0.70, 0.50]
var max_burst_caps: Array[int] = [0, 35, 65, 110, 180, 280, 450]

var cooldown_timer: float = 0.0

@onready var frame_mesh: MeshInstance3D = get_node_or_null("FrameMesh")
@onready var neon_grid: MeshInstance3D = get_node_or_null("NeonGrid")
@onready var trigger_area: Area3D = get_node_or_null("TriggerArea")
@onready var trigger_shape: CollisionShape3D = get_node_or_null("TriggerArea/CollisionShape3D")
@onready var spark_particles: CPUParticles3D = get_node_or_null("SparkParticles")
@onready var arc_light: OmniLight3D = get_node_or_null("ArcLight")
@onready var sound_manager = get_node_or_null("/root/Main/SoundManager")

func _ready() -> void:
	add_to_group("devices")
	if trigger_area:
		trigger_area.collision_layer = 0
		trigger_area.collision_mask = 2
	update_visuals()

func setup_level(new_level: int) -> void:
	level = max(new_level, 1)
	is_active = (level > 0)
	visible = is_active
	update_visuals()

func update_visuals() -> void:
	if not is_active or level <= 0:
		visible = false
		if spark_particles: spark_particles.emitting = false
		return
		
	visible = true
	var idx = clamp(level, 1, zap_radii.size() - 1)
	var r = zap_radii[idx]
	var scale_factor = (r * 2.0) / 7.0
	
	if frame_mesh:
		frame_mesh.scale = Vector3(scale_factor, 1.0, scale_factor)
	if neon_grid:
		neon_grid.scale = Vector3(scale_factor, 1.0, scale_factor)
		if neon_grid.material_override is StandardMaterial3D:
			var mat = neon_grid.material_override as StandardMaterial3D
			mat.emission_energy_multiplier = 2.5 + (level * 1.0)
		
	if arc_light:
		arc_light.omni_range = max(8.0, r * 1.2)
		arc_light.light_energy = 0.5
		
	if spark_particles:
		spark_particles.emission_box_extents = Vector3(r * 0.75, 0.2, r * 0.75)

func _physics_process(delta: float) -> void:
	if not is_active or level <= 0:
		return
		
	cooldown_timer += delta
	var idx = clamp(level, 1, cooldown_intervals.size() - 1)
	var cd = cooldown_intervals[idx]
	
	# Visual charge buildup during final 0.5s of cooldown
	var remaining = cd - cooldown_timer
	if remaining <= 0.5:
		var charge_pct = 1.0 - (remaining / 0.5)
		if arc_light:
			arc_light.light_energy = 0.4 + charge_pct * 3.5
		if spark_particles and not spark_particles.emitting:
			spark_particles.emitting = true
	else:
		if arc_light:
			arc_light.light_energy = 0.4
		if spark_particles and spark_particles.emitting:
			spark_particles.emitting = false
			
	if cooldown_timer >= cd:
		cooldown_timer = 0.0
		process_electric_discharge()

func process_electric_discharge() -> void:
	var idx = clamp(level, 1, max_burst_caps.size() - 1)
	var max_burst = max_burst_caps[idx]
	var victims = get_targets_in_volume(max_burst)
	var zapped_count = 0
	
	for body in victims:
		if is_instance_valid(body) and not body.get("is_popped"):
			if body.has_method("pop"):
				body.pop("electric_grid")
				zapped_count += 1
				
	if zapped_count > 0:
		if sound_manager and sound_manager.has_method("play_zap"):
			sound_manager.play_zap()
			
		if arc_light:
			arc_light.light_energy = 7.5 + (level * 1.5)
			var tween = create_tween()
			tween.tween_property(arc_light, "light_energy", 0.4, 0.22).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)

func get_targets_in_volume(max_count: int) -> Array[RigidBody3D]:
	var list: Array[RigidBody3D] = []
	var world = get_world_3d()
	if not world: return list
	var space_state = world.direct_space_state
	if not space_state: return list
	
	var idx = clamp(level, 1, zap_radii.size() - 1)
	var r = zap_radii[idx]
	var h = zap_heights[idx]
	
	# Cylinder EMP shockwave (hits balloons on floor AND high in midair across the room)
	var query = PhysicsShapeQueryParameters3D.new()
	var cyl = CylinderShape3D.new()
	cyl.radius = r
	cyl.height = h
	query.shape = cyl
	query.transform = Transform3D(Basis(), global_position + Vector3(0, h * 0.5, 0))
	query.collision_mask = 2 # Balloons layer
	query.collide_with_bodies = true
	query.collide_with_areas = false
	
	var results = space_state.intersect_shape(query, max_count)
	for res in results:
		var col = res.collider
		if col is RigidBody3D and is_instance_valid(col) and not col.get("is_popped"):
			list.append(col)
	return list
