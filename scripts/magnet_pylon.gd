extends Node3D

@export var is_active: bool = false
@export var level: int = 0

var pull_ranges: Array[float] = [0.0, 3.5, 4.5, 5.8, 7.2, 8.8, 10.5]
var pull_strengths: Array[float] = [0.0, 2.8, 4.0, 5.5, 7.2, 9.0, 11.5]

var tick_timer: float = 0.0
var tick_rate: float = 0.08 # 12.5 Hz for buttery smooth 100+ FPS performance

@onready var core_orb: MeshInstance3D = $CoreOrb
@onready var magnet_ring: MeshInstance3D = $MagneticRing
@onready var magnet_light: OmniLight3D = $MagnetLight
@onready var particles: CPUParticles3D = $MagneticParticles

func _ready() -> void:
	add_to_group("devices")
	add_to_group("placeable_devices")
	update_visuals()

func setup_level(new_level: int) -> void:
	level = max(new_level, 1)
	is_active = (level > 0)
	visible = is_active
	update_visuals()

func update_visuals() -> void:
	if not is_active or level <= 0:
		visible = false
		if particles:
			particles.emitting = false
		return
		
	visible = true
	var idx = clamp(level, 1, pull_ranges.size() - 1)
	var r = pull_ranges[idx]
	
	if magnet_light:
		magnet_light.omni_range = max(6.0, r * 0.8)
		magnet_light.light_energy = 1.2 + level * 0.35
		
	if particles:
		particles.emission_sphere_radius = clamp(r * 0.3, 1.5, 5.0)
		particles.emitting = true

func _physics_process(delta: float) -> void:
	if not is_active or level <= 0:
		return
		
	if magnet_ring:
		magnet_ring.rotate_y(2.5 * delta)
		
	tick_timer += delta
	if tick_timer >= tick_rate:
		tick_timer = 0.0
		apply_magnetic_pull()

func apply_magnetic_pull() -> void:
	var idx = clamp(level, 1, pull_ranges.size() - 1)
	var max_range = pull_ranges[idx]
	var max_range_sq = max_range * max_range
	var strength = pull_strengths[idx]
	var center_pos = global_position + Vector3(0, 0.6, 0)
	
	var balloons = get_tree().get_nodes_in_group("balloons")
	for b in balloons:
		if b is RigidBody3D and is_instance_valid(b) and not b.is_queued_for_deletion() and not b.get("is_popped"):
			var diff = center_pos - b.global_position
			var dist_sq = diff.length_squared()
			if dist_sq < max_range_sq and dist_sq > 0.4:
				if b.has_method("wake_physics"):
					b.wake_physics()
				var dist = sqrt(dist_sq)
				var dir = diff / dist
				var falloff = clamp(1.0 - (dist / max_range), 0.2, 1.0)
				var force = dir * (falloff * strength * 0.06)
				b.apply_central_impulse(force)
