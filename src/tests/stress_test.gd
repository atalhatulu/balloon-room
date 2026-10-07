extends Node3D

# Stress Test Scene for Balloon Room
# Tests Static Balloons, Dynamic/Moving Balloons, Physics sleeping and Rendering Draw Calls

@export var balloon_scene: PackedScene = preload("res://src/entities/balloon.tscn")

var balloon_container: Node3D = null
var is_moving_mode: bool = true
var target_balloon_count: int = 250

# Telemetry
var fps_label: Label = null
var stats_label: Label = null
var mode_label: Label = null
var instructions_label: Label = null

var camera: Camera3D = null
var camera_pivot: Node3D = null
var cam_rot_speed: float = 0.35
var cam_auto_rotate: bool = true

var fps_history: Array[float] = []
var min_fps: float = 999.0
var max_fps: float = 0.0

func _ready() -> void:
	_setup_environment()
	_setup_camera()
	_setup_ui()
	
	balloon_container = Node3D.new()
	balloon_container.name = "TestBalloonContainer"
	add_child(balloon_container)
	
	_spawn_balloons(target_balloon_count)

func _setup_environment() -> void:
	# WorldEnvironment
	var env = Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.08, 0.10, 0.14)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.7, 0.75, 0.85)
	env.ambient_light_energy = 1.0
	
	var world_env = WorldEnvironment.new()
	world_env.environment = env
	add_child(world_env)
	
	# Sunlight / Key light
	var dir_light = DirectionalLight3D.new()
	dir_light.rotation_degrees = Vector3(-45, 45, 0)
	dir_light.light_color = Color(1.0, 0.95, 0.90)
	dir_light.light_energy = 1.2
	dir_light.shadow_enabled = false # Keep pure mesh & physics stress test
	add_child(dir_light)
	
	# Test Arena Box (30x30m floor, 15m walls)
	_create_arena_bounds()

func _create_arena_bounds() -> void:
	var arena = Node3D.new()
	arena.name = "Arena"
	add_child(arena)
	
	# Floor
	var floor_body = StaticBody3D.new()
	floor_body.collision_layer = 1
	floor_body.collision_mask = 2
	var floor_shape = CollisionShape3D.new()
	var box = BoxShape3D.new()
	box.size = Vector3(36, 1, 36)
	floor_shape.shape = box
	floor_shape.position = Vector3(0, -0.5, 0)
	floor_body.add_child(floor_shape)
	
	var floor_mesh = MeshInstance3D.new()
	var pmesh = PlaneMesh.new()
	pmesh.size = Vector2(36, 36)
	floor_mesh.mesh = pmesh
	var mat = StandardMaterial3D.new()
	mat.albedo_color = Color(0.12, 0.15, 0.20)
	mat.roughness = 0.8
	floor_mesh.material_override = mat
	floor_body.add_child(floor_mesh)
	arena.add_child(floor_body)
	
	# Glass/Border Walls so moving balloons stay in view
	var wall_configs = [
		{"pos": Vector3(0, 7.5, -18), "size": Vector3(36, 15, 1)},
		{"pos": Vector3(0, 7.5, 18), "size": Vector3(36, 15, 1)},
		{"pos": Vector3(-18, 7.5, 0), "size": Vector3(1, 15, 36)},
		{"pos": Vector3(18, 7.5, 0), "size": Vector3(1, 15, 36)},
		{"pos": Vector3(0, 15.5, 0), "size": Vector3(36, 1, 36)} # Ceiling
	]
	
	for cfg in wall_configs:
		var wall = StaticBody3D.new()
		wall.collision_layer = 1
		wall.collision_mask = 2
		var col = CollisionShape3D.new()
		var w_box = BoxShape3D.new()
		w_box.size = cfg["size"]
		col.shape = w_box
		col.position = cfg["pos"]
		wall.add_child(col)
		arena.add_child(wall)

func _setup_camera() -> void:
	camera_pivot = Node3D.new()
	camera_pivot.name = "CameraPivot"
	camera_pivot.position = Vector3(0, 5, 0)
	add_child(camera_pivot)
	
	camera = Camera3D.new()
	camera.position = Vector3(0, 8, 22)
	camera.rotation_degrees = Vector3(-20, 0, 0)
	camera.fov = 72.0
	camera_pivot.add_child(camera)

