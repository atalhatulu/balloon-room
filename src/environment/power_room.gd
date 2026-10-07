class_name PowerRoom
extends Node3D

signal power_restored()

var is_power_active: bool = true
var breaker_switch: Node3D = null
var breaker_spark_particles: CPUParticles3D = null
var emergency_light: OmniLight3D = null
var panel_status_light: MeshInstance3D = null
var panel_status_label: Label3D = null
var switch_handle: MeshInstance3D = null

func _ready() -> void:
	name = "PowerRoom"
	_build_room_geometry()
	_build_breaker_panel()

func _create_pbr_mat(albedo: Color, rough: float = 0.5, metal: float = 0.0, emit_col: Color = Color.BLACK, emit_energy: float = 0.0) -> StandardMaterial3D:
	var mat = StandardMaterial3D.new()
	mat.albedo_color = albedo
	mat.roughness = rough
	mat.metallic = metal
	if emit_energy > 0.0:
		mat.emission_enabled = true
		mat.emission = emit_col
		mat.emission_energy_multiplier = emit_energy
	return mat

func _build_room_geometry() -> void:
	# Small electrical generator & maintenance room behind the South door
	# Room dimensions: W = 7.0m, L = 6.0m, H = 4.0m
	# Center of room: x = 0, y = 0, z = 3.25 (extends from z = 0.25 to z = 6.25)
	
	var mat_floor = _create_pbr_mat(Color(0.22, 0.24, 0.26), 0.7, 0.1) # Dark utility industrial concrete
	var mat_wall = _create_pbr_mat(Color(0.35, 0.38, 0.40), 0.8, 0.05) # Gray industrial cinderblock
	var mat_ceiling = _create_pbr_mat(Color(0.18, 0.20, 0.22), 0.85, 0.1) # Dark technical ceiling
	var mat_metal_trim = _create_pbr_mat(Color(0.85, 0.65, 0.10), 0.4, 0.3) # Hazard yellow stripes
	
	# 1. Floor
	var floor_body = StaticBody3D.new()
	floor_body.name = "UtilityFloor"
	var f_mesh = MeshInstance3D.new()
	var f_box = BoxMesh.new()
	f_box.size = Vector3(7.0, 0.5, 6.0)
	f_mesh.mesh = f_box
	f_mesh.material_override = mat_floor
	floor_body.add_child(f_mesh)
	
	var f_col = CollisionShape3D.new()
	f_col.shape = BoxShape3D.new()
	f_col.shape.size = f_box.size
	floor_body.add_child(f_col)
	floor_body.position = Vector3(0, -0.25, 3.25)
	add_child(floor_body)
	
	# 2. Ceiling
	var ceil_body = StaticBody3D.new()
	ceil_body.name = "UtilityCeiling"
	var c_mesh = MeshInstance3D.new()
	c_mesh.mesh = f_box
	c_mesh.material_override = mat_ceiling
	ceil_body.add_child(c_mesh)
	
	var c_col = CollisionShape3D.new()
	c_col.shape = BoxShape3D.new()
	c_col.shape.size = f_box.size
	ceil_body.add_child(c_col)
	ceil_body.position = Vector3(0, 4.25, 3.25)
	add_child(ceil_body)
	
	# 3. Back Wall (South of PowerRoom, z = +6.25)
	var back_wall = StaticBody3D.new()
	back_wall.name = "BackWall"
	var bw_mesh = MeshInstance3D.new()
	var bw_box = BoxMesh.new()
	bw_box.size = Vector3(7.0, 4.0, 0.5)
	bw_mesh.mesh = bw_box
	bw_mesh.material_override = mat_wall
	back_wall.add_child(bw_mesh)
	
	var bw_col = CollisionShape3D.new()
	bw_col.shape = BoxShape3D.new()
	bw_col.shape.size = bw_box.size
	back_wall.add_child(bw_col)
	back_wall.position = Vector3(0, 2.0, 6.25)
	add_child(back_wall)
	
	# 4. West Wall (x = -3.5m)
	var west_wall = StaticBody3D.new()
	west_wall.name = "WestWall"
	var sw_mesh = MeshInstance3D.new()
	var sw_box = BoxMesh.new()
	sw_box.size = Vector3(0.5, 4.0, 6.0)
	sw_mesh.mesh = sw_box
	sw_mesh.material_override = mat_wall
	west_wall.add_child(sw_mesh)
	
	var sw_col = CollisionShape3D.new()
	sw_col.shape = BoxShape3D.new()
	sw_col.shape.size = sw_box.size
	west_wall.add_child(sw_col)
	west_wall.position = Vector3(-3.5, 2.0, 3.25)
	add_child(west_wall)
	
	# 5. East Wall (x = +3.5m)
	var east_wall = StaticBody3D.new()
	east_wall.name = "EastWall"
	var ew_mesh = MeshInstance3D.new()
	ew_mesh.mesh = sw_box
	ew_mesh.material_override = mat_wall
	east_wall.add_child(ew_mesh)
	
	var ew_col = CollisionShape3D.new()
	ew_col.shape = BoxShape3D.new()
	ew_col.shape.size = sw_box.size
	east_wall.add_child(ew_col)
	east_wall.position = Vector3(3.5, 2.0, 3.25)
	add_child(east_wall)
	
	# 6. Front Wall Portals (Left and right flanking the 2.5m door opening at z = +0.20)
	# Door is at x in [-1.25, 1.25], openings span from x=-3.5 to -1.25 (width 2.25) and 1.25 to 3.5 (width 2.25)
	var front_l = StaticBody3D.new()
	var fw_box = BoxMesh.new()
	fw_box.size = Vector3(2.25, 4.0, 0.4)
	var fw_l_mesh = MeshInstance3D.new()
	fw_l_mesh.mesh = fw_box
	fw_l_mesh.material_override = mat_wall
	front_l.add_child(fw_l_mesh)
	var fw_l_col = CollisionShape3D.new()
	fw_l_col.shape = BoxShape3D.new()
	fw_l_col.shape.size = fw_box.size
	front_l.add_child(fw_l_col)
	front_l.position = Vector3(-2.375, 2.0, 0.20)
	add_child(front_l)
	
	var front_r = StaticBody3D.new()
	var fw_r_mesh = MeshInstance3D.new()
	fw_r_mesh.mesh = fw_box
	fw_r_mesh.material_override = mat_wall
	front_r.add_child(fw_r_mesh)
	var fw_r_col = CollisionShape3D.new()
	fw_r_col.shape = BoxShape3D.new()
	fw_r_col.shape.size = fw_box.size
	front_r.add_child(fw_r_col)
	front_r.position = Vector3(2.375, 2.0, 0.20)
	add_child(front_r)
	
	# Overhead header above door (x in [-1.25, 1.25], y from 2.8 to 4.0 -> H=1.2, center y=3.4)
	var front_top = StaticBody3D.new()
	var ftop_box = BoxMesh.new()
	ftop_box.size = Vector3(2.5, 1.2, 0.4)
	var ftop_mesh = MeshInstance3D.new()
	ftop_mesh.mesh = ftop_box
	ftop_mesh.material_override = mat_wall
	front_top.add_child(ftop_mesh)
	var ftop_col = CollisionShape3D.new()
	ftop_col.shape = BoxShape3D.new()
	ftop_col.shape.size = ftop_box.size
	front_top.add_child(ftop_col)
	front_top.position = Vector3(0, 3.4, 0.20)
	add_child(front_top)

	# 7. Heavy Generator Machinery Props on the sides
	_build_generator_props()

	# 8. Room Emergency Light
	emergency_light = OmniLight3D.new()
	emergency_light.name = "EmergencyLight"
	emergency_light.position = Vector3(0, 3.5, 3.25)
	emergency_light.omni_range = 9.0
	emergency_light.light_energy = 0.3
	emergency_light.light_color = Color(0.3, 0.7, 1.0)
	add_child(emergency_light)

