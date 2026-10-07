extends Node3D

# Directional fan: a forward rectangular airflow volume, no pop damage.
const Feedback = preload("res://src/devices/device_feedback.gd")
var feedback: Node3D

@export var is_active: bool = true
@export var level: int = 1
@export var wind_strength: float = 5.5
@export var wind_range: float = 12.0
@export var fan_spin_speed: float = 20.0

static var ranges: Array[float] = [0.0, 9.0, 14.0, 20.0, 28.0, 36.0, 45.0]
static var strengths: Array[float] = [0.0, 22.0, 32.0, 45.0, 60.0, 80.0, 110.0]
static var global_fan_multiplier: float = 1.0

@onready var blades_node: Node3D = $Blades
@onready var wind_area: Area3D = $WindArea
@onready var wind_particles: CPUParticles3D = get_node_or_null("WindParticles")

func _ready() -> void:
	feedback = Feedback.new()
	add_child(feedback)
	feedback.configure(Color("66d8e0"), 1.0, 0.65, true)
	feedback.contact_label = "balon yönlendirildi"
	add_to_group("fans")
	add_to_group("devices")
	add_to_group("placeable_devices")
	setup_level(level)

func setup_level(new_level: int) -> void:
	level = max(new_level, 1)
	is_active = (level > 0)
	var idx = clamp(level, 1, ranges.size() - 1)
	wind_range = ranges[idx]
	wind_strength = strengths[idx]
	fan_spin_speed = 18.0 + (level * 3.5)
	
	if wind_area:
		var coll = wind_area.get_node_or_null("CollisionShape3D")
		if coll:
			var box = BoxShape3D.new()
			box.size = Vector3(4.5 + level * 0.8, 3.8 + level * 0.6, wind_range)
			coll.shape = box
			wind_area.position = Vector3(0, 1.7, -wind_range * 0.5)
			
	update_active_visuals()

func toggle() -> void:
	is_active = not is_active
	update_active_visuals()

func update_active_visuals() -> void:
	if wind_particles:
		wind_particles.emitting = is_active

func _process(delta: float) -> void:
	var facility = get_node_or_null("/root/Main")
	if facility and facility.is_blackout:
		if wind_particles: wind_particles.emitting = false
		return
	if wind_particles: wind_particles.emitting = is_active

	if is_active and level > 0 and blades_node:
		blades_node.rotate_z(fan_spin_speed * delta)

var _wind_tick_timer: float = 0.0

func _physics_process(delta: float) -> void:
	var facility = get_node_or_null("/root/Main")
	if facility and facility.is_blackout:
		if wind_particles: wind_particles.emitting = false
		return
	if wind_particles: wind_particles.emitting = is_active

	if not is_active or level <= 0 or not wind_area:
		return
		
	# Apply wind force at 30Hz throttle to halve physics force calculations across hundreds of balloons
	_wind_tick_timer += delta
	if _wind_tick_timer < 0.033:
		return
	var step_delta = minf(_wind_tick_timer, 0.1)
	_wind_tick_timer = 0.0
	
	var bodies = wind_area.get_overlapping_bodies()
	if bodies.is_empty():
		return
		
	var forward_dir = -global_transform.basis.z.normalized()
	var base_force_vec = (forward_dir + Vector3(0, 0.14, 0)).normalized()
	var base_str = wind_strength * global_fan_multiplier
	feedback.update_state(step_delta, 1.0, not bodies.is_empty())
	var my_pos = global_position
	
	for body in bodies:
		if body is RigidBody3D and is_instance_valid(body) and not body.is_queued_for_deletion() and body.is_in_group("balloons") and not body.get("is_popped"):
			var wall_query := PhysicsRayQueryParameters3D.create(global_position + Vector3(0, 1.7, 0), body.global_position, 1)
			if not get_world_3d().direct_space_state.intersect_ray(wall_query).is_empty(): continue
			if body.sleeping:
				body.sleeping = false
			var dist = my_pos.distance_to(body.global_position)
			var falloff = clamp(1.0 - (dist / wind_range), 0.25, 1.0)
			var speed = body.linear_velocity.length()
			var speed_damper = clamp(1.0 - (speed / 16.0), 0.35, 1.0)
			# Hafif balonlar rüzgarla güçlü bir şekilde savrulur
			var mass_inertia_scale = clampf(0.12 / sqrt(maxf(0.02, body.mass)), 0.35, 2.0)
			var effective_force = base_str * falloff * speed_damper * body.mass * mass_inertia_scale * step_delta
			body.apply_central_impulse(base_force_vec * effective_force)
			if "blown_by_fan_time" in body:
				body.blown_by_fan_time = Time.get_ticks_msec() / 1000.0
			feedback.record_contact(body)