func _setup_ui() -> void:
	var canvas = CanvasLayer.new()
	add_child(canvas)
	
	var panel = PanelContainer.new()
	panel.anchor_left = 0.0
	panel.anchor_top = 0.0
	panel.offset_left = 20
	panel.offset_top = 20
	panel.offset_right = 380
	panel.offset_bottom = 240
	
	var style = StyleBoxFlat.new()
	style.bg_color = Color(0.05, 0.07, 0.12, 0.90)
	style.border_color = Color(0.2, 0.7, 0.9, 0.8)
	style.set_border_width_all(2)
	style.set_corner_radius_all(8)
	style.content_margin_left = 14
	style.content_margin_right = 14
	style.content_margin_top = 10
	style.content_margin_bottom = 10
	panel.add_theme_stylebox_override("panel", style)
	canvas.add_child(panel)
	
	var vbox = VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 6)
	panel.add_child(vbox)
	
	var title = Label.new()
	title.text = "⚡ BALON STRES & PERFORMANS TESTİ"
	title.add_theme_font_size_override("font_size", 15)
	title.add_theme_color_override("font_color", Color(0.3, 0.9, 1.0))
	vbox.add_child(title)
	
	fps_label = Label.new()
	fps_label.text = "FPS: --"
	fps_label.add_theme_font_size_override("font_size", 18)
	fps_label.add_theme_color_override("font_color", Color(0.2, 1.0, 0.4))
	vbox.add_child(fps_label)
	
	stats_label = Label.new()
	stats_label.text = "Aktif Balon: 0 | Fizik Süresi: -- ms"
	stats_label.add_theme_font_size_override("font_size", 13)
	stats_label.add_theme_color_override("font_color", Color(0.85, 0.9, 0.95))
	vbox.add_child(stats_label)
	
	mode_label = Label.new()
	mode_label.text = "Mod: [HAREKETLİ (DİNAMİK FİZİK)]"
	mode_label.add_theme_font_size_override("font_size", 13)
	mode_label.add_theme_color_override("font_color", Color(1.0, 0.8, 0.2))
	vbox.add_child(mode_label)
	
	var sep = HSeparator.new()
	vbox.add_child(sep)
	
	instructions_label = Label.new()
	instructions_label.text = "[M] Mod Değiştir (Sabit / Dinamik)\n[1] 250  |  [2] 500  |  [3] 1000  |  [4] 1500  |  [5] 2000 Balon\n[+] / [-] (+100 / -100 Balon)\n[Boşluk] Kamera Döndürme\n[R] Hızlandır / Karıştır\n[ESC] Ana Sahneye Dön"
	instructions_label.add_theme_font_size_override("font_size", 12)
	instructions_label.add_theme_color_override("font_color", Color(0.65, 0.75, 0.85))
	vbox.add_child(instructions_label)

func _process(delta: float) -> void:
	var cur_fps = Engine.get_frames_per_second()
	min_fps = minf(min_fps, cur_fps)
	max_fps = maxf(max_fps, cur_fps)
	
	fps_label.text = "FPS: %d (Min: %d | Max: %d)" % [cur_fps, int(min_fps), int(max_fps)]
	if cur_fps >= 100:
		fps_label.add_theme_color_override("font_color", Color(0.2, 1.0, 0.4))
	elif cur_fps >= 60:
		fps_label.add_theme_color_override("font_color", Color(0.3, 0.8, 1.0))
	elif cur_fps >= 30:
		fps_label.add_theme_color_override("font_color", Color(1.0, 0.75, 0.2))
	else:
		fps_label.add_theme_color_override("font_color", Color(1.0, 0.3, 0.3))
		
	var active_physical = balloon_container.get_child_count() if balloon_container else 0
	var total_tier_balloons := 0
	var sleeping_tier_balloons := 0
	var phys_time = Performance.get_monitor(Performance.TIME_PHYSICS_PROCESS) * 1000.0
	
	if balloon_container:
		for b in balloon_container.get_children():
			if b is RigidBody3D and not b.is_queued_for_deletion():
				var val: int = b.get("tier_value") if ("tier_value" in b) else 1
				total_tier_balloons += val
				if b.sleeping:
					sleeping_tier_balloons += val
					
	stats_label.text = "Toplam Balon Değeri: %d (Fiziksel Gövde: %d) | Uyuyan: %d (%d%%) | Fizik: %.2f ms" % [
		total_tier_balloons,
		active_physical,
		sleeping_tier_balloons,
		int(float(sleeping_tier_balloons) / float(maxi(1, total_tier_balloons)) * 100.0),
		phys_time
	]
	
	if cam_auto_rotate and camera_pivot:
		camera_pivot.rotate_y(cam_rot_speed * delta)