func _build_generator_props() -> void:
	var mat_gen = _create_pbr_mat(Color(0.18, 0.28, 0.22), 0.45, 0.6) # Industrial sage green generator
	var mat_pipe = _create_pbr_mat(Color(0.25, 0.27, 0.29), 0.3, 0.8) # Heavy cast steel pipes
	
	# Left generator unit
	var gen_body = StaticBody3D.new()
	var g_box = BoxMesh.new()
	g_box.size = Vector3(1.2, 1.8, 2.8)
	var g_mesh = MeshInstance3D.new()
	g_mesh.mesh = g_box
	g_mesh.material_override = mat_gen
	gen_body.add_child(g_mesh)
	var g_col = CollisionShape3D.new()
	g_col.shape = BoxShape3D.new()
	g_col.shape.size = g_box.size
	gen_body.add_child(g_col)
	gen_body.position = Vector3(-2.6, 0.9, 3.5)
	add_child(gen_body)
	
	# Cable conduits along the ceiling
	var conduit = MeshInstance3D.new()
	var c_cyl = CylinderMesh.new()
	c_cyl.top_radius = 0.06
	c_cyl.bottom_radius = 0.06
	c_cyl.height = 5.5
	conduit.mesh = c_cyl
	conduit.material_override = mat_pipe
	conduit.rotation_degrees = Vector3(90, 0, 0)
	conduit.position = Vector3(1.8, 3.8, 3.25)
	add_child(conduit)

