extends Node3D

const Feedback = preload("res://src/devices/device_feedback.gd")
var feedback: Node3D


@export var is_active: bool = false
@export var level: int = 1

var cooldown_intervals: Array[float] = [0.0, 0.55, 0.42, 0.32, 0.24, 0.18, 0.12]
var batch_capacities: Array[int] = [0, 20, 45, 90, 160, 260, 400]
var trigger_radii: Array[float] = [0.0, 1.8, 2.3, 2.9, 3.6, 4.4, 5.4]

var cooldown_timer: float = 0.0
var thrust_tween: Tween

@onready var plate_mesh: MeshInstance3D = get_node_or_null("PlateMesh")
@onready var spikes_mesh: MeshInstance3D = get_node_or_null("SpikesMesh")
@onready var trigger_area: Area3D = get_node_or_null("TriggerArea")
@onready var trigger_shape: CollisionShape3D = get_node_or_null("TriggerArea/CollisionShape3D")
@onready var impact_particles: CPUParticles3D = get_node_or_null("ImpactParticles")
@onready var sound_manager = get_node_or_null("/root/Main/SoundManager")

# Cached physics query parameters to prevent continuous dynamic allocation in _physics_process
var _cached_query: PhysicsShapeQueryParameters3D = null
var _cached_box: BoxShape3D = null

func _ensure_physics_query() -> void:
	if _cached_box == null:
		_cached_box = BoxShape3D.new()
	if _cached_query == null:
		_cached_query = PhysicsShapeQueryParameters3D.new()
		_cached_query.shape = _cached_box
		_cached_query.collision_mask = 2 # Balloons layer
		_cached_query.collide_with_bodies = true
		_cached_query.collide_with_areas = false

func _ready() -> void:
	feedback = Feedback.new()
	feedback.name = "ActivityIndicator"
	add_child(feedback)
	feedback.configure(Color(1.0, 0.42, 0.12), 2.6, 1.55, false)
	if spikes_mesh and spikes_mesh.material_override:
		spikes_mesh.material_override = spikes_mesh.material_override.duplicate()
	# Merge the teeth into one mesh; keep the existing animated node and bounds.
	if spikes_mesh:
		var teeth := SurfaceTool.new()
		teeth.begin(Mesh.PRIMITIVE_TRIANGLES)
		var tooth := CylinderMesh.new()
		tooth.top_radius = 0.015
		tooth.bottom_radius = 0.13
		tooth.height = 0.32
		tooth.radial_segments = 6
		tooth.rings = 1
		for x in range(7):
			for z in range(7):
				teeth.append_from(tooth, 0, Transform3D(Basis(), Vector3((x - 3) * 0.46, 0.08, (z - 3) * 0.46)))
		spikes_mesh.mesh = teeth.commit()
	add_to_group("devices")
	if trigger_area:
		trigger_area.collision_layer = 0
		trigger_area.collision_mask = 2
	_ensure_physics_query()
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
	var idx = clamp(level, 1, trigger_radii.size() - 1)
	var r = trigger_radii[idx]
	var scale_factor = (r * 2.0) / 3.5
	
	if feedback:
		feedback.scale = Vector3(scale_factor, 1.0, scale_factor)
	_ensure_physics_query()
	if _cached_box:
		# Generous 3.5m vertical shredding height so floating balloons don't bounce over it
		_cached_box.size = Vector3(r * 2.0, 3.5, r * 2.0)
	
	if plate_mesh:
		plate_mesh.scale = Vector3(scale_factor, 1.0, scale_factor)
	if spikes_mesh:
		spikes_mesh.scale = Vector3(scale_factor, 1.0, scale_factor)
		if spikes_mesh.material_override is StandardMaterial3D:
			var mat = spikes_mesh.material_override as StandardMaterial3D
			mat.albedo_color = Color(1.0, 0.40 - (level * 0.05), 0.15, 1.0)
	if impact_particles:
		impact_particles.emission_box_extents = Vector3(r * 0.85, 0.1, r * 0.85)

func _physics_process(delta: float) -> void:
	var facility = get_node_or_null("/root/Main")
	if facility and facility.is_blackout:
		return

	if not is_active or level <= 0:
		return
		
	cooldown_timer += delta
	var idx = clamp(level, 1, cooldown_intervals.size() - 1)
	var cd = cooldown_intervals[idx]
	if feedback: feedback.update_state(delta, clampf(cooldown_timer / cd, 0.0, 1.0))
	if cooldown_timer >= cd:
		cooldown_timer = fmod(cooldown_timer, cd)
		execute_spike_thrust()

func execute_spike_thrust() -> void:
	if spikes_mesh:
		if thrust_tween: thrust_tween.kill()
		thrust_tween = create_tween()
		thrust_tween.tween_property(spikes_mesh, "position:y", 0.28, 0.035).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
		thrust_tween.tween_property(spikes_mesh, "position:y", 0.08, minf(0.12, cooldown_intervals[clampi(level, 1, 6)] * 0.45)).set_delay(0.015).set_trans(Tween.TRANS_SINE)
		
	var idx = clamp(level, 1, batch_capacities.size() - 1)
	var max_batch = batch_capacities[idx]
	var victims = get_targets_in_volume(max_batch)
	var popped_count = 0
	
	for body in victims:
		if is_instance_valid(body) and not body.get("is_popped"):
			if body.has_method("pop") and (not body.has_method("can_pop") or body.can_pop("spike_wall")):
				body.pop("spike_wall")
				popped_count += 1
				
	if popped_count > 0:
		feedback.record_output(popped_count)
		feedback.pulse()
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
	
	_ensure_physics_query()
	_cached_query.transform = Transform3D(global_basis.orthonormalized(), global_position + Vector3(0, 0.9, 0))
	
	var results = space_state.intersect_shape(_cached_query, max_count + 2)
	for res in results:
		var col = res.collider
		if col is RigidBody3D and is_instance_valid(col) and not col.get("is_popped"):
			if col.has_method("can_pop") and not col.can_pop("spike_floor"): continue
			list.append(col)
			if list.size() >= max_count: break
	return list
