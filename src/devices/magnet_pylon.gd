extends Node3D

const Feedback = preload("res://src/devices/device_feedback.gd")
var feedback: Node3D


@export var is_active: bool = false
@export var level: int = 0

static var pull_ranges: Array[float] = [0.0, 3.8, 5.0, 6.5, 8.5, 11.0, 14.0]
static var pull_strengths: Array[float] = [0.0, 1.6, 2.6, 4.0, 6.0, 8.8, 12.5]
static var global_pull_multiplier: float = 1.0

var _pulling: bool = false

var tick_timer: float = 0.0
var tick_rate: float = 0.08 # 12.5 Hz physics queries
static var query_phase := 0

@onready var core_orb: MeshInstance3D = $CoreOrb
@onready var magnet_ring: MeshInstance3D = $MagneticRing
@onready var magnet_light: OmniLight3D = $MagnetLight
@onready var particles: CPUParticles3D = $MagneticParticles

# Cached physics query parameters to prevent continuous dynamic allocation in _physics_process
var _cached_query: PhysicsShapeQueryParameters3D = null
var _cached_sphere: SphereShape3D = null

func _ensure_physics_query() -> void:
	if _cached_sphere == null:
		_cached_sphere = SphereShape3D.new()
	if _cached_query == null:
		_cached_query = PhysicsShapeQueryParameters3D.new()
		_cached_query.shape = _cached_sphere
		_cached_query.collision_mask = 2 # Balloons layer
		_cached_query.collide_with_bodies = true
		_cached_query.collide_with_areas = false

func _ready() -> void:
	# Spread multiple magnets across physics frames instead of querying together.
	tick_timer = float(query_phase % 5) * tick_rate / 5.0
	query_phase += 1
	feedback = Feedback.new()
	feedback.name = "ActivityIndicator"
	add_child(feedback)
	feedback.configure(Color(0.65, 0.38, 1.0), 0.65, 0.4, true)
	add_to_group("devices")
	add_to_group("placeable_devices")
	_ensure_physics_query()
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
	
	_ensure_physics_query()
	if _cached_sphere:
		_cached_sphere.radius = r
	
	if magnet_light:
		magnet_light.omni_range = max(5.0, r * 0.85)
		magnet_light.light_energy = 1.0 + level * 0.25
		
	if particles:
		particles.emission_sphere_radius = clamp(r * 0.35, 1.4, 4.5)
		particles.emitting = true

func _physics_process(delta: float) -> void:
	var facility = get_node_or_null("/root/Main")
	if facility and facility.is_blackout:
		return

	if not is_active or level <= 0:
		return
		
	feedback.update_state(delta, 1.0 if _pulling else 0.125, _pulling)
	if core_orb:
		core_orb.scale = Vector3.ONE * (1.0 + feedback.flash * 0.18)
	if magnet_ring:
		magnet_ring.rotation.z = 0.3
		magnet_ring.rotate_y((3.5 if _pulling else 0.8) * delta)
		
	tick_timer += delta
	if tick_timer >= tick_rate:
		tick_timer = fmod(tick_timer, tick_rate)
		apply_magnetic_pull()

func apply_magnetic_pull() -> void:
	var world = get_world_3d()
	if not world: return
	var space_state = world.direct_space_state
	if not space_state: return
	
	_ensure_physics_query()
	var idx = clamp(level, 1, pull_ranges.size() - 1)
	var max_range = pull_ranges[idx]
	var strength = pull_strengths[idx]
	var center_pos = global_position + Vector3(0, 0.75, 0)
	
	_cached_query.transform = Transform3D(Basis(), center_pos)
	
	var max_pull_targets = 35 + (level * 15)
	var results = space_state.intersect_shape(_cached_query, max_pull_targets)
	_pulling = false
	for res in results:
		var b = res.collider
		if b is RigidBody3D and is_instance_valid(b) and not b.is_queued_for_deletion() and not b.get("is_popped"):
			var diff = center_pos - b.global_position
			var dist = diff.length()
			if dist > 0.35:
				_pulling = true
				if b.has_method("wake_physics"):
					b.wake_physics()
				var dir = diff / dist
				var falloff = clamp(1.0 - (dist / max_range), 0.15, 1.0)
				# Gentle magnetic drift with velocity damping so balloons don't slingshot
				var cur_speed = b.linear_velocity.length()
				var speed_damper = clamp(1.0 - (cur_speed / 4.0), 0.25, 1.0)
				var impulse_mag = (strength * global_pull_multiplier) * falloff * 0.08 * speed_damper
				var force = (dir + Vector3(0, 0.08, 0)).normalized() * impulse_mag
				b.apply_central_impulse(force)
				if "pulled_by_magnet_time" in b:
					b.pulled_by_magnet_time = Time.get_ticks_msec() / 1000.0
				feedback.record_contact(b)

	if _pulling:
		feedback.pulse()
