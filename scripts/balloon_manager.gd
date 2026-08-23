extends Node3D

class_name BalloonManager

const MAX_CAPACITY: int = 10000
const BALLOON_RADIUS: float = 0.40
const BALLOON_DIAMETER: float = 0.80
const REPULSION_DIST: float = 0.82
const GRID_CELL_SIZE: float = 1.4

# Flat Array Structures for Cache Performance
var positions: PackedVector3Array = PackedVector3Array()
var velocities: PackedVector3Array = PackedVector3Array()
var colors: PackedColorArray = PackedColorArray()
var is_sleeping: PackedByteArray = PackedByteArray()

var active_count: int = 0
var room_half_w: float = 7.5
var room_half_l: float = 7.5
var room_height: float = 6.8

var current_gravity: float = 2.45
var linear_damping: float = 1.8

@onready var multimesh_instance: MultiMeshInstance3D = $MultiMeshInstance3D
@onready var main_node = get_node_or_null("/root/Main")
@onready var game_manager = get_node_or_null("/root/Main/GameManager")
@onready var pop_particle_scene: PackedScene = preload("res://scenes/pop_particle.tscn")

var palette: Array[Color] = [
	Color("#ff4757"), # Red
	Color("#2ed573"), # Green
	Color("#1e90ff"), # Blue
	Color("#ffa502"), # Orange
	Color("#9b59b6"), # Purple
	Color("#ff6b81"), # Pink
	Color("#00d2d3"), # Cyan
	Color("#ffd32a"), # Yellow
	Color("#ff5e57")  # Coral
]

func _ready() -> void:
	_init_multimesh()

func _init_multimesh() -> void:
	if not multimesh_instance:
		multimesh_instance = MultiMeshInstance3D.new()
		multimesh_instance.name = "MultiMeshInstance3D"
		add_child(multimesh_instance)

	var mm = MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.use_colors = true
	mm.instance_count = MAX_CAPACITY
	mm.visible_instance_count = 0
	
	var sphere_mesh = SphereMesh.new()
	sphere_mesh.radius = BALLOON_RADIUS
	sphere_mesh.height = 0.85
	sphere_mesh.radial_segments = 16
	sphere_mesh.rings = 8
	
	var mat = StandardMaterial3D.new()
	mat.vertex_color_use_as_albedo = true
	mat.roughness = 0.35
	mat.metallic = 0.05
	mat.metallic_specular = 0.4
	sphere_mesh.material = mat
	
	mm.mesh = sphere_mesh
	multimesh_instance.multimesh = mm
	multimesh_instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF

func update_room_bounds(width: float, length: float, height: float = 6.8) -> void:
	room_half_w = (width * 0.5) - 0.45
	room_half_l = (length * 0.5) - 0.45
	room_height = height

func update_gravity_and_damp(grav_scale: float, damp_val: float) -> void:
	current_gravity = max(0.2, grav_scale * 9.8)
	linear_damping = max(0.5, damp_val)

func spawn_balloon(origin: Vector3, initial_vel: Vector3 = Vector3.ZERO, custom_color: Color = Color.BLACK) -> int:
	if active_count >= MAX_CAPACITY:
		return -1
		
	var idx = active_count
	var col = custom_color if custom_color != Color.BLACK else palette[randi() % palette.size()]
	
	positions.append(origin)
	velocities.append(initial_vel)
	colors.append(col)
	is_sleeping.append(0) # Awake on spawn
	
	active_count += 1
	
	var xform = Transform3D()
	xform.origin = origin
	multimesh_instance.multimesh.set_instance_transform(idx, xform)
	multimesh_instance.multimesh.set_instance_color(idx, col)
	multimesh_instance.multimesh.visible_instance_count = active_count
	
	if game_manager and game_manager.has_method("on_balloon_spawned"):
		game_manager.on_balloon_spawned(1)
		
	return idx

