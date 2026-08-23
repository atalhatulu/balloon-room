extends Node3D

@export var is_active: bool = false
@export var level: int = 0

var crush_speeds: Array[float] = [4.0, 6.0, 8.5, 12.0, 16.0, 22.0]
var vacuum_ranges: Array[float] = [2.2, 2.8, 3.5, 4.2, 5.0, 6.0]
var vacuum_forces: Array[float] = [2.5, 3.8, 5.2, 7.0, 9.0, 11.5]
var coin_bonuses: Array[int] = [1, 1, 2, 2, 3, 4]
var cooldown_times: Array[float] = [1.4, 1.1, 0.85, 0.65, 0.48, 0.35]
var max_batch_limits: Array[int] = [12, 20, 32, 50, 75, 110]

var roller_rotation_speed: float = 8.0
var process_timer: float = 0.0
var cooldown_timer: float = 0.0
var crushed_in_batch: int = 0
var is_cooling_down: bool = false

@onready var roller_left: MeshInstance3D = get_node_or_null("Chassis/RollerLeft")
@onready var roller_right: MeshInstance3D = get_node_or_null("Chassis/RollerRight")
@onready var vacuum_area: Area3D = get_node_or_null("VacuumArea")
@onready var vacuum_shape: CollisionShape3D = get_node_or_null("VacuumArea/CollisionShape3D")
@onready var grind_area: Area3D = get_node_or_null("GrindArea")
@onready var status_light: OmniLight3D = get_node_or_null("StatusLight")
@onready var spark_particles: CPUParticles3D = get_node_or_null("GrindSparks")

func _ready() -> void:
	add_to_group("devices")
	if grind_area:
		grind_area.collision_layer = 0
		grind_area.collision_mask = 2
		grind_area.body_entered.connect(_on_grind_body_entered)
	if vacuum_area:
		vacuum_area.collision_layer = 0
		vacuum_area.collision_mask = 2
	setup_level(level)

func setup_level(new_lvl: int) -> void:
	level = new_lvl
	is_active = (level > 0)
	visible = is_active
	
	if is_active:
		roller_rotation_speed = 6.0 + level * 3.5
		if vacuum_shape and vacuum_shape.shape is SphereShape3D:
			var idx = clamp(level - 1, 0, vacuum_ranges.size() - 1)
			vacuum_shape.shape.radius = vacuum_ranges[idx]
		if status_light:
			status_light.light_color = Color("#00ff88")
			status_light.light_energy = 1.6
		if spark_particles:
			spark_particles.emitting = true
	else:
		if status_light:
			status_light.light_color = Color("#ff4757")
			status_light.light_energy = 0.4
		if spark_particles:
			spark_particles.emitting = false

func _process(delta: float) -> void:
	if not is_active:
		return
		
	var speed_mult = 0.25 if is_cooling_down else 1.0
	if roller_left:
		roller_left.rotate_z(-roller_rotation_speed * speed_mult * delta)
	if roller_right:
		roller_right.rotate_z(roller_rotation_speed * speed_mult * delta)

func _physics_process(delta: float) -> void:
	if not is_active:
		return
		
	var idx = clamp(level - 1, 0, cooldown_times.size() - 1)
	var max_cd = cooldown_times[idx]
	
	# Cooldown State Management
	if is_cooling_down:
		cooldown_timer += delta
		if status_light:
			status_light.light_color = Color("#f39c12")
			status_light.light_energy = 0.8
		if spark_particles:
			spark_particles.emitting = false
			
		if cooldown_timer >= max_cd:
			is_cooling_down = false
			cooldown_timer = 0.0
			crushed_in_batch = 0
			if status_light:
				status_light.light_color = Color("#00ff88")
				status_light.light_energy = 1.6
			if spark_particles:
				spark_particles.emitting = true
				
	# Continuous Vacuum Suction & Direct Contact Check
	process_timer += delta
	if process_timer >= 0.06:
		process_timer = 0.0
		apply_vacuum_pull(idx)
		check_direct_grind()

func apply_vacuum_pull(idx: int) -> void:
	if not vacuum_area: return
	var v_range = vacuum_ranges[idx]
	var v_force = vacuum_forces[idx]
	var intake_point = global_position + global_transform.basis.z * 0.4 + Vector3(0, 0.35, 0)
	
	var bodies = vacuum_area.get_overlapping_bodies()
	for b in bodies:
		if b is RigidBody3D and is_instance_valid(b) and not b.is_queued_for_deletion():
			if not b.get("is_popped"):
				var dist = intake_point.distance_to(b.global_position)
				if dist <= v_range:
					if b.has_method("wake_physics"):
						b.wake_physics()
					var dir = (intake_point - b.global_position).normalized()
					var pull = clamp((v_range - dist) / v_range, 0.2, 1.0) * v_force
					b.apply_central_force(dir * pull)

func check_direct_grind() -> void:
	if is_cooling_down: return
	var world = get_world_3d()
	if not world: return
	var space_state = world.direct_space_state
	if not space_state: return
	
	var query = PhysicsShapeQueryParameters3D.new()
	var box = BoxShape3D.new()
	box.size = Vector3(2.2, 0.9, 1.1)
	query.shape = box
	query.transform = Transform3D(global_transform.basis, global_position + Vector3(0, 0.55, 0))
	query.collision_mask = 2
	query.collide_with_bodies = true
	query.collide_with_areas = false
	
	var results = space_state.intersect_shape(query, 6)
	for res in results:
		var body = res.collider
		if is_instance_valid(body) and not body.get("is_popped") and body.has_method("pop"):
			_on_grind_body_entered(body)

func _on_grind_body_entered(body: Node3D) -> void:
	if not is_active or is_cooling_down:
		return
		
	if body and body.is_in_group("balloons") and body.has_method("pop"):
		if not body.get("is_popped"):
			var main_node = get_node_or_null("/root/Main")
			if main_node and main_node.get("sound_manager"):
				main_node.sound_manager.play_crunch()
			if main_node and main_node.get("shop_manager"):
				var idx = clamp(level - 1, 0, coin_bonuses.size() - 1)
				main_node.shop_manager.add_coins(coin_bonuses[idx])
				
			body.pop("conveyor_crusher", 0)
			crushed_in_batch += 1
			
			var idx = clamp(level - 1, 0, max_batch_limits.size() - 1)
			if crushed_in_batch >= max_batch_limits[idx]:
				is_cooling_down = true
				cooldown_timer = 0.0
