class_name ExitDoor
extends Node3D

signal door_opened()

var is_locked: bool = true
var is_open: bool = false

var left_panel: Node3D = null
var right_panel: Node3D = null
var lock_light: MeshInstance3D = null
var lock_label: Label3D = null
var exit_sign: Node3D = null

var lp_col: CollisionShape3D = null
var rp_col: CollisionShape3D = null
var _door_tween: Tween = null
var _door_moving := false

func _ready() -> void:
	name = "ExitDoor"
	_build_door_structure()

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

func _build_door_structure() -> void:
	var mat_frame = _create_pbr_mat(Color(0.15, 0.17, 0.19), 0.5, 0.6)
	var mat_orange_door = _create_pbr_mat(Color(0.90, 0.42, 0.08), 0.32, 0.35)
	var mat_trim_black = _create_pbr_mat(Color(0.08, 0.09, 0.10), 0.6, 0.2)
	var mat_handle_chrome = _create_pbr_mat(Color(0.85, 0.88, 0.90), 0.12, 0.95)
	var mat_sign_housing = _create_pbr_mat(Color(0.12, 0.14, 0.16), 0.3, 0.5)
	var mat_sign_glow = _create_pbr_mat(Color(0.15, 0.95, 0.40), 0.1, 0.0, Color(0.15, 0.95, 0.40), 3.5)
	var mat_lock_red = _create_pbr_mat(Color(0.1, 0.1, 0.1), 0.2, 0.0, Color(1.0, 0.15, 0.15), 3.2)
	
	# 1. Heavy Outer Steel Frame (Hollow doorway: left post, right post, top lintel)
	# Frame is static environment (collision_layer = 1)
	var frame = StaticBody3D.new()
	frame.name = "Frame"
	frame.collision_layer = 1
	frame.collision_mask = 0
	add_child(frame)
	
	# Top Lintel (W: 2.5m, H: 0.35m, D: 0.26m)
	var lintel_mesh = MeshInstance3D.new()
	var l_box = BoxMesh.new()
	l_box.size = Vector3(2.5, 0.35, 0.26)
	lintel_mesh.mesh = l_box
	lintel_mesh.material_override = mat_frame
	lintel_mesh.position = Vector3(0, 2.975, 0)
	frame.add_child(lintel_mesh)
	
	var l_col = CollisionShape3D.new()
	var l_shape = BoxShape3D.new()
	l_shape.size = Vector3(2.5, 0.35, 0.26)
	l_col.shape = l_shape
	l_col.position = Vector3(0, 2.975, 0)
	frame.add_child(l_col)
	
	# Left Post (W: 0.22m, H: 2.8m, D: 0.26m)
	var post_mesh_l = MeshInstance3D.new()
	var p_post_box = BoxMesh.new()
	p_post_box.size = Vector3(0.22, 2.80, 0.26)
	post_mesh_l.mesh = p_post_box
	post_mesh_l.material_override = mat_frame
	post_mesh_l.position = Vector3(-1.14, 1.40, 0)
	frame.add_child(post_mesh_l)
	
	var post_col_l = CollisionShape3D.new()
	var post_shape = BoxShape3D.new()
	post_shape.size = Vector3(0.22, 2.80, 0.26)
	post_col_l.shape = post_shape
	post_col_l.position = Vector3(-1.14, 1.40, 0)
	frame.add_child(post_col_l)
	
	# Right Post (W: 0.22m, H: 2.8m, D: 0.26m)
	var post_mesh_r = MeshInstance3D.new()
	post_mesh_r.mesh = p_post_box
	post_mesh_r.material_override = mat_frame
	post_mesh_r.position = Vector3(1.14, 1.40, 0)
	frame.add_child(post_mesh_r)
	
	var post_col_r = CollisionShape3D.new()
	post_col_r.shape = post_shape
	post_col_r.position = Vector3(1.14, 1.40, 0)
	frame.add_child(post_col_r)
	
	# 2. Glowing EXIT Signboard above the door
	exit_sign = Node3D.new()
	exit_sign.name = "ExitSign"
	exit_sign.position = Vector3(0, 3.40, 0.08)
	add_child(exit_sign)
	
	var sign_box = MeshInstance3D.new()
	var sb_mesh = BoxMesh.new()
	sb_mesh.size = Vector3(1.10, 0.36, 0.14)
	sign_box.mesh = sb_mesh
	sign_box.material_override = mat_sign_housing
	exit_sign.add_child(sign_box)
	
	var sign_face = MeshInstance3D.new()
	var sf_mesh = BoxMesh.new()
	sf_mesh.size = Vector3(1.02, 0.30, 0.04)
	sign_face.mesh = sf_mesh
	sign_face.material_override = mat_sign_glow
	sign_face.position = Vector3(0, 0, 0.07)
	exit_sign.add_child(sign_face)
	
	var sign_label = Label3D.new()
	sign_label.text = "JENERATÖR"
	sign_label.font_size = 22
	sign_label.modulate = Color(0.05, 0.15, 0.08)
	sign_label.outline_size = 12
	sign_label.outline_modulate = Color(0.15, 0.95, 0.40)
	sign_label.pixel_size = 0.0038
	sign_label.position = Vector3(0, 0, 0.10)
	exit_sign.add_child(sign_label)
	
	# 3. Twin Orange Sliding Security Door Panels (AnimatableBody3D with sync_to_physics)
	var panels_root = Node3D.new()
	panels_root.name = "Panels"
	add_child(panels_root)
	
	# Left Door Panel (W: 1.05m, H: 2.76m, D: 0.10m)
	var lp_body = AnimatableBody3D.new()
	lp_body.name = "LeftPanel"
	# The door is positioned with its parent during each room rebuild. Let the
	# physics server follow that parent transform so the panels stay in the
	# doorway instead of retaining their startup world position.
	lp_body.sync_to_physics = false
	lp_body.collision_layer = 1
	lp_body.collision_mask = 0
	lp_body.position = Vector3(-0.55, 1.40, 0.0)
	panels_root.add_child(lp_body)
	left_panel = lp_body
	
	var lp_mesh = MeshInstance3D.new()
	var p_box = BoxMesh.new()
	p_box.size = Vector3(1.05, 2.76, 0.10)
	lp_mesh.mesh = p_box
	lp_mesh.material_override = mat_orange_door
	left_panel.add_child(lp_mesh)
	
	var p_shape = BoxShape3D.new()
	p_shape.size = Vector3(1.05, 2.76, 0.10)
	lp_col = CollisionShape3D.new()
	lp_col.shape = p_shape
	left_panel.add_child(lp_col)
	
	# Black rubber perimeter seal
	var lp_trim = MeshInstance3D.new()
	var tr_box = BoxMesh.new()
	tr_box.size = Vector3(1.07, 0.06, 0.11)
	lp_trim.mesh = tr_box
	lp_trim.material_override = mat_trim_black
	lp_trim.position = Vector3(0, 1.35, 0)
	left_panel.add_child(lp_trim)
	
	# Chrome handle
	var lp_handle = MeshInstance3D.new()
	var h_cyl = CylinderMesh.new()
	h_cyl.top_radius = 0.025
	h_cyl.bottom_radius = 0.025
	h_cyl.height = 0.65
	lp_handle.mesh = h_cyl
	lp_handle.material_override = mat_handle_chrome
	lp_handle.position = Vector3(0.40, 0, 0.08)
	left_panel.add_child(lp_handle)
	
	# Right Door Panel
	var rp_body = AnimatableBody3D.new()
	rp_body.name = "RightPanel"
	rp_body.sync_to_physics = false
	rp_body.collision_layer = 1
	rp_body.collision_mask = 0
	rp_body.position = Vector3(0.55, 1.40, 0.0)
	panels_root.add_child(rp_body)
	right_panel = rp_body
	
	var rp_mesh = MeshInstance3D.new()
	rp_mesh.mesh = p_box
	rp_mesh.material_override = mat_orange_door
	right_panel.add_child(rp_mesh)
	
	rp_col = CollisionShape3D.new()
	rp_col.shape = p_shape
	right_panel.add_child(rp_col)
	
	var rp_trim = MeshInstance3D.new()
	rp_trim.mesh = tr_box
	rp_trim.material_override = mat_trim_black
	rp_trim.position = Vector3(0, 1.35, 0)
	right_panel.add_child(rp_trim)
	
	var rp_handle = MeshInstance3D.new()
	rp_handle.mesh = h_cyl
	rp_handle.material_override = mat_handle_chrome
	rp_handle.position = Vector3(-0.40, 0, 0.08)
	right_panel.add_child(rp_handle)
	
	# 4. Electronic Keycard Security Status Lock
	var lock_box = Node3D.new()
	lock_box.position = Vector3(1.45, 1.40, 0.14)
	add_child(lock_box)
	
	var lb_mesh = MeshInstance3D.new()
	var l_mesh = BoxMesh.new()
	l_mesh.size = Vector3(0.24, 0.38, 0.08)
	lb_mesh.mesh = l_mesh
	lb_mesh.material_override = mat_sign_housing
	lock_box.add_child(lb_mesh)
	
	lock_light = MeshInstance3D.new()
	var led_cyl = CylinderMesh.new()
	led_cyl.top_radius = 0.04
	led_cyl.bottom_radius = 0.04
	led_cyl.height = 0.02
	lock_light.mesh = led_cyl
	lock_light.material_override = mat_lock_red
	lock_light.rotation_degrees = Vector3(90, 0, 0)
	lock_light.position = Vector3(0, 0.10, 0.045)
	lock_box.add_child(lock_light)
	
	lock_label = Label3D.new()
	lock_label.text = "KAPALI"
	lock_label.font_size = 28
	lock_label.modulate = Color(1.0, 0.25, 0.25)
	lock_label.pixel_size = 0.003
	lock_label.position = Vector3(0, -0.06, 0.05)
	lock_box.add_child(lock_label)
	
	# 5. Proximity interaction area for opening / closing the door
	var area = Area3D.new()
	area.name = "ProximityArea"
	area.collision_layer = 0
	area.collision_mask = 1 # Player layer
	var a_col = CollisionShape3D.new()
	var a_box = BoxShape3D.new()
	a_box.size = Vector3(3.2, 2.8, 3.2)
	a_col.shape = a_box
	a_col.position = Vector3(0, 1.25, 0.2)
	area.add_child(a_col)
	add_child(area)
	
	area.body_entered.connect(_on_player_entered_area)
	area.body_exited.connect(_on_player_exited_area)

