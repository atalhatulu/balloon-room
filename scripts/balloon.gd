extends RigidBody3D

signal popped(balloon_node: RigidBody3D, pop_position: Vector3, balloon_color: Color, combo_depth: int, balloon_type: int)

enum BalloonType { NORMAL = 0, GOLDEN = 1, BOMB = 2, PLASMA = 3 }

@export var pop_particle_scene: PackedScene = preload("res://scenes/pop_particle.tscn")

var balloon_type: int = BalloonType.NORMAL
var balloon_color: Color = Color(1.0, 0.35, 0.45)
var is_popped: bool = false
var custom_color_set: bool = false

# Shared static material cache to batch draw calls across all balloons
static var _material_cache: Dictionary = {}
static var _ring_mat_cache: Dictionary = {}
static var _active_particle_count: int = 0

@onready var mesh_instance: MeshInstance3D = $MeshInstance3D
@onready var collision_shape: CollisionShape3D = $CollisionShape3D
@onready var bomb_fuse: Node3D = get_node_or_null("BombFuse")
@onready var halo_ring: MeshInstance3D = get_node_or_null("HaloRing")

func _ready() -> void:
	add_to_group("balloons")
	can_sleep = true
	continuous_cd = false
	
	if mesh_instance:
		mesh_instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		
	if not custom_color_set:
		setup_random_color()
	else:
		_apply_visual_features()

func _physics_process(_delta: float) -> void:
	if is_popped:
		return
		
	# Anti-Void: Immediately pop any balloon that clips under floor or flies out of bounds
	if global_position.y < -0.4 or global_position.y > 35.0:
		pop("out_of_bounds")

func wake_physics() -> void:
	sleeping = false

func set_balloon_color(col: Color) -> void:
	custom_color_set = true
	balloon_color = col
	if col.to_html() == "ffd700" or col.is_equal_approx(Color("#ffd700")):
		balloon_type = BalloonType.GOLDEN
	elif col.to_html() == "2c2c34" or col.is_equal_approx(Color("#2c2c34")):
		balloon_type = BalloonType.BOMB
	elif col.to_html() == "e056fd" or col.is_equal_approx(Color("#e056fd")):
		balloon_type = BalloonType.PLASMA
	else:
		balloon_type = BalloonType.NORMAL
	_apply_visual_features()

func setup_random_color() -> void:
	var g_chance = 0.08
	var b_chance = 0.06
	var p_chance = 0.05
	var main_node = get_node_or_null("/root/Main")
	if main_node and main_node.get("shop_manager"):
		var r_data = main_node.shop_manager.get_current_room_data()
		g_chance = r_data.get("gold_chance", 0.08)
		b_chance = r_data.get("bomb_chance", 0.06)
		
	var roll = randf()
	if roll < g_chance:
		balloon_type = BalloonType.GOLDEN
		balloon_color = Color("#ffd700")
	elif roll < (g_chance + b_chance):
		balloon_type = BalloonType.BOMB
		balloon_color = Color("#1e2022")
	elif roll < (g_chance + b_chance + p_chance):
		balloon_type = BalloonType.PLASMA
		balloon_color = Color("#be2edd")
	else:
		balloon_type = BalloonType.NORMAL
		var palette = [
			Color("#ff4757"), # Red
			Color("#2ed573"), # Green
			Color("#1e90ff"), # Blue
			Color("#ffa502"), # Orange
			Color("#9b59b6"), # Purple
			Color("#ff6b81"), # Pink
			Color("#00d2d3")  # Cyan
		]
		balloon_color = palette[randi() % palette.size()]
		
	_apply_visual_features()

func _apply_visual_features() -> void:
	_apply_cached_material()
	
	# 3D Visual Props for Special Types
	if bomb_fuse:
		bomb_fuse.visible = (balloon_type == BalloonType.BOMB)
		
	if halo_ring:
		if balloon_type == BalloonType.GOLDEN:
			halo_ring.visible = true
			halo_ring.material_override = _get_ring_material(Color("#ffd700"))
		elif balloon_type == BalloonType.PLASMA:
			halo_ring.visible = true
			halo_ring.material_override = _get_ring_material(Color("#e056fd"))
		else:
			halo_ring.visible = false

static func _get_ring_material(color: Color) -> StandardMaterial3D:
	var key = color.to_html(false)
	if _ring_mat_cache.has(key):
		return _ring_mat_cache[key]
	var mat = StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.albedo_color = color
	_ring_mat_cache[key] = mat
	return mat

