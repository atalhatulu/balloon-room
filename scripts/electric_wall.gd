extends Node3D

@export var is_active: bool = false
@export var level: int = 0

var widths: Array[float] = [0.0, 3.5, 5.0, 7.0, 9.5, 13.0]
var lengths: Array[float] = [0.0, 3.5, 5.0, 7.0, 9.5, 13.0]
var zap_heights: Array[float] = [0.0, 2.0, 2.4, 2.8, 3.4, 4.0]
var cooldown_intervals: Array[float] = [2.0, 1.4, 1.0, 0.75, 0.55, 0.40]
var max_burst_caps: Array[int] = [0, 24, 45, 75, 120, 180]

var cooldown_timer: float = 0.0

@onready var frame_mesh: MeshInstance3D = $FrameMesh
@onready var neon_grid: MeshInstance3D = $NeonGrid
@onready var trigger_area: Area3D = $TriggerArea
@onready var trigger_shape: CollisionShape3D = $TriggerArea/CollisionShape3D
@onready var spark_particles: CPUParticles3D = $SparkParticles
@onready var arc_light: OmniLight3D = $ArcLight
@onready var sound_manager = get_node_or_null("/root/Main/SoundManager")

func _ready() -> void:
	add_to_group("devices")
	if trigger_area:
		trigger_area.collision_layer = 0
		trigger_area.collision_mask = 2
	update_visuals()
	update_position_for_room()

func setup_level(new_level: int) -> void:
	level = new_level
	is_active = (level > 0)
	visible = is_active
	update_visuals()
	update_position_for_room()

func update_position_for_room() -> void:
	var main_node = get_node_or_null("/root/Main")
	var room_w = 16.0
	if main_node and main_node.get("shop_manager"):
		var r_data = main_node.shop_manager.get_current_room_data()
		if r_data.has("floor_size"):
			room_w = r_data["floor_size"].x
		
	var off_x = room_w * 0.28
	position = Vector3(-off_x, 0.05, 0.0)

func update_visuals() -> void:
	if not is_active or level <= 0:
		visible = false
		if trigger_shape:
			trigger_shape.disabled = true
		return
		
	visible = true
	var idx = clamp(level, 1, widths.size() - 1)
	var w = widths[idx]
	var l = lengths[idx]
	var h = zap_heights[idx]
	
	if frame_mesh and frame_mesh.mesh is BoxMesh:
		frame_mesh.mesh.size = Vector3(w, 0.10, l)
		frame_mesh.position = Vector3(0, 0.05, 0)
		
	if neon_grid and neon_grid.mesh is BoxMesh:
		neon_grid.mesh.size = Vector3(w - 0.2, 0.12, l - 0.2)
		neon_grid.position = Vector3(0, 0.06, 0)
		
	if trigger_shape and trigger_shape.shape is BoxShape3D:
		trigger_shape.disabled = false
		trigger_shape.shape.size = Vector3(w, h, l)
		trigger_shape.position = Vector3(0, h * 0.5, 0)
		
	if spark_particles:
		spark_particles.position = Vector3(0, 0.2, 0)
		spark_particles.emission_box_extents = Vector3(w * 0.45, 0.1, l * 0.45)
		spark_particles.emitting = false
		
	if arc_light:
		arc_light.position = Vector3(0, 0.6, 0)
		arc_light.omni_range = max(6.0, w * 0.8)
		arc_light.light_energy = 0.4

func _physics_process(delta: float) -> void:
	if not is_active or level <= 0:
		return
		
	cooldown_timer += delta
	var idx = clamp(level, 1, cooldown_intervals.size() - 1)
	var cd = cooldown_intervals[idx]
	
	# Visual charge buildup during final 0.4s of cooldown
	var remaining = cd - cooldown_timer
	if remaining <= 0.4:
		var charge_pct = 1.0 - (remaining / 0.4)
		if arc_light:
			arc_light.light_energy = 0.4 + charge_pct * 2.0
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
			arc_light.light_energy = 5.0
			var tween = create_tween()
			tween.tween_property(arc_light, "light_energy", 0.4, 0.25)

func get_targets_in_volume(max_count: int) -> Array[RigidBody3D]:
	var list: Array[RigidBody3D] = []
	var world = get_world_3d()
	if not world: return list
	var space_state = world.direct_space_state
	if not space_state: return list
	
	var idx = clamp(level, 1, widths.size() - 1)
	var w = widths[idx]
	var l = lengths[idx]
	var h = zap_heights[idx]
	
	var query = PhysicsShapeQueryParameters3D.new()
	var box = BoxShape3D.new()
	box.size = Vector3(w, h, l)
	query.shape = box
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
