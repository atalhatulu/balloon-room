extends Node3D

# Wall Spikes: Vertical wall-mounted steel spikes that puncture balloons entering its zone

@export var is_active: bool = false
@export var level: int = 1

var cooldown_intervals: Array[float] = [0.0, 0.55, 0.44, 0.35, 0.26, 0.19, 0.14]
var batch_capacities: Array[int] = [0, 14, 25, 40, 65, 95, 140]

var cooldown_timer: float = 0.0

@onready var plate_mesh: MeshInstance3D = get_node_or_null("PlateMesh")
@onready var spikes_node: Node3D = get_node_or_null("Spikes")
@onready var trigger_area: Area3D = get_node_or_null("TriggerArea")
@onready var impact_particles: CPUParticles3D = get_node_or_null("ImpactParticles")
@onready var sound_manager = get_node_or_null("/root/Main/SoundManager")

func _ready() -> void:
	add_to_group("devices")
	add_to_group("placeable_devices")
	if trigger_area:
		trigger_area.collision_layer = 0
		trigger_area.collision_mask = 2
	setup_level(level)

func setup_level(new_level: int) -> void:
	level = max(new_level, 1)
	is_active = (level > 0)
	visible = is_active
	update_visuals()

func update_visuals() -> void:
	if not is_active or level <= 0:
		visible = false
		return
		
	visible = true

func _physics_process(delta: float) -> void:
	if not is_active or level <= 0:
		return
		
	cooldown_timer += delta
	var idx = clamp(level, 1, cooldown_intervals.size() - 1)
	var cd = cooldown_intervals[idx]
	
	if cooldown_timer >= cd:
		cooldown_timer = 0.0
		execute_spike_thrust()

func execute_spike_thrust() -> void:
	if not trigger_area: return
	var bodies = trigger_area.get_overlapping_bodies()
	if bodies.is_empty(): return
	
	var idx = clamp(level, 1, batch_capacities.size() - 1)
	var cap = batch_capacities[idx]
	var popped_count = 0
	
	for body in bodies:
		if popped_count >= cap: break
		if body.is_in_group("balloons") and body is RigidBody3D and is_instance_valid(body) and not body.is_queued_for_deletion():
			if not body.get("is_popped"):
				body.pop("wall_spikes")
				popped_count += 1
				
	if popped_count > 0:
		# Puncture thrust animation outward from wall
		if spikes_node:
			var tw = create_tween()
			tw.tween_property(spikes_node, "position:z", -0.42, 0.04)
			tw.tween_property(spikes_node, "position:z", 0.0, 0.10).set_delay(0.05)
			
		if impact_particles:
			impact_particles.emitting = true
			
		if sound_manager and sound_manager.has_method("play_pop"):
			sound_manager.play_pop(randi_range(2, 5))
