extends Node3D

# Room / Wall Fan: blows air in a wide cone to herd balloons across the room

@export var is_active: bool = true
@export var level: int = 1
@export var wind_strength: float = 14.0
@export var wind_range: float = 9.0
@export var fan_spin_speed: float = 24.0

var ranges: Array[float] = [0.0, 9.0, 12.0, 16.0, 20.0, 25.0, 32.0]
var strengths: Array[float] = [0.0, 14.0, 18.0, 24.0, 32.0, 42.0, 55.0]

@onready var blades_node: Node3D = $Blades
@onready var wind_area: Area3D = $WindArea
@onready var wind_particles: CPUParticles3D = get_node_or_null("WindParticles")

func _ready() -> void:
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
	fan_spin_speed = 22.0 + (level * 5.0)
	
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

func _physics_process(delta: float) -> void:
	if not is_active or level <= 0:
		return
		
	# Spin blades
	if blades_node:
		blades_node.rotate_z(fan_spin_speed * delta)
		
	# Apply wind force to all balloons in the wind zone
	if not wind_area: return
	var bodies = wind_area.get_overlapping_bodies()
	var forward_dir = -global_transform.basis.z.normalized()
	
	for body in bodies:
		if body.is_in_group("balloons") and body is RigidBody3D and is_instance_valid(body) and not body.is_queued_for_deletion():
			if body.has_method("wake_physics"):
				body.wake_physics()
			var distance = global_position.distance_to(body.global_position)
			var falloff = clamp(1.0 - (distance / wind_range), 0.15, 1.0)
			
			# Add slight upward lift and spreading vortex turbulence
			var turbulence = Vector3(
				sin(Time.get_ticks_msec() * 0.005 + body.global_position.x) * 0.25,
				0.15,
				cos(Time.get_ticks_msec() * 0.005 + body.global_position.z) * 0.25
			)
			var total_force = (forward_dir + turbulence).normalized() * (wind_strength * falloff)
			body.apply_central_force(total_force)
