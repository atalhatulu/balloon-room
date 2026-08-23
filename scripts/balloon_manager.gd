extends Node3D

class_name BalloonManager

# Maximum capacity for MultiMesh buffer
const MAX_CAPACITY: int = 10000
const BALLOON_RADIUS: float = 0.40
const BALLOON_DIAMETER: float = 0.80
const REPULSION_DIST: float = 0.82
const GRID_CELL_SIZE: float = 1.25

# Simulation Data Structures (Flat Arrays for Ultra-Fast Memory Cache Locality)
var positions: PackedVector3Array = PackedVector3Array()
var velocities: PackedVector3Array = PackedVector3Array()
var rotations: PackedVector3Array = PackedVector3Array()
var colors: PackedColorArray = PackedColorArray()
var scales: PackedVector3Array = PackedVector3Array()

var active_count: int = 0
var room_half_w: float = 7.5
var room_half_l: float = 7.5
var room_height: float = 6.8

var current_gravity: float = 2.45 # Base 0.25G * 9.8
var linear_damping: float = 1.8

@onready var multimesh_instance: MultiMeshInstance3D = $MultiMeshInstance3D
@onready var main_node = get_node_or_null("/root/Main")
@onready var game_manager = get_node_or_null("/root/Main/GameManager")
@onready var pop_particle_scene: PackedScene = preload("res://scenes/pop_particle.tscn")

# Pre-allocated palette
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
	
	# Sphere mesh with procedural smooth rubber
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
	rotations.append(Vector3(randf_range(-PI, PI), randf_range(-PI, PI), randf_range(-PI, PI)))
	colors.append(col)
	scales.append(Vector3.ONE)
	
	active_count += 1
	
	# Update single transform in buffer
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
	
	# -------------------------------------------------------------
	# 1. Integrate Velocity & Position + Floor/Wall Collisions
	# -------------------------------------------------------------
	for i in range(active_count):
		var p = positions[i]
		var v = velocities[i]
		
		v.y -= grav_step
		v.x *= damp_factor
		v.z *= damp_factor
		
		p += v * delta
		
		# Floor Collision
		if p.y < BALLOON_RADIUS:
			p.y = BALLOON_RADIUS
			if v.y < 0:
				v.y = -v.y * 0.12 # Soft bounce
			v.x *= 0.82
			v.z *= 0.82
			
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

	# -------------------------------------------------------------
	# 2. Spatial Grid Broadphase: Soft Sphere Repulsion (Fluid Piling)
	# -------------------------------------------------------------
	var grid: Dictionary = {}
	for i in range(active_count):
		var p = positions[i]
		var gx = int(floor(p.x / GRID_CELL_SIZE))
		var gy = int(floor(p.y / GRID_CELL_SIZE))
		var gz = int(floor(p.z / GRID_CELL_SIZE))
		var key = Vector3i(gx, gy, gz)
		if not grid.has(key):
			grid[key] = [i]
		else:
			grid[key].append(i)
			
	var rep_sq = REPULSION_DIST * REPULSION_DIST
	var neighbor_offsets = [
		Vector3i(0, 0, 0), Vector3i(1, 0, 0), Vector3i(-1, 0, 0),
		Vector3i(0, 1, 0), Vector3i(0, -1, 0), Vector3i(0, 0, 1), Vector3i(0, 0, -1),
		Vector3i(1, 1, 0), Vector3i(-1, 1, 0), Vector3i(1, -1, 0), Vector3i(-1, -1, 0),
		Vector3i(1, 0, 1), Vector3i(-1, 0, 1), Vector3i(1, 0, -1), Vector3i(-1, 0, -1)
	]
	
	for cell_key in grid.keys():
		var cell_indices: Array = grid[cell_key]
		var c_size = cell_indices.size()
		
		# Intra-cell collisions
		for a in range(c_size):
			var idx_a = cell_indices[a]
			var pos_a = positions[idx_a]
			for b in range(a + 1, c_size):
				var idx_b = cell_indices[b]
				var pos_b = positions[idx_b]
				var diff = pos_a - pos_b
				var d_sq = diff.length_squared()
				if d_sq < rep_sq and d_sq > 0.0001:
					var dist = sqrt(d_sq)
					var overlap = (REPULSION_DIST - dist) * 0.5
					var n = diff / dist
					var push = n * overlap
					pos_a += push * 0.85
					pos_b -= push * 0.85
					positions[idx_a] = pos_a
					positions[idx_b] = pos_b
					velocities[idx_a] += push * 3.5
					velocities[idx_b] -= push * 3.5
					
		# Inter-cell neighboring collisions
		for offset in neighbor_offsets:
			if offset == Vector3i.ZERO: continue
			var n_key = cell_key + offset
			if grid.has(n_key):
				var n_indices: Array = grid[n_key]
				for idx_a in cell_indices:
					var pos_a = positions[idx_a]
					for idx_b in n_indices:
						var pos_b = positions[idx_b]
						var diff = pos_a - pos_b
						var d_sq = diff.length_squared()
						if d_sq < rep_sq and d_sq > 0.0001:
							var dist = sqrt(d_sq)
							var overlap = (REPULSION_DIST - dist) * 0.5
							var n = diff / dist
							var push = n * overlap
							pos_a += push * 0.85
							pos_b -= push * 0.85
							positions[idx_a] = pos_a
							positions[idx_b] = pos_b
							velocities[idx_a] += push * 3.5
							velocities[idx_b] -= push * 3.5

	# -------------------------------------------------------------
	# 3. Write All Transforms to MultiMesh Buffer
	# -------------------------------------------------------------
	for i in range(active_count):
		var p = positions[i]
		var v = velocities[i]
		var xform = Transform3D()
		xform.origin = p
		
		# Slight organic tilt based on velocity
		if v.length_squared() > 0.05:
			var tilt_axis = Vector3(-v.z, 0, v.x).normalized()
			if tilt_axis != Vector3.ZERO:
				var tilt_amt = clamp(v.length() * 0.08, 0.0, 0.35)
				xform.basis = Basis(tilt_axis, tilt_amt)
				
		mm.set_instance_transform(i, xform)

