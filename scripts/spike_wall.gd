extends Node3D

@export var is_active: bool = false
@export var level: int = 1

var cooldown_intervals: Array[float] = [0.0, 0.60, 0.48, 0.38, 0.30, 0.22, 0.16]
var batch_capacities: Array[int] = [0, 12, 22, 36, 55, 80, 120]
var trigger_radii: Array[float] = [0.0, 1.4, 1.6, 1.8, 2.0, 2.2, 2.5]

var cooldown_timer: float = 0.0

@onready var plate_mesh: MeshInstance3D = get_node_or_null("PlateMesh")
@onready var spikes_mesh: MeshInstance3D = get_node_or_null("SpikesMesh")
@onready var trigger_area: Area3D = get_node_or_null("TriggerArea")
@onready var trigger_shape: CollisionShape3D = get_node_or_null("TriggerArea/CollisionShape3D")
@onready var impact_particles: CPUParticles3D = get_node_or_null("ImpactParticles")
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
		return
		
	visible = true
	if spikes_mesh and spikes_mesh.material_override is StandardMaterial3D:
		var mat = spikes_mesh.material_override as StandardMaterial3D
		# Color shifts to hotter orange-red with level
		mat.albedo_color = Color(1.0, 0.35 - (level * 0.04), 0.15, 1.0)

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
		tween.tween_property(spikes_mesh, "position:y", 0.28, 0.04)
		tween.tween_property(spikes_mesh, "position:y", 0.08, 0.12).set_delay(0.06)
		
	var idx = clamp(level, 1, batch_capacities.size() - 1)
	var max_batch = batch_capacities[idx]
	var r = trigger_radii[clamp(level, 1, trigger_radii.size() - 1)]
	
	var bm = get_node_or_null("/root/Main/BalloonContainer")
	var popped_count = 0
	if bm and bm.has_method("pop_in_box"):
		popped_count = bm.pop_in_box(global_position + Vector3(0, 0.8, 0), Vector3(r * 2.0, 1.6, r * 2.0), max_batch, "spike_floor")
	else:
		var victims = get_targets_in_volume(max_batch)
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
	
	var idx = clamp(level, 1, trigger_radii.size() - 1)
	var r = trigger_radii[idx]
	
	var query = PhysicsShapeQueryParameters3D.new()
	var box = BoxShape3D.new()
	box.size = Vector3(r * 2.0, 1.8, r * 2.0)
	query.shape = box
	query.transform = Transform3D(Basis(), global_position + Vector3(0, 0.9, 0))
	query.collision_mask = 2 # Balloons layer
	query.collide_with_bodies = true
	query.collide_with_areas = false
	
	var results = space_state.intersect_shape(query, max_count)
	for res in results:
		var col = res.collider
		if col is RigidBody3D and is_instance_valid(col) and not col.get("is_popped"):
			list.append(col)
	return list
