class_name BrokenPipeHazard
extends Node3D

signal pipe_repaired()

var is_ruptured: bool = false
var repair_progress := 0.0
var repair_sound_timer := 0.0
var alarm_phase := 0.0
var repair_label: Label3D
var steam_particles: CPUParticles3D = null
var spark_particles: CPUParticles3D = null
var warning_light: OmniLight3D = null
var interaction_area: Area3D = null
var valve_wheel: MeshInstance3D = null
var hiss_player: AudioStreamPlayer3D = null

func _ready() -> void:
	name = "BrokenPipeHazard"
	_build_pipe_visuals()
	_build_particles_and_audio()
	# Keep the intact pressure line visible so the player can learn its location
	# before an overpressure emergency. Rupture state is still indicated by the
	# blinking beacon, sparks, steam and the interaction prompt.
	visible = true

func _build_pipe_visuals() -> void:
	# Heavy industrial pipe junction mounted to wall/ceiling
	var mat_pipe = StandardMaterial3D.new()
	mat_pipe.albedo_color = Color(0.28, 0.32, 0.35)
	mat_pipe.metallic = 0.8
	mat_pipe.roughness = 0.35
	
	var mat_yellow = StandardMaterial3D.new()
	mat_yellow.albedo_color = Color(0.92, 0.72, 0.15)
	mat_yellow.metallic = 0.2
	mat_yellow.roughness = 0.4
	
	var mat_red_valve = StandardMaterial3D.new()
	mat_red_valve.albedo_color = Color(0.88, 0.18, 0.18)
	mat_red_valve.roughness = 0.3
	
	# Main pipe body
	var pipe_body = MeshInstance3D.new()
	var cyl = CylinderMesh.new()
	cyl.top_radius = 0.16
	cyl.bottom_radius = 0.16
	cyl.height = 1.8
	pipe_body.mesh = cyl
	pipe_body.material_override = mat_pipe
	pipe_body.rotation_degrees = Vector3(0, 0, 90)
	add_child(pipe_body)
	
	# Flanges / Collar
	for x in [-0.75, 0.75]:
		var flange = MeshInstance3D.new()
		var f_mesh = CylinderMesh.new()
		f_mesh.top_radius = 0.22
		f_mesh.bottom_radius = 0.22
		f_mesh.height = 0.08
		flange.mesh = f_mesh
		flange.material_override = mat_yellow
		flange.rotation_degrees = Vector3(0, 0, 90)
		flange.position = Vector3(x, 0, 0)
		add_child(flange)
		
	# Rupture breach seam (Center)
	var breach = MeshInstance3D.new()
	var b_box = BoxMesh.new()
	b_box.size = Vector3(0.35, 0.35, 0.12)
	breach.mesh = b_box
	breach.material_override = mat_yellow
	breach.position = Vector3(0, 0, 0.12)
	add_child(breach)
	
	# Manual Emergency Shut-off Valve Wheel
	valve_wheel = MeshInstance3D.new()
	var v_mesh = TorusMesh.new()
	v_mesh.inner_radius = 0.12
	v_mesh.outer_radius = 0.22
	valve_wheel.mesh = v_mesh
	valve_wheel.material_override = mat_red_valve
	valve_wheel.position = Vector3(0, -0.32, 0.20)
	valve_wheel.rotation_degrees = Vector3(90, 0, 0)
	add_child(valve_wheel)
	for angle in [0.0, PI / 2.0]:
		var spoke := MeshInstance3D.new()
		var spoke_mesh := BoxMesh.new()
		spoke_mesh.size = Vector3(0.35, 0.025, 0.025)
		spoke.mesh = spoke_mesh
		spoke.material_override = mat_red_valve
		spoke.rotation.y = angle
		valve_wheel.add_child(spoke)
	
	# Wall Label
	var lbl = Label3D.new()
	lbl.text = "BASINÇ HATTI #04"
	lbl.font_size = 28
	lbl.modulate = Color(0.95, 0.85, 0.2)
	lbl.pixel_size = 0.003
	lbl.position = Vector3(0, 0.42, 0.18)
	add_child(lbl)
	repair_label = Label3D.new()
	repair_label.font_size = 24
	repair_label.pixel_size = 0.003
	repair_label.position = Vector3(0, -0.72, 0.25)
	add_child(repair_label)
	repair_label.text = "HAT NORMAL"
	
	# Interaction Area for Raycast / Crosshair detection
	interaction_area = Area3D.new()
	interaction_area.name = "RepairArea"
	interaction_area.collision_layer = 1
	interaction_area.collision_mask = 1
	var col = CollisionShape3D.new()
	var box_shape = BoxShape3D.new()
	box_shape.size = Vector3(1.6, 1.4, 0.8)
	col.shape = box_shape
	interaction_area.add_child(col)
	add_child(interaction_area)
	interaction_area.add_to_group("broken_pipe")

