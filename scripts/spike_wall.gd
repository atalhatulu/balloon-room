extends Node3D

@export var is_active: bool = false
@export var level: int = 0
@export var current_zone: int = 0

var widths: Array[float] = [0.0, 3.5, 5.0, 7.0, 9.5, 13.0]
var lengths: Array[float] = [0.0, 3.5, 5.0, 7.0, 9.5, 13.0]
var cooldown_intervals: Array[float] = [2.8, 2.4, 2.0, 1.6, 1.3, 1.0]
var batch_capacities: Array[int] = [0, 8, 14, 22, 32, 45]

var cooldown_timer: float = 0.0

var zone_names: Array[String] = [
	"Tam Menfez Altı (Doğrudan Düşüş)",
	"Kuzey-Batı Bölgesi",
	"Kuzey-Doğu Bölgesi",
	"Güney-Batı Bölgesi",
	"Güney-Doğu Bölgesi"
]

@onready var plate_mesh: MeshInstance3D = $PlateMesh
@onready var spikes_mesh: MeshInstance3D = $SpikesMesh
@onready var trigger_area: Area3D = $TriggerArea
@onready var trigger_shape: CollisionShape3D = $TriggerArea/CollisionShape3D
@onready var impact_particles: CPUParticles3D = $ImpactParticles
@onready var sound_manager = get_node_or_null("/root/Main/SoundManager")

func _ready() -> void:
	add_to_group("devices")
	add_to_group("interactables")
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

func cycle_zone() -> String:
	if not is_active or level <= 0:
		return ""
	current_zone = (current_zone + 1) % zone_names.size()
	update_position_for_room()
	return zone_names[current_zone]

func set_zone(zone_idx: int) -> void:
	current_zone = posmod(zone_idx, zone_names.size())
	update_position_for_room()

func update_position_for_room() -> void:
	var main_node = get_node_or_null("/root/Main")
	var room_w = 16.0
	var room_l = 16.0
	
	if main_node and main_node.get("shop_manager"):
		var r_data = main_node.shop_manager.get_current_room_data()
		if r_data.has("floor_size"):
			room_w = r_data["floor_size"].x
			room_l = r_data["floor_size"].y
		
	var off_x = room_w * 0.25
	var off_z = room_l * 0.25
	
	var zone_coords = [
		Vector3(0.0, 0.05, 0.0),
		Vector3(-off_x, 0.05, -off_z),
		Vector3(off_x, 0.05, -off_z),
		Vector3(-off_x, 0.05, off_z),
		Vector3(off_x, 0.05, off_z)
	]
	
	position = zone_coords[clamp(current_zone, 0, zone_coords.size() - 1)]

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
	
	if plate_mesh and plate_mesh.mesh is BoxMesh:
		plate_mesh.mesh.size = Vector3(w, 0.10, l)
		plate_mesh.position = Vector3(0, 0.05, 0)
		
	if spikes_mesh and spikes_mesh.mesh is BoxMesh:
		spikes_mesh.mesh.size = Vector3(w - 0.15, 0.22, l - 0.15)
		spikes_mesh.position = Vector3(0, 0.08, 0) # Retracted idle position
		
	if trigger_shape and trigger_shape.shape is BoxShape3D:
		trigger_shape.disabled = false
		trigger_shape.shape.size = Vector3(w, 1.8, l)
		trigger_shape.position = Vector3(0, 0.9, 0)
		
	if impact_particles:
		impact_particles.position = Vector3(0, 0.25, 0)
		impact_particles.emission_box_extents = Vector3(w * 0.45, 0.1, l * 0.45)

func _physics_process(delta: float) -> void:
	if not is_active or level <= 0:
		return
		
	cooldown_timer += delta
	var idx = clamp(level, 1, cooldown_intervals.size() - 1)
	var cd = cooldown_intervals[idx]
	
	if cooldown_timer >= cd:
		cooldown_timer = 0.0
		execute_spike_thrust()

func execute_spike_thrust() -> void:
	if spikes_mesh:
		var tween = create_tween()
		tween.tween_property(spikes_mesh, "position:y", 0.28, 0.05)
		tween.tween_property(spikes_mesh, "position:y", 0.08, 0.25).set_delay(0.12)
		
	var idx = clamp(level, 1, batch_capacities.size() - 1)
	var max_batch = batch_capacities[idx]
	var victims = get_targets_in_volume(max_batch)
	var popped_count = 0
	
	for body in victims:
		if is_instance_valid(body) and not body.get("is_popped"):
			if body.has_method("pop"):
				body.pop("spike_floor")
				popped_count += 1
				
	if popped_count > 0:
		if impact_particles:
			impact_particles.restart()
			impact_particles.emitting = true
			
		if sound_manager and sound_manager.has_method("play_spike_pop"):
			sound_manager.play_spike_pop()

func get_targets_in_volume(max_count: int) -> Array[RigidBody3D]:
	var list: Array[RigidBody3D] = []
	var world = get_world_3d()
	if not world: return list
	var space_state = world.direct_space_state
	if not space_state: return list
	
	var idx = clamp(level, 1, widths.size() - 1)
	var w = widths[idx]
	var l = lengths[idx]
	
	var query = PhysicsShapeQueryParameters3D.new()
	var box = BoxShape3D.new()
	box.size = Vector3(w, 2.2, l)
	query.shape = box
	query.transform = Transform3D(Basis(), global_position + Vector3(0, 1.1, 0))
	query.collision_mask = 2 # Balloons layer
	query.collide_with_bodies = true
	query.collide_with_areas = false
	
	var results = space_state.intersect_shape(query, max_count)
	for res in results:
		var col = res.collider
		if col is RigidBody3D and is_instance_valid(col) and not col.get("is_popped"):
			list.append(col)
	return list