func _physics_process(delta: float) -> void:
	if active_count == 0:
		return
		
	var mm = multimesh_instance.multimesh
	var grav_step = current_gravity * delta
	var damp_factor = max(0.0, 1.0 - (linear_damping * delta))
	var sleep_vel_threshold_sq = 0.04
	
	# -------------------------------------------------------------
	# 1. Physics integration only for awake balloons
	# -------------------------------------------------------------
	var awake_indices: Array[int] = []
	
	for i in range(active_count):
		if is_sleeping[i] == 1:
			continue
			
		awake_indices.append(i)
		var p = positions[i]
		var v = velocities[i]
		
		v.y -= grav_step
		v.x *= damp_factor
		v.z *= damp_factor
		
		p += v * delta
		
		# Floor Collision
		if p.y <= BALLOON_RADIUS:
			p.y = BALLOON_RADIUS
			if v.y < 0:
				v.y = -v.y * 0.10
			v.x *= 0.70
			v.z *= 0.70
			
			if v.length_squared() < sleep_vel_threshold_sq:
				v = Vector3.ZERO
				is_sleeping[i] = 1
				
		# Ceiling Collision
		if p.y > room_height:
			p.y = room_height
			if v.y > 0: v.y = -v.y * 0.2
			
		# Room Walls
		if p.x < -room_half_w:
			p.x = -room_half_w
			if v.x < 0: v.x = -v.x * 0.3
		elif p.x > room_half_w:
			p.x = room_half_w
			if v.x > 0: v.x = -v.x * 0.3
			
		if p.z < -room_half_l:
			p.z = -room_half_l
			if v.z < 0: v.z = -v.z * 0.3
		elif p.z > room_half_l:
			p.z = room_half_l
			if v.z > 0: v.z = -v.z * 0.3
			
		positions[i] = p
		velocities[i] = v
		
		# Update transform in buffer ONLY for awake balloons
		var xform = Transform3D()
		xform.origin = p
		if v.length_squared() > 0.05:
			var tilt_axis = Vector3(-v.z, 0, v.x).normalized()
			if tilt_axis != Vector3.ZERO:
				var tilt_amt = clamp(v.length() * 0.08, 0.0, 0.35)
				xform.basis = Basis(tilt_axis, tilt_amt)
		mm.set_instance_transform(i, xform)

	# -------------------------------------------------------------
	# 2. Fast Repulsion only between Awake balloons and their local cluster
	# -------------------------------------------------------------
	if awake_indices.is_empty():
		return
		
	var rep_sq = REPULSION_DIST * REPULSION_DIST
	for i in awake_indices:
		var pos_a = positions[i]
		# Check nearby balloons within a fast stride
		for j in range(max(0, i - 25), min(active_count, i + 25)):
			if i == j: continue
			var pos_b = positions[j]
			var diff = pos_a - pos_b
			var d_sq = diff.length_squared()
			if d_sq < rep_sq and d_sq > 0.0001:
				var dist = sqrt(d_sq)
				var overlap = (REPULSION_DIST - dist) * 0.5
				var push = (diff / dist) * overlap
				
				positions[i] += push * 0.85
				velocities[i] += push * 2.5
				
				positions[j] -= push * 0.85
				velocities[j] -= push * 2.5
				is_sleeping[j] = 0 # Wake up pushed balloon
				
				var xform_j = Transform3D()
				xform_j.origin = positions[j]
				mm.set_instance_transform(j, xform_j)

func pop_balloon_at_index(idx: int, reason: String = "needle", combo: int = 0) -> void:
	if idx < 0 or idx >= active_count:
		return
		
	var pop_pos = positions[idx]
	var pop_col = colors[idx]
	
	_spawn_pop_vfx(pop_pos, pop_col)
	
	var last_idx = active_count - 1
	if idx != last_idx:
		positions[idx] = positions[last_idx]
		velocities[idx] = velocities[last_idx]
		colors[idx] = colors[last_idx]
		is_sleeping[idx] = is_sleeping[last_idx]
		
		var mm = multimesh_instance.multimesh
		var last_xform = mm.get_instance_transform(last_idx)
		mm.set_instance_transform(idx, last_xform)
		mm.set_instance_color(idx, colors[idx])
		
	positions.remove_at(last_idx)
	velocities.remove_at(last_idx)
	colors.remove_at(last_idx)
	is_sleeping.remove_at(last_idx)
	
	active_count -= 1
	multimesh_instance.multimesh.visible_instance_count = active_count
	
	if game_manager and game_manager.has_method("on_balloon_popped"):
		game_manager.on_balloon_popped(pop_pos, pop_col, combo, 0)