func _input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.is_echo():
		match event.keycode:
			KEY_M:
				_toggle_physics_mode()
			KEY_EQUAL, KEY_KP_ADD:
				_change_target_count(target_balloon_count + 100)
			KEY_MINUS, KEY_KP_SUBTRACT:
				_change_target_count(maxi(50, target_balloon_count - 100))
			KEY_1:
				_change_target_count(250)
			KEY_2:
				_change_target_count(500)
			KEY_3:
				_change_target_count(1000)
			KEY_4:
				_change_target_count(1500)
			KEY_5:
				_change_target_count(2000)
			KEY_SPACE:
				cam_auto_rotate = not cam_auto_rotate
			KEY_R:
				_re_energize_balloons()
			KEY_ESCAPE:
				get_tree().change_scene_to_file("res://scenes/main.tscn")

func _toggle_physics_mode() -> void:
	is_moving_mode = not is_moving_mode
	if is_moving_mode:
		mode_label.text = "Mod: [HAREKETLİ (DİNAMİK FİZİK)]"
		mode_label.add_theme_color_override("font_color", Color(1.0, 0.8, 0.2))
		_apply_dynamic_physics()
	else:
		mode_label.text = "Mod: [SABİT (STATİK / DONDURULMUŞ)]"
		mode_label.add_theme_color_override("font_color", Color(0.3, 0.9, 1.0))
		_apply_static_physics()
	min_fps = 999.0
	max_fps = 0.0

func _apply_static_physics() -> void:
	if not balloon_container: return
	for b in balloon_container.get_children():
		if b is RigidBody3D:
			b.freeze = true
			b.linear_velocity = Vector3.ZERO
			b.angular_velocity = Vector3.ZERO

func _apply_dynamic_physics() -> void:
	if not balloon_container: return
	for b in balloon_container.get_children():
		if b is RigidBody3D:
			b.freeze = false
			b.sleeping = false
			b.linear_velocity = Vector3(randf_range(-3.5, 3.5), randf_range(0.5, 4.5), randf_range(-3.5, 3.5))
			b.angular_velocity = Vector3(randf_range(-2, 2), randf_range(-2, 2), randf_range(-2, 2))

func _re_energize_balloons() -> void:
	min_fps = 999.0
	max_fps = 0.0
	_apply_dynamic_physics()

func _change_target_count(new_count: int) -> void:
	target_balloon_count = new_count
	min_fps = 999.0
	max_fps = 0.0
	_spawn_balloons(target_balloon_count)

func _spawn_balloons(count: int) -> void:
	if not balloon_scene or not balloon_container: return
	
	# Clear existing
	for c in balloon_container.get_children():
		c.queue_free()
		
	var tiers = [1, 1, 1, 5, 5, 10]
	var specials = ["normal", "normal", "normal", "bomb", "air", "gold"]
	
	for i in range(count):
		var b = balloon_scene.instantiate()
		var rand_x = randf_range(-14.0, 14.0)
		var rand_y = randf_range(1.5, 12.0)
		var rand_z = randf_range(-14.0, 14.0)
		b.position = Vector3(rand_x, rand_y, rand_z)
		
		balloon_container.add_child(b)
		
		var t = tiers[i % tiers.size()]
		var spec = specials[i % specials.size()]
		if b.has_method("setup_tier"):
			b.setup_tier(t)
		if spec != "normal" and b.has_method("setup_special_type"):
			b.setup_special_type(spec)
			
		if b is RigidBody3D:
			if is_moving_mode:
				b.freeze = false
				b.linear_velocity = Vector3(randf_range(-3.0, 3.0), randf_range(-1.0, 3.0), randf_range(-3.0, 3.0))
			else:
				b.freeze = true
				b.linear_velocity = Vector3.ZERO
