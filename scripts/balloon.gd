extends RigidBody3D

signal popped(balloon_node: RigidBody3D, pop_position: Vector3, balloon_color: Color, combo_depth: int, balloon_type: int)

@export var pop_particle_scene: PackedScene = preload("res://scenes/pop_particle.tscn")

var balloon_color: Color = Color(1.0, 0.35, 0.45)
var is_popped: bool = false
var custom_color_set: bool = false

# Shared static material cache to batch draw calls across all balloons
static var _material_cache: Dictionary = {}
static var _active_particle_count: int = 0

@onready var mesh_instance: MeshInstance3D = $MeshInstance3D
@onready var collision_shape: CollisionShape3D = $CollisionShape3D

func _ready() -> void:
	add_to_group("balloons")
	can_sleep = true
	continuous_cd = false
	
	if mesh_instance:
		mesh_instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		
	if not custom_color_set:
		setup_random_color()
	else:
		_apply_cached_material()

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
	_apply_cached_material()

func setup_random_color() -> void:
	var palette = [
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
	balloon_color = palette[randi() % palette.size()]
	_apply_cached_material()

static func get_cached_material(color: Color) -> StandardMaterial3D:
	var key = color.to_html(false)
	if _material_cache.has(key):
		return _material_cache[key]
		
	var mat = StandardMaterial3D.new()
	mat.albedo_color = color
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_PER_PIXEL
	mat.roughness = 0.35
	mat.metallic = 0.05
	mat.metallic_specular = 0.4
	
	_material_cache[key] = mat
	return mat

static var _highlight_mat_cache: Dictionary = {}
static func get_highlight_material(color: Color) -> StandardMaterial3D:
	var key = color.to_html(false)
	if _highlight_mat_cache.has(key):
		return _highlight_mat_cache[key]
		
	var mat = StandardMaterial3D.new()
	mat.albedo_color = color.lightened(0.25)
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_PER_PIXEL
	mat.roughness = 0.2
	mat.emission_enabled = true
	mat.emission = Color(1.0, 1.0, 1.0)
	mat.emission_energy_multiplier = 0.6
	
	_highlight_mat_cache[key] = mat
	return mat

func _apply_cached_material() -> void:
	var mat = get_cached_material(balloon_color)
	if mesh_instance:
		mesh_instance.material_override = mat

func set_highlight(active: bool) -> void:
	if not mesh_instance or is_popped: return
	if active:
		mesh_instance.material_override = get_highlight_material(balloon_color)
	else:
		_apply_cached_material()

func pop(_trigger_source: String = "manual", combo_depth: int = 0) -> void:
	if is_popped:
		return
	is_popped = true
	
	var pop_pos = global_position
	var pop_col = balloon_color
	
	popped.emit(self, pop_pos, pop_col, combo_depth, 0)
	
	# Hide visual and disable collision immediately
	if mesh_instance: mesh_instance.visible = false
	if collision_shape: collision_shape.disabled = true
	freeze = true
	
	# Spawn visual rubber shreds with throttle cap
	if pop_particle_scene and _active_particle_count < 12:
		_active_particle_count += 1
		var particle = pop_particle_scene.instantiate()
		particle.position = pop_pos
		get_parent().add_child(particle)
		if particle.has_method("init"):
			particle.init(pop_col)
		particle.tree_exited.connect(func(): _active_particle_count = max(0, _active_particle_count - 1))
			
	queue_free()
