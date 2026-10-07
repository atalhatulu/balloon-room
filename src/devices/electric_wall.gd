extends Node3D

const Feedback = preload("res://src/devices/device_feedback.gd")
var feedback: Node3D


@export var is_active: bool = false
@export var level: int = 1

# Laser Fence dimensions: fence width, fence height, cooldown interval, and batch shred limit
var fence_widths: Array[float] = [0.0, 5.0, 7.0, 9.5, 12.0, 15.0, 18.0]
var fence_heights: Array[float] = [0.0, 3.8, 4.5, 5.2, 6.0, 7.0, 8.0]
var cooldown_intervals: Array[float] = [0.0, 0.40, 0.30, 0.22, 0.16, 0.12, 0.08]
var max_burst_caps: Array[int] = [0, 25, 50, 90, 150, 240, 380]

var cooldown_timer: float = 0.0

@onready var frame_mesh: MeshInstance3D = get_node_or_null("FrameMesh")
@onready var neon_grid: MeshInstance3D = get_node_or_null("NeonGrid")
@onready var trigger_area: Area3D = get_node_or_null("TriggerArea")
@onready var trigger_shape: CollisionShape3D = get_node_or_null("TriggerArea/CollisionShape3D")
@onready var spark_particles: CPUParticles3D = get_node_or_null("SparkParticles")
@onready var arc_light: OmniLight3D = get_node_or_null("ArcLight")
@onready var sound_manager = get_node_or_null("/root/Main/SoundManager")

# Cached physics query parameters for box-shaped vertical laser fence
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
	feedback.configure(Color(0.18, 0.85, 1.0), 3.0, 1.78, false)
	if neon_grid and neon_grid.material_override:
		neon_grid.material_override = neon_grid.material_override.duplicate()
	if frame_mesh and frame_mesh.material_override:
		frame_mesh.material_override = frame_mesh.material_override.duplicate()
	if trigger_shape and trigger_shape.shape:
		trigger_shape.shape = trigger_shape.shape.duplicate()
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
		if spark_particles: spark_particles.emitting = false
		return
		
	visible = true
	var idx = clamp(level, 1, fence_widths.size() - 1)
	var w = fence_widths[idx]
	var h = fence_heights[idx]
	
	if feedback:
		feedback.scale = Vector3(w / 4.0, 1.0, 1.0)
	_ensure_physics_query()
	if _cached_box:
		_cached_box.size = Vector3(w, h, 1.2)
	
	if frame_mesh:
		frame_mesh.scale = Vector3.ONE
		frame_mesh.position = Vector3.ZERO
		frame_mesh.mesh = _build_frame_mesh(w, h)
	if neon_grid:
		neon_grid.scale = Vector3.ONE
		neon_grid.position = Vector3.ZERO
		neon_grid.mesh = _build_grid_mesh(w, h)
		if neon_grid.material_override is StandardMaterial3D:
			var mat = neon_grid.material_override as StandardMaterial3D
			mat.emission_energy_multiplier = 2.5 + (level * 1.0)
	if trigger_shape and trigger_shape.shape is BoxShape3D:
		(trigger_shape.shape as BoxShape3D).size = Vector3(w, h, 1.2)
		trigger_shape.position = Vector3(0, h * 0.5, 0)
		
	if arc_light:
		arc_light.position.y = h * 0.5
		arc_light.omni_range = maxf(4.0, minf(7.0, w * 0.32))
		arc_light.light_energy = 0.5
		
	if spark_particles:
		spark_particles.position.y = h * 0.5
		spark_particles.emission_box_extents = Vector3(w * 0.45, h * 0.45, 0.25)

func _build_frame_mesh(w: float, h: float) -> ArrayMesh:
	var boxes: Array[Dictionary] = []
	for side in [-1.0, 1.0]:
		var x: float = float(side) * (w * 0.5 - 0.09)
		boxes.append({"size": Vector3(0.18, h, 0.20), "position": Vector3(x, h * 0.5, 0)})
		boxes.append({"size": Vector3(0.52, 0.09, 0.66), "position": Vector3(x, 0.045, 0)})
	boxes.append({"size": Vector3(w, 0.14, 0.20), "position": Vector3(0, h - 0.07, 0)})
	boxes.append({"size": Vector3(w, 0.12, 0.20), "position": Vector3(0, 0.06, 0)})
	return _merge_box_meshes(boxes)

func _build_grid_mesh(w: float, h: float) -> ArrayMesh:
	var boxes: Array[Dictionary] = []
	var inset_w := maxf(0.5, w - 0.36)
	var inset_h := maxf(0.6, h - 0.42)
	var horizontal_count := clampi(roundi(h / 0.58), 4, 14)
	var vertical_count := clampi(roundi(w / 0.85), 5, 22)
	for i in range(horizontal_count):
		var y := 0.24 + inset_h * float(i) / float(horizontal_count - 1)
		boxes.append({"size": Vector3(inset_w, 0.035, 0.035), "position": Vector3(0, y, 0)})
	for i in range(vertical_count):
		var x := -inset_w * 0.5 + inset_w * float(i) / float(vertical_count - 1)
		boxes.append({"size": Vector3(0.035, inset_h, 0.035), "position": Vector3(x, h * 0.5, 0)})
	return _merge_box_meshes(boxes)

