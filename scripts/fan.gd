extends Node3D

# Room Fan: blows air in a wide cone to herd balloons across the room

@export var is_active: bool = true
@export var wind_strength: float = 14.0
@export var wind_range: float = 9.0
@export var fan_spin_speed: float = 24.0

@onready var blades_node: Node3D = $Blades
@onready var wind_area: Area3D = $WindArea
@onready var wind_particles = get_node_or_null("WindParticles")

func _ready() -> void:
	add_to_group("fans")
	update_active_visuals()

func toggle() -> void:
	is_active = not is_active
	update_active_visuals()

func update_active_visuals() -> void:
	if wind_particles:
		wind_particles.emitting = is_active

func _physics_process(delta: float) -> void:
	if not is_active:
		return
		
	# Spin blades
	if blades_node:
		blades_node.rotate_z(fan_spin_speed * delta)
		
	# Apply wind force to all balloons in the wind zone
	var bodies = wind_area.get_overlapping_bodies()
	var forward_dir = -global_transform.basis.z.normalized()
	
	for body in bodies:
		if body.is_in_group("balloons") and body is RigidBody3D:
			if body.has_method("wake_physics"):
				body.wake_physics()
			var distance = global_position.distance_to(body.global_position)
			var falloff = clamp(1.0 - (distance / wind_range), 0.1, 1.0)
			
			# Add slight upward lift and spreading vortex turbulence
			var turbulence = Vector3(
				sin(Time.get_ticks_msec() * 0.005 + body.global_position.x) * 0.3,
				0.2,
				cos(Time.get_ticks_msec() * 0.005 + body.global_position.z) * 0.3
			)
			var total_force = (forward_dir + turbulence).normalized() * (wind_strength * falloff)
			body.apply_central_force(total_force)