func _build_breaker_panel() -> void:
	# Breaker box mounted on the back wall (x = 0, y = 1.6, z = 5.95)
	var panel_body = StaticBody3D.new()
	panel_body.name = "BreakerPanelBody"
	panel_body.add_to_group("power_panel")
	
	var mat_cabinet = _create_pbr_mat(Color(0.12, 0.13, 0.15), 0.35, 0.7) # Dark industrial electrical steel
	var mat_yellow_stripe = _create_pbr_mat(Color(0.95, 0.75, 0.10), 0.4, 0.2)
	var mat_lever_red = _create_pbr_mat(Color(0.85, 0.15, 0.15), 0.25, 0.4)
	var mat_status_green = _create_pbr_mat(Color(0.1, 0.1, 0.1), 0.2, 0.0, Color(0.15, 0.95, 0.35), 3.5)
	
	# Metal cabinet box (W: 1.1m, H: 1.5m, D: 0.25m)
	var box_mesh = BoxMesh.new()
	box_mesh.size = Vector3(1.10, 1.50, 0.25)
	var cabinet = MeshInstance3D.new()
	cabinet.mesh = box_mesh
	cabinet.material_override = mat_cabinet
	panel_body.add_child(cabinet)
	
	var col_box = CollisionShape3D.new()
	col_box.shape = BoxShape3D.new()
	col_box.shape.size = box_mesh.size
	panel_body.add_child(col_box)
	
	# Yellow hazard warning border
	var hazard_top = MeshInstance3D.new()
	var hz_mesh = BoxMesh.new()
	hz_mesh.size = Vector3(1.12, 0.08, 0.26)
	hazard_top.mesh = hz_mesh
	hazard_top.material_override = mat_yellow_stripe
	hazard_top.position = Vector3(0, 0.71, 0)
	panel_body.add_child(hazard_top)
	
	# Status Indicator LED
	panel_status_light = MeshInstance3D.new()
	var led_cyl = CylinderMesh.new()
	led_cyl.top_radius = 0.05
	led_cyl.bottom_radius = 0.05
	led_cyl.height = 0.03
	panel_status_light.mesh = led_cyl
	panel_status_light.material_override = mat_status_green
	panel_status_light.rotation_degrees = Vector3(90, 0, 0)
	panel_status_light.position = Vector3(0, 0.45, 0.13)
	panel_body.add_child(panel_status_light)
	
	# Status Text
	panel_status_label = Label3D.new()
	panel_status_label.text = "ŞEBEKE: AKTİF"
	panel_status_label.font_size = 28
	panel_status_label.modulate = Color(0.2, 0.95, 0.4)
	panel_status_label.pixel_size = 0.003
	panel_status_label.position = Vector3(0, 0.32, 0.14)
	panel_body.add_child(panel_status_label)
	
	# Heavy Knife-Switch Lever / Breaker Handle
	breaker_switch = Node3D.new()
	breaker_switch.name = "BreakerSwitch"
	breaker_switch.position = Vector3(0, -0.10, 0.14)
	panel_body.add_child(breaker_switch)
	
	# Lever Pivot Base
	var base_mesh = MeshInstance3D.new()
	var b_mesh = BoxMesh.new()
	b_mesh.size = Vector3(0.12, 0.22, 0.06)
	base_mesh.mesh = b_mesh
	base_mesh.material_override = mat_cabinet
	breaker_switch.add_child(base_mesh)
	
	# Lever Handle
	switch_handle = MeshInstance3D.new()
	var h_mesh = BoxMesh.new()
	h_mesh.size = Vector3(0.08, 0.32, 0.08)
	switch_handle.mesh = h_mesh
	switch_handle.material_override = mat_lever_red
	switch_handle.position = Vector3(0, 0.12, 0.05)
	# Default UP position (Power ON)
	switch_handle.rotation_degrees = Vector3(25, 0, 0)
	breaker_switch.add_child(switch_handle)
	
	# Spark Particles
	breaker_spark_particles = CPUParticles3D.new()
	breaker_spark_particles.name = "SparkParticles"
	breaker_spark_particles.emitting = false
	breaker_spark_particles.amount = 32
	breaker_spark_particles.lifetime = 0.4
	breaker_spark_particles.one_shot = true
	breaker_spark_particles.explosiveness = 0.9
	breaker_spark_particles.direction = Vector3(0, 1, -1)
	breaker_spark_particles.spread = 45.0
	breaker_spark_particles.initial_velocity_min = 3.5
	breaker_spark_particles.initial_velocity_max = 6.0
	breaker_spark_particles.gravity = Vector3(0, -9.8, 0)
	breaker_spark_particles.color = Color(1.0, 0.9, 0.3)
	breaker_spark_particles.position = Vector3(0, 0.0, 0.18)
	breaker_switch.add_child(breaker_spark_particles)
	
	# Interaction Area around the panel
	var panel_area = Area3D.new()
	panel_area.name = "BreakerArea"
	panel_area.add_to_group("power_panel_area")
	var a_col = CollisionShape3D.new()
	var a_box = BoxShape3D.new()
	a_box.size = Vector3(2.5, 2.5, 2.5)
	a_col.shape = BoxShape3D.new()
	a_col.shape.size = a_box.size
	a_col.position = Vector3(0, 0, 0.6)
	panel_area.add_child(a_col)
	panel_body.add_child(panel_area)
	
	panel_area.body_entered.connect(_on_player_entered_panel)
	panel_area.body_exited.connect(_on_player_exited_panel)
	
	panel_body.rotation.y = PI
	panel_body.position = Vector3(0, 1.6, 5.80)
	add_child(panel_body)