static func get_cached_material(type: int, color: Color) -> StandardMaterial3D:
	var key = str(type) + "_" + color.to_html(false)
	if _material_cache.has(key):
		return _material_cache[key]
		
	var mat = StandardMaterial3D.new()
	mat.albedo_color = color
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_PER_PIXEL
	
	if type == BalloonType.GOLDEN:
		mat.metallic = 0.95
		mat.roughness = 0.12
		mat.emission_enabled = true
		mat.emission = Color("#ffd700")
		mat.emission_energy_multiplier = 0.5
	elif type == BalloonType.BOMB:
		mat.metallic = 0.8
		mat.roughness = 0.5
		mat.albedo_color = Color("#18191c")
		mat.emission_enabled = true
		mat.emission = Color("#ff2a2a")
		mat.emission_energy_multiplier = 0.7
	elif type == BalloonType.PLASMA:
		mat.metallic = 0.9
		mat.roughness = 0.15
		mat.emission_enabled = true
		mat.emission = Color("#be2edd")
		mat.emission_energy_multiplier = 1.3
	else:
		mat.roughness = 0.35
		mat.metallic = 0.05
		mat.metallic_specular = 0.4
		
	_material_cache[key] = mat
	return mat

func _apply_cached_material() -> void:
	var mat = get_cached_material(balloon_type, balloon_color)
	if mesh_instance:
		mesh_instance.material_override = mat

func pop(_trigger_source: String = "manual", combo_depth: int = 0) -> void:
	if is_popped:
		return
	is_popped = true
	
	var pop_pos = global_position
	var pop_type = balloon_type
	var pop_col = balloon_color
	
	popped.emit(self, pop_pos, pop_col, combo_depth, pop_type)
	
	# Hide visual and disable collision immediately
	if mesh_instance: mesh_instance.visible = false
	if bomb_fuse: bomb_fuse.visible = false
	if halo_ring: halo_ring.visible = false
	if collision_shape: collision_shape.disabled = true
	freeze = true
	
	# Spawn visual rubber shreds with throttle cap
	if pop_particle_scene and _active_particle_count < 10:
		_active_particle_count += 1
		var particle = pop_particle_scene.instantiate()
		particle.position = pop_pos
		get_parent().add_child(particle)
		if particle.has_method("init"):
			particle.init(pop_col)
		particle.tree_exited.connect(func(): _active_particle_count = max(0, _active_particle_count - 1))
			
	# Elemental Reactions via C++ Spatial Direct Query (0.01ms cost)
	if pop_type == BalloonType.BOMB and combo_depth < 2:
		trigger_bomb_blast(pop_pos)
	elif pop_type == BalloonType.PLASMA and combo_depth < 2:
		trigger_plasma_chain(pop_pos)
	elif pop_type == BalloonType.NORMAL and combo_depth < 3:
		trigger_color_chain(pop_pos, pop_col, combo_depth + 1)
		
	queue_free()

func _get_nearby_balloons(origin: Vector3, radius: float, max_count: int) -> Array[RigidBody3D]:
	var world = get_world_3d()
	if not world: return []
	var space_state = world.direct_space_state
	if not space_state: return []
	
	var query = PhysicsShapeQueryParameters3D.new()
	var sphere = SphereShape3D.new()
	sphere.radius = radius
	query.shape = sphere
	query.transform = Transform3D(Basis(), origin)
	query.collision_mask = 2 # Balloons layer
	query.collide_with_bodies = true
	query.collide_with_areas = false
	query.exclude = [get_rid()]
	
	var results = space_state.intersect_shape(query, max_count)
	var list: Array[RigidBody3D] = []
	for res in results:
		var col = res.collider
		if col is RigidBody3D and is_instance_valid(col) and not col.get("is_popped"):
			list.append(col)
	return list

func trigger_plasma_chain(origin: Vector3) -> void:
	var victims = _get_nearby_balloons(origin, 5.5, 6)
	for t in victims:
		if is_instance_valid(t) and not t.get("is_popped"):
			t.pop("plasma_zap", 1)

func trigger_bomb_blast(origin: Vector3) -> void:
	var victims = _get_nearby_balloons(origin, 4.8, 10)
	for t in victims:
		if is_instance_valid(t) and not t.get("is_popped"):
			t.pop("bomb_blast", 1)

func trigger_color_chain(origin: Vector3, my_col: Color, next_depth: int) -> void:
	var victims = _get_nearby_balloons(origin, 1.4, 3)
	for target in victims:
		if is_instance_valid(target) and not target.get("is_popped"):
			var other_col: Color = target.get("balloon_color")
			if other_col.is_equal_approx(my_col) or my_col.to_html() == other_col.to_html():
				target.pop("color_chain", next_depth)
