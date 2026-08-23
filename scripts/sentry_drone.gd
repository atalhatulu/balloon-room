extends Node3D

@export var is_active: bool = false
@export var level: int = 0

var cooldown_intervals: Array[float] = [1.4, 1.1, 0.85, 0.65, 0.50, 0.38]
var laser_ranges: Array[float] = [5.5, 7.0, 8.5, 10.0, 12.0, 14.5]
var max_targets_per_burst: Array[int] = [1, 2, 3, 4, 6, 8]

var cooldown_timer: float = 0.0
var hover_angle: float = 0.0

@onready var core_mesh: MeshInstance3D = get_node_or_null("CoreMesh")
@onready var eye_light: OmniLight3D = get_node_or_null("EyeLight")
@onready var laser_beam: MeshInstance3D = get_node_or_null("LaserBeam")

var player_node: Node3D = null

func _ready() -> void:
	add_to_group("devices")
	setup_level(level)

func setup_level(new_lvl: int) -> void:
	level = new_lvl
	is_active = (level > 0)
	visible = is_active
	if eye_light:
		eye_light.light_color = Color("#00d2d3") if is_active else Color("#576574")

func _process(delta: float) -> void:
	if not is_active:
		return
		
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
		fire_laser_burst()

func fire_laser_burst() -> void:
	var world = get_world_3d()
	if not world: return
	var space_state = world.direct_space_state
	if not space_state: return
	
	var idx = clamp(level - 1, 0, laser_ranges.size() - 1)
	var max_range = laser_ranges[idx]
	var max_shots = max_targets_per_burst[idx]
	var my_pos = global_position
	
	var shape_query = PhysicsShapeQueryParameters3D.new()
	var sphere = SphereShape3D.new()
	sphere.radius = max_range
	shape_query.shape = sphere
	shape_query.transform = Transform3D(Basis(), my_pos)
	shape_query.collision_mask = 2 # Balloons layer
	shape_query.collide_with_bodies = true
	shape_query.collide_with_areas = false
	
	var results = space_state.intersect_shape(shape_query, max_shots)
	for res in results:
		var target = res.collider
		if target is RigidBody3D and is_instance_valid(target) and not target.get("is_popped") and not target.is_queued_for_deletion():
			shoot_at_target(target)

func shoot_at_target(target: RigidBody3D) -> void:
	look_at(target.global_position, Vector3.UP)
	
	var main_node = get_node_or_null("/root/Main")
	if main_node and main_node.get("sound_manager"):
		main_node.sound_manager.play_zap()
		
	if laser_beam:
		var dist = global_position.distance_to(target.global_position)
		laser_beam.scale = Vector3(1, 1, dist)
		laser_beam.position = Vector3(0, -0.15, -dist * 0.5)
		laser_beam.visible = true
		
		get_tree().create_timer(0.06).timeout.connect(func():
			if laser_beam and is_instance_valid(laser_beam):
				laser_beam.visible = false
		)
		
	if target and is_instance_valid(target) and target.has_method("pop"):
		target.pop("sentry_drone", 0)

func update_position_for_room() -> void:
	pass
