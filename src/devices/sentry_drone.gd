extends Node3D

@export var is_active: bool = false
@export var level: int = 0

var cooldown_intervals: Array[float] = [0.45, 0.35, 0.28, 0.22, 0.16, 0.12]
var laser_ranges: Array[float] = [12.0, 15.0, 18.0, 22.0, 26.0, 30.0]

var cooldown_timer: float = 0.0
var hover_angle: float = 0.0

@onready var core_mesh: MeshInstance3D = get_node_or_null("CoreMesh")
@onready var eye_light: OmniLight3D = get_node_or_null("EyeLight")
@onready var laser_beam: MeshInstance3D = get_node_or_null("LaserBeam")

var player_node: Node3D = null
var _cached_query: PhysicsShapeQueryParameters3D = null
var _cached_sphere: SphereShape3D = null
var _main_ref: Node = null
var _sound_manager_ref: Node = null
var _laser_timer: float = 0.0
var needle_arm: Node3D = null
var needle_mesh: MeshInstance3D = null

func _ensure_physics_query() -> void:
	if _cached_sphere == null:
		_cached_sphere = SphereShape3D.new()
		var idx = clamp(level - 1, 0, laser_ranges.size() - 1)
		_cached_sphere.radius = laser_ranges[idx]
	if _cached_query == null:
		_cached_query = PhysicsShapeQueryParameters3D.new()
		_cached_query.shape = _cached_sphere
		_cached_query.collision_mask = 2
		_cached_query.collide_with_bodies = true
		_cached_query.collide_with_areas = false

func _ready() -> void:
	add_to_group("devices")
	_create_needle_arm()
	_ensure_physics_query()
	_main_ref = get_node_or_null("/root/Main")
	if _main_ref:
		_sound_manager_ref = _main_ref.get("sound_manager")
	setup_level(level)

func _create_needle_arm() -> void:
	if needle_arm != null: return
	needle_arm = Node3D.new()
	needle_arm.name = "NeedleArm"
	add_child(needle_arm)
	needle_arm.position = Vector3(0.0, -0.12, -0.2)

	needle_mesh = MeshInstance3D.new()
	needle_mesh.name = "ArmNeedleMesh"
	var cyl = CylinderMesh.new()
	cyl.top_radius = 0.005
	cyl.bottom_radius = 0.02
	cyl.height = 0.35
	needle_mesh.mesh = cyl
	needle_mesh.rotation_degrees = Vector3(90, 0, 0)
	needle_mesh.position = Vector3(0, 0, -0.15)
	
	var mat = StandardMaterial3D.new()
	mat.albedo_color = Color(0.85, 0.85, 0.9)
	mat.metallic = 0.95
	mat.roughness = 0.15
	needle_mesh.material_override = mat
	needle_arm.add_child(needle_mesh)

func setup_level(new_lvl: int) -> void:
	level = new_lvl
	is_active = (level > 0)
	visible = is_active
	if eye_light:
		eye_light.light_color = Color("#00d2d3") if is_active else Color("#576574")
	if _cached_sphere:
		var idx = clamp(level - 1, 0, laser_ranges.size() - 1)
		_cached_sphere.radius = laser_ranges[idx]

func _process(delta: float) -> void:
	var facility = get_node_or_null("/root/Main")
	if facility and facility.is_blackout:
		return

	if not is_active:
		return
		
	# Laser beam flash countdown (Zero-allocation timer)
	if _laser_timer > 0.0:
		_laser_timer -= delta
		if _laser_timer <= 0.0 and laser_beam and is_instance_valid(laser_beam):
			laser_beam.visible = false
		
	hover_angle += delta * 2.5
	
	if not player_node or not is_instance_valid(player_node):
		player_node = get_tree().get_first_node_in_group("player")
		
	if player_node and is_instance_valid(player_node):
		var target_pos = player_node.global_position + Vector3(
			sin(hover_angle) * 1.6,
			2.4 + sin(hover_angle * 1.8) * 0.25,
			cos(hover_angle) * 1.6
		)
		global_position = global_position.lerp(target_pos, 7.0 * delta)
		
	cooldown_timer += delta
	var idx = clamp(level - 1, 0, cooldown_intervals.size() - 1)
	var cd = cooldown_intervals[idx]
	
	if eye_light:
		var charge_pct = clamp(cooldown_timer / cd, 0.0, 1.0)
		eye_light.light_energy = 0.3 + charge_pct * 1.2
		
	if cooldown_timer >= cd:
		cooldown_timer = 0.0
		fire_single_shot()

func fire_single_shot() -> void:
	var world = get_world_3d()
	if not world: return
	var space_state = world.direct_space_state
	if not space_state: return
	
	_ensure_physics_query()
	_cached_query.transform = Transform3D(Basis(), global_position)
	
	var results = space_state.intersect_shape(_cached_query, 32)
	var candidates: Array = []
	for res in results:
		var target = res.collider
		if target is RigidBody3D and is_instance_valid(target) and not target.get("is_popped") and not target.is_queued_for_deletion():
			if target.has_method("can_pop") and not target.can_pop("sentry_drone"): continue
			candidates.append(target)
			
	if candidates.is_empty(): return
	
	# Priority Sort: Special Gas Types (chroma, bomb, gold) > High Tiers (50, 10, 5) > Nearest Distance
	candidates.sort_custom(func(a, b):
		var a_special = 1 if (a.get("gas_type") != "normal") else 0
		var b_special = 1 if (b.get("gas_type") != "normal") else 0
		if a_special != b_special:
			return a_special > b_special
		var a_tier = int(a.get("tier")) if ("tier" in a) else 1
		var b_tier = int(b.get("tier")) if ("tier" in b) else 1
		if a_tier != b_tier:
			return a_tier > b_tier
		return global_position.distance_squared_to(a.global_position) < global_position.distance_squared_to(b.global_position)
	)
	
	# Single target pop only
	shoot_at_target(candidates[0])

func shoot_at_target(target: RigidBody3D) -> void:
	if not target or not is_instance_valid(target): return
	if target.has_method("can_pop") and not target.can_pop("sentry_drone"): return
	
	look_at(target.global_position, Vector3.UP)
	
	# Needle arm stab animation
	if needle_arm and is_instance_valid(needle_arm):
		var tw = create_tween()
		tw.tween_property(needle_arm, "position:z", -0.45, 0.05).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		tw.tween_property(needle_arm, "position:z", -0.2, 0.08).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	
	if not is_instance_valid(_sound_manager_ref):
		_main_ref = get_node_or_null("/root/Main")
		if _main_ref:
			_sound_manager_ref = _main_ref.get("sound_manager")
	if _sound_manager_ref and _sound_manager_ref.has_method("play_zap"):
		_sound_manager_ref.play_zap()
		
	if laser_beam:
		var dist = global_position.distance_to(target.global_position)
		laser_beam.scale = Vector3(1, 1, dist)
		laser_beam.position = Vector3(0, -0.15, -dist * 0.5)
		laser_beam.visible = true
		_laser_timer = 0.05
		
	if target.has_method("pop"):
		target.pop("sentry_drone", 0)

func update_position_for_room() -> void:
	pass