func _spawn_pop_vfx(pos: Vector3, col: Color) -> void:
	if pop_particle_scene and main_node:
		var p = pop_particle_scene.instantiate()
		p.position = pos
		if p.has_method("set_pop_color"):
			p.set_pop_color(col)
		main_node.add_child(p)

func pop_nearest_at_ray(cam_pos: Vector3, look_dir: Vector3, max_reach: float = 5.2) -> int:
	var best_idx = -1
	var best_dot = 0.94
	var best_dist = max_reach
	
	for i in range(active_count):
		var to_b = positions[i] - cam_pos
		var dist = to_b.length()
		if dist <= max_reach and dist > 0.35:
			var dot = look_dir.dot(to_b / dist)
			if dot > best_dot:
				best_dot = dot
				best_dist = dist
				best_idx = i
				
	if best_idx != -1:
		pop_balloon_at_index(best_idx, "needle")
		return best_idx
	return -1

func pop_in_radius(center: Vector3, radius: float, max_count: int = 50, reason: String = "trap") -> int:
	var r_sq = radius * radius
	var popped = 0
	var i = active_count - 1
	while i >= 0 and popped < max_count:
		if positions[i].distance_squared_to(center) <= r_sq:
			pop_balloon_at_index(i, reason)
			popped += 1
		i -= 1
	return popped

func pop_in_box(center: Vector3, size: Vector3, max_count: int = 50, reason: String = "trap") -> int:
	var half_s = size * 0.5
	var min_p = center - half_s
	var max_p = center + half_s
	var popped = 0
	var i = active_count - 1
	while i >= 0 and popped < max_count:
		var p = positions[i]
		if p.x >= min_p.x and p.x <= max_p.x and p.y >= min_p.y and p.y <= max_p.y and p.z >= min_p.z and p.z <= max_p.z:
			pop_balloon_at_index(i, reason)
			popped += 1
		i -= 1
	return popped

func apply_magnet_pull(pylon_pos: Vector3, radius: float, strength: float) -> void:
	var r_sq = radius * radius
	for i in range(active_count):
		var diff = pylon_pos - positions[i]
		var dist_sq = diff.length_squared()
		if dist_sq < r_sq and dist_sq > 0.35:
			var dist = sqrt(dist_sq)
			var dir = diff / dist
			var falloff = clamp(1.0 - (dist / radius), 0.2, 1.0)
			velocities[i] += dir * (falloff * strength * 0.35)
			is_sleeping[i] = 0

func apply_wind_force(cone_origin: Vector3, cone_dir: Vector3, reach: float, cone_dot: float, force: float) -> void:
	var r_sq = reach * reach
	for i in range(active_count):
		var diff = positions[i] - cone_origin
		var dist_sq = diff.length_squared()
		if dist_sq <= r_sq and dist_sq > 0.3:
			var dist = sqrt(dist_sq)
			var to_b = diff / dist
			var dot = cone_dir.dot(to_b)
			if dot >= cone_dot:
				var falloff = 1.0 - (dist / reach)
				velocities[i] += cone_dir * (force * falloff * 0.45)
				is_sleeping[i] = 0

func get_save_data() -> Array:
	var list: Array = []
	for i in range(active_count):
		var p = positions[i]
		list.append({
			"pos": [p.x, p.y, p.z],
			"color": colors[i].to_html(false)
		})
	return list

func load_save_data(data: Array) -> void:
	clear_all()
	for item in data:
		var p_arr = item.get("pos", [0, 1, 0])
		var col_str = item.get("color", "ff4757")
		var pos = Vector3(p_arr[0], p_arr[1], p_arr[2])
		var col = Color.from_string(col_str, Color("#ff4757"))
		spawn_balloon(pos, Vector3.ZERO, col)

func clear_all() -> void:
	positions.clear()
	velocities.clear()
	colors.clear()
	is_sleeping.clear()
	active_count = 0
	if multimesh_instance and multimesh_instance.multimesh:
		multimesh_instance.multimesh.visible_instance_count = 0