var player_near_door: bool = false

func _on_player_entered_area(body: Node) -> void:
	if body.is_in_group("player"):
		player_near_door = true
		_update_door_prompt()

func _on_player_exited_area(body: Node) -> void:
	if body.is_in_group("player"):
		player_near_door = false
		var main_node = get_node_or_null("/root/Main")
		if main_node and "desk_prompt" in main_node and main_node.desk_prompt:
			if "KAPI" in main_node.desk_prompt.text or "Kapı" in main_node.desk_prompt.text:
				main_node.desk_prompt.visible = false

func _update_door_prompt() -> void:
	if not player_near_door: return
	var main_node = get_node_or_null("/root/Main")
	if main_node and "desk_prompt" in main_node and main_node.desk_prompt:
		if is_open:
			main_node.desk_prompt.text = "[E] Jeneratör Odası Kapısını Kapat"
		else:
			main_node.desk_prompt.text = "[E] Jeneratör Odası Kapısını Aç"
		main_node.desk_prompt.visible = true

func toggle_door() -> void:
	if _door_moving: return
	if is_open:
		close_door()
	else:
		open_door()

func open_door() -> void:
	if is_open:
		return
	is_locked = false
	is_open = true
	_door_moving = true
	preload("res://src/environment/interaction_feedback.gd").sound(self, "door")
	
	# Turn status light to green
	if lock_light:
		var mat_lock_green = _create_pbr_mat(Color(0.1, 0.1, 0.1), 0.2, 0.0, Color(0.1, 1.0, 0.3), 3.5)
		lock_light.material_override = mat_lock_green
	if lock_label:
		lock_label.text = "AÇIK"
		lock_label.modulate = Color(0.2, 1.0, 0.4)
		
	if _door_tween and _door_tween.is_valid():
		_door_tween.kill()
		
	# Slide orange panels open smoothly sideways
	if left_panel and right_panel:
		_door_tween = create_tween()
		_door_tween.set_parallel(true)
		_door_tween.tween_property(left_panel, "position:x", -1.65, 0.65).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN_OUT)
		_door_tween.tween_property(right_panel, "position:x", 1.65, 0.65).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN_OUT)
		# When fully open, temporarily disable collision shapes so player walks through smoothly without any stutter
		_door_tween.chain().tween_callback(func():
			_door_moving = false
			preload("res://src/environment/interaction_feedback.gd").sound(self, "button")
			if is_open:
				if lp_col: lp_col.disabled = true
				if rp_col: rp_col.disabled = true
		)
		
	door_opened.emit()
	_update_door_prompt()