func _merge_box_meshes(boxes: Array[Dictionary]) -> ArrayMesh:
	var surface := SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	for entry in boxes:
		var box := BoxMesh.new()
		box.size = entry["size"]
		surface.append_from(box, 0, Transform3D(Basis(), entry["position"]))
	return surface.commit()

func _physics_process(delta: float) -> void:
	var facility = get_node_or_null("/root/Main")
	if facility and facility.is_blackout:
		if neon_grid and neon_grid.material_override is StandardMaterial3D:
			(neon_grid.material_override as StandardMaterial3D).emission_energy_multiplier = 0.0
		if arc_light: arc_light.light_energy = 0.0
		if spark_particles: spark_particles.emitting = false
		return

	if not is_active or level <= 0:
		return
		
	cooldown_timer += delta
	var idx = clamp(level, 1, cooldown_intervals.size() - 1)
	var cd = cooldown_intervals[idx]
	feedback.update_state(delta, clampf(cooldown_timer / cd, 0.0, 1.0))
	
	if neon_grid and neon_grid.material_override is StandardMaterial3D:
		var charge := clampf(cooldown_timer / cd, 0.0, 1.0)
		(neon_grid.material_override as StandardMaterial3D).emission_energy_multiplier = 0.08 + charge * 0.25 + feedback.flash * 4.0
	# Visual charge buildup during final 0.5s of cooldown
	var remaining = cd - cooldown_timer
	if remaining <= 0.5:
		var charge_pct = 1.0 - (remaining / 0.5)
		if arc_light:
			arc_light.light_energy = 0.4 + charge_pct * 3.5 + feedback.flash * 6.0
		if spark_particles and not spark_particles.emitting:
			spark_particles.emitting = true
	else:
		if arc_light:
			arc_light.light_energy = 0.4 + feedback.flash * 6.0
		if spark_particles and spark_particles.emitting:
			spark_particles.emitting = false
			
	if cooldown_timer >= cd:
		cooldown_timer = fmod(cooldown_timer, cd)
		process_electric_discharge()

func process_electric_discharge() -> void:
	var idx = clamp(level, 1, max_burst_caps.size() - 1)
	var max_burst = max_burst_caps[idx]
	var victims = get_targets_in_volume(max_burst)
	if victims.is_empty():
		return
		
	if sound_manager and sound_manager.has_method("play_zap"):
		sound_manager.play_zap()
		
	if arc_light:
		arc_light.light_energy = 7.5 + (level * 1.5)
		
	# Stagger pops over 3-4 consecutive frames (25 balloons/frame) to prevent massive single-frame lag spikes
	_stagger_pop_batch(victims, 0, 25)

func _stagger_pop_batch(targets: Array[RigidBody3D], start_idx: int, batch_size: int) -> void:
	if not is_active or process_mode == Node.PROCESS_MODE_DISABLED or not is_inside_tree(): return
	var zapped_count = 0
	var end_idx = mini(targets.size(), start_idx + batch_size)
	
	for i in range(start_idx, end_idx):
		var body = targets[i]
		if is_instance_valid(body) and not body.get("is_popped"):
			if body.has_method("pop") and (not body.has_method("can_pop") or body.can_pop("electric_grid")):
				body.pop("electric_grid")
				zapped_count += 1
				
	if zapped_count > 0 and feedback:
		feedback.record_output(zapped_count)
		feedback.pulse()
		
	if end_idx < targets.size():
		# Chain next slice on next idle frame
		get_tree().process_frame.connect(func(): _stagger_pop_batch(targets, end_idx, batch_size), CONNECT_ONE_SHOT)

func get_targets_in_volume(max_count: int) -> Array[RigidBody3D]:
	var list: Array[RigidBody3D] = []
	var world = get_world_3d()
	if not world: return list
	var space_state = world.direct_space_state
	if not space_state: return list
	
	_ensure_physics_query()
	var idx = clamp(level, 1, fence_widths.size() - 1)
	var h = fence_heights[idx]
	
	_cached_query.transform = Transform3D(global_transform.basis, global_position + Vector3(0, h * 0.5, 0))
	
	var results = space_state.intersect_shape(_cached_query, max_count + 2)
	for res in results:
		var col = res.collider
		if col is RigidBody3D and is_instance_valid(col) and not col.get("is_popped"):
			if col.has_method("can_pop") and not col.can_pop("electric_grid"): continue
			list.append(col)
			if list.size() >= max_count: break
	return list