func _build_particles_and_audio() -> void:
	# 1. High-pressure steam particles
	steam_particles = CPUParticles3D.new()
	steam_particles.amount = 45
	steam_particles.lifetime = 0.65
	steam_particles.speed_scale = 1.2
	steam_particles.explosiveness = 0.05
	steam_particles.randomness = 0.4
	steam_particles.direction = Vector3(0, -0.4, 1.0).normalized()
	steam_particles.spread = 28.0
	steam_particles.initial_velocity_min = 4.5
	steam_particles.initial_velocity_max = 7.5
	steam_particles.scale_amount_min = 0.15
	steam_particles.scale_amount_max = 0.45
	
	var steam_mesh = SphereMesh.new()
	steam_mesh.radius = 0.15
	steam_mesh.height = 0.30
	var steam_mat = StandardMaterial3D.new()
	steam_mat.albedo_color = Color(0.92, 0.95, 1.0, 0.35)
	steam_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	steam_mat.roughness = 1.0
	steam_mesh.material = steam_mat
	steam_particles.mesh = steam_mesh
	steam_particles.position = Vector3(0, 0, 0.18)
	steam_particles.emitting = false
	add_child(steam_particles)
	
	# 2. Electric Sparks
	spark_particles = CPUParticles3D.new()
	spark_particles.amount = 16
	spark_particles.lifetime = 0.35
	spark_particles.direction = Vector3(0, -1, 0.8).normalized()
	spark_particles.spread = 45.0
	spark_particles.initial_velocity_min = 3.0
	spark_particles.initial_velocity_max = 6.0
	spark_particles.scale_amount_min = 0.04
	spark_particles.scale_amount_max = 0.08
	
	var spark_mesh = SphereMesh.new()
	spark_mesh.radius = 0.04
	spark_mesh.height = 0.08
	var spark_mat = StandardMaterial3D.new()
	spark_mat.albedo_color = Color(1.0, 0.75, 0.2)
	spark_mat.emission_enabled = true
	spark_mat.emission = Color(1.0, 0.8, 0.2)
	spark_mat.emission_energy_multiplier = 4.5
	spark_mesh.material = spark_mat
	spark_particles.mesh = spark_mesh
	spark_particles.position = Vector3(0, 0, 0.18)
	spark_particles.emitting = false
	add_child(spark_particles)
	
	# 3. Warning Red Beacon Light
	warning_light = OmniLight3D.new()
	warning_light.light_color = Color(1.0, 0.2, 0.1)
	warning_light.light_energy = 0.0
	warning_light.omni_range = 5.0
	warning_light.position = Vector3(0, 0.25, 0.4)
	add_child(warning_light)

func trigger_rupture() -> void:
	if is_ruptured: return
	is_ruptured = true
	visible = true
	steam_particles.speed_scale = 1.2
	steam_particles.emitting = true
	spark_particles.emitting = true
	warning_light.light_energy = 2.5
	
	repair_progress = 0.0

func _process(delta: float) -> void:
	if not is_ruptured: return
	alarm_phase += delta
	warning_light.light_energy = 0.3 + 2.2 * (0.5 + 0.5 * sin(alarm_phase * TAU * 1.2))

func advance_repair(delta: float, holding: bool) -> bool:
	if not is_ruptured: return false
	if holding:
		repair_sound_timer -= delta
		if repair_sound_timer <= 0.0:
			preload("res://src/environment/interaction_feedback.gd").sound(self, "repair")
			repair_sound_timer = 0.55
	else:
		repair_sound_timer = 0.0
	repair_progress = minf(1.0, repair_progress + delta / 2.0) if holding else 0.0
	valve_wheel.rotation_degrees.z = repair_progress * 360.0
	steam_particles.speed_scale = lerpf(1.2, 0.25, repair_progress)
	repair_label.text = "VANA KAPATILIYOR • %d%%" % int(repair_progress * 100.0) if holding else "KAÇAK • [E] BASILI TUT"
	return repair_progress >= 1.0

func repair() -> void:
	if not is_ruptured: return
	is_ruptured = false
	steam_particles.emitting = false
	spark_particles.emitting = false
	warning_light.light_energy = 0.0
	
	repair_progress = 0.0
	repair_label.text = "HAT GÜVENLİ • ELEKTRİK PANOSUNA GİT"

	pipe_repaired.emit()