func close_door() -> void:
	if not is_open or _door_moving:
		return
	var player = get_tree().get_first_node_in_group("player")
	if player:
		var offset: Vector3 = to_local(player.global_position)
		if absf(offset.x) < 1.6 and absf(offset.z) < 0.8:
			preload("res://src/environment/interaction_feedback.gd").sound(self, "denied")
			return
	_door_moving = true
	preload("res://src/environment/interaction_feedback.gd").sound(self, "door")
	is_open = false
	
	# Immediately re-enable collision before sliding shut
	if lp_col: lp_col.disabled = false
	if rp_col: rp_col.disabled = false
	
	if lock_light:
		var mat_lock_red = _create_pbr_mat(Color(0.1, 0.1, 0.1), 0.2, 0.0, Color(1.0, 0.15, 0.15), 3.2)
		lock_light.material_override = mat_lock_red
	if lock_label:
		lock_label.text = "KAPALI"
		lock_label.modulate = Color(1.0, 0.4, 0.4)
		
	if _door_tween and _door_tween.is_valid():
		_door_tween.kill()
		
	if left_panel and right_panel:
		_door_tween = create_tween()
		_door_tween.set_parallel(true)
		_door_tween.tween_property(left_panel, "position:x", -0.55, 0.55).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
		_door_tween.tween_property(right_panel, "position:x", 0.55, 0.55).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
		
	if _door_tween:
		_door_tween.chain().tween_callback(func():
			_door_moving = false
			preload("res://src/environment/interaction_feedback.gd").sound(self, "button")
		)
	_update_door_prompt()