func pop_balloon_at_index(idx: int, reason: String = "needle", combo: int = 0) -> void:
	if idx < 0 or idx >= active_count:
		return
		
	var pop_pos = positions[idx]
	var pop_col = colors[idx]
	
	# Spawn visual rubber shred particle
	_spawn_pop_vfx(pop_pos, pop_col)
	
	# Swap and pop back (O(1) removal)
	var last_idx = active_count - 1
	if idx != last_idx:
		positions[idx] = positions[last_idx]
		velocities[idx] = velocities[last_idx]
		rotations[idx] = rotations[last_idx]
		colors[idx] = colors[last_idx]
		scales[idx] = scales[last_idx]
		
		var mm = multimesh_instance.multimesh
		var last_xform = mm.get_instance_transform(last_idx)
		mm.set_instance_transform(idx, last_xform)
		mm.set_instance_color(idx, colors[idx])
		
	positions.remove_at(last_idx)
	velocities.remove_at(last_idx)
	rotations.remove_at(last_idx)
	colors.remove_at(last_idx)
	scales.remove_at(last_idx)
	
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

# -------------------------------------------------------------
# Interaction APIs for Player, Traps, Magnets, and Sentry Drones
# -------------------------------------------------------------

func pop_nearest_at_ray(cam_pos: Vector3, look_dir: Vector3, max_reach: float = 5.2) -> int:
	var best_idx = -1
	var best_dot = 0.94 # ~20 degree cone
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

func get_balloon_under_ray(cam_pos: Vector3, look_dir: Vector3, max_reach: float = 5.2) -> int:
	var best_idx = -1
	var best_dot = 0.94
	for i in range(active_count):
		var to_b = positions[i] - cam_pos
		var dist = to_b.length()
		if dist <= max_reach and dist > 0.35:
			var dot = look_dir.dot(to_b / dist)
			if dot > best_dot:
				best_dot = dot
				best_idx = i
	return best_idx

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

func trigger_splash_pop(origin: Vector3, match_color: Color, radius: float, max_targets: int = 30) -> int:
	var r_sq = radius * radius
	var match_hex = match_color.to_html(false)
	var popped = 0
	var i = active_count - 1
	while i >= 0 and popped < max_targets:
		if colors[i].to_html(false) == match_hex:
			if positions[i].distance_squared_to(origin) <= r_sq:
				pop_balloon_at_index(i, "splash")
				popped += 1
		i -= 1
	return popped

# -------------------------------------------------------------
# Save / Load Serialization
# -------------------------------------------------------------

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
	rotations.clear()
	colors.clear()
	scales.clear()
	active_count = 0
	if multimesh_instance and multimesh_instance.multimesh:
		multimesh_instance.multimesh.visible_instance_count = 0
