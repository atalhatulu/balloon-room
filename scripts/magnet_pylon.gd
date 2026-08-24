extends Node3D

@export var is_active: bool = false
@export var level: int = 0

static var pull_ranges: Array[float] = [0.0, 5.5, 7.5, 10.0, 13.0, 16.5, 20.0]
static var pull_strengths: Array[float] = [0.0, 4.5, 6.5, 9.0, 12.5, 17.0, 23.0]
static var global_pull_multiplier: float = 1.0

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
		magnet_light.omni_range = max(6.0, r * 0.85)
		magnet_light.light_energy = 1.2 + level * 0.35
		
	if particles:
		particles.emission_sphere_radius = clamp(r * 0.40, 1.8, 6.0)
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
	var world = get_world_3d()
	if not world: return
	var space_state = world.direct_space_state
	if not space_state: return
	
	var idx = clamp(level, 1, pull_ranges.size() - 1)
	var max_range = pull_ranges[idx]
	var strength = pull_strengths[idx]
	var center_pos = global_position + Vector3(0, 0.75, 0)
	
	var shape_query = PhysicsShapeQueryParameters3D.new()
	var sphere = SphereShape3D.new()
	sphere.radius = max_range
	shape_query.shape = sphere
	shape_query.transform = Transform3D(Basis(), center_pos)
	shape_query.collision_mask = 2
	shape_query.collide_with_bodies = true
	shape_query.collide_with_areas = false
	
	var max_pull_targets = 40 + (level * 20)
	var results = space_state.intersect_shape(shape_query, max_pull_targets)
	for res in results:
		var b = res.collider
		if b is RigidBody3D and is_instance_valid(b) and not b.is_queued_for_deletion() and not b.get("is_popped"):
			var diff = center_pos - b.global_position
			var dist = diff.length()
			if dist > 0.4:
				if b.has_method("wake_physics"):
					b.wake_physics()
				var dir = diff / dist
				var falloff = clamp(1.0 - (dist / max_range), 0.20, 1.0)
				var impulse_mag = (strength * global_pull_multiplier) * falloff * 0.22
				var force = (dir + Vector3(0, 0.12, 0)).normalized() * impulse_mag
				b.apply_central_impulse(force)
