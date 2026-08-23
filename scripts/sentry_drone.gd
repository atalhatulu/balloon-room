extends Node3D

@export var is_active: bool = false
@export var level: int = 0

var cooldown_intervals: Array[float] = [2.4, 1.8, 1.3, 0.9, 0.6]
var laser_ranges: Array[float] = [6.5, 9.5, 14.0, 20.0, 28.0]
var max_targets_per_burst: Array[int] = [1, 2, 2, 3, 4]

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
	var idx = clamp(level - 1, 0, laser_ranges.size() - 1)
	var max_range = laser_ranges[idx]
	var max_r_sq = max_range * max_range
	var max_shots = max_targets_per_burst[idx]
	var my_pos = global_position
	
	var balloons = get_tree().get_nodes_in_group("balloons")
	var targets: Array[RigidBody3D] = []
	for b in balloons:
		if b is RigidBody3D and is_instance_valid(b) and not b.is_queued_for_deletion():
			if not b.get("is_popped"):
				if my_pos.distance_squared_to(b.global_position) <= max_r_sq:
					targets.append(b)
					if targets.size() >= max_shots:
						break
						
	for target in targets:
		if is_instance_valid(target) and not target.get("is_popped"):
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