var player_near_panel: bool = false

func _on_player_entered_panel(body: Node) -> void:
	if body.is_in_group("player"):
		player_near_panel = true
		_update_panel_prompt()

func _on_player_exited_panel(body: Node) -> void:
	if body.is_in_group("player"):
		player_near_panel = false
		var main_node = get_node_or_null("/root/Main")
		if main_node and "desk_prompt" in main_node and main_node.desk_prompt:
			if "PANO" in main_node.desk_prompt.text or "Şalter" in main_node.desk_prompt.text:
				main_node.desk_prompt.visible = false

func _update_panel_prompt() -> void:
	if not player_near_panel: return
	var main_node = get_node_or_null("/root/Main")
	if main_node and "desk_prompt" in main_node and main_node.desk_prompt:
		if not is_power_active:
			main_node.desk_prompt.text = "[E] Şalteri Kaldır & Şebekeyi Başlat (+500 Coin)"
			main_node.desk_prompt.visible = true
		else:
			main_node.desk_prompt.text = "Elektrik Panosu [Şebeke Normal]"
			main_node.desk_prompt.visible = true

func set_blackout_state(power_active: bool) -> void:
	is_power_active = power_active
	if not power_active:
		# Power outage: switch trips down, red emergency beacon
		if switch_handle:
			var tw = create_tween()
			tw.tween_property(switch_handle, "rotation_degrees:x", -35.0, 0.25).set_trans(Tween.TRANS_BOUNCE)
		if panel_status_light:
			var mat_red = _create_pbr_mat(Color(0.1, 0.1, 0.1), 0.2, 0.0, Color(1.0, 0.1, 0.1), 3.5)
			panel_status_light.material_override = mat_red
		if panel_status_label:
			panel_status_label.text = "ŞEBEKE: DEVRE DIŞI!"
			panel_status_label.modulate = Color(1.0, 0.2, 0.2)
		if emergency_light:
			emergency_light.light_color = Color(1.0, 0.15, 0.1)
			emergency_light.light_energy = 0.8
	else:
		# Power restored: switch flips up, green status
		if switch_handle:
			var tw = create_tween()
			tw.tween_property(switch_handle, "rotation_degrees:x", 25.0, 0.25).set_trans(Tween.TRANS_BACK)
		if panel_status_light:
			var mat_green = _create_pbr_mat(Color(0.1, 0.1, 0.1), 0.2, 0.0, Color(0.15, 0.95, 0.35), 3.5)
			panel_status_light.material_override = mat_green
		if panel_status_label:
			panel_status_label.text = "ŞEBEKE: AKTİF"
			panel_status_label.modulate = Color(0.2, 0.95, 0.4)
		if emergency_light:
			emergency_light.light_color = Color(0.3, 0.7, 1.0)
			emergency_light.light_energy = 0.3
			
	_update_panel_prompt()

func trigger_restore_switch() -> void:
	if is_power_active:
		return
	preload("res://src/environment/interaction_feedback.gd").sound(breaker_switch, "switch")
	if breaker_spark_particles:
		breaker_spark_particles.restart()
		breaker_spark_particles.emitting = true
	set_blackout_state(true)
	power_restored.emit()
