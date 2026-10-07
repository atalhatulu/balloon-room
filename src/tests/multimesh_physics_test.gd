extends Node3D

# Bağımsız MultiMesh + PhysicsServer3D Prototip Sahnesi
# Mevcut oyuna dokunmaz; saf sunucu ve GPU instancing performansını test eder.

const Design = preload("res://src/entities/collectible_design.gd")

var multimesh_instance: MultiMeshInstance3D = null
var multimesh: MultiMesh = null
var shape_rid: RID
var body_rids: Array[RID] = []
var active_count: int = 2000

var fps_label: Label = null
var stats_label: Label = null
var instructions_label: Label = null
var camera_pivot: Node3D = null
var cam_auto_rotate: bool = true
var min_fps: float = 999.0

# Çarpışma kutusu sınırları
const ARENA_EXTENTS = Vector3(18.0, 15.0, 18.0)

func _ready() -> void:
	_setup_environment()
	_setup_camera()
	_setup_ui()
	_setup_physics_server_arena()
	_setup_multimesh()
	_spawn_server_balloons(active_count)

func _setup_environment() -> void:
	var env = Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.06, 0.08, 0.12)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.75, 0.8, 0.9)
	env.ambient_light_energy = 1.0
	
	var we = WorldEnvironment.new()
	we.environment = env
	add_child(we)
	
	var light = DirectionalLight3D.new()
	light.rotation_degrees = Vector3(-50, 40, 0)
	light.light_color = Color(1.0, 0.96, 0.90)
	light.light_energy = 1.2
	add_child(light)

func _setup_camera() -> void:
	camera_pivot = Node3D.new()
	camera_pivot.position = Vector3(0, 5, 0)
	add_child(camera_pivot)
	
	var cam = Camera3D.new()
	cam.position = Vector3(0, 9, 25)
	cam.rotation_degrees = Vector3(-20, 0, 0)
	cam.fov = 70.0
	camera_pivot.add_child(cam)

func _setup_ui() -> void:
	var canvas = CanvasLayer.new()
	add_child(canvas)
	
	var panel = PanelContainer.new()
	panel.offset_left = 20
	panel.offset_top = 20
	panel.offset_right = 440
	panel.offset_bottom = 260
	
	var sb = StyleBoxFlat.new()
	sb.bg_color = Color(0.04, 0.06, 0.10, 0.92)
	sb.border_color = Color(0.3, 0.9, 0.7, 0.9)
	sb.set_border_width_all(2)
	sb.set_corner_radius_all(8)
	for s in ["left", "right", "top", "bottom"]: sb.set("content_margin_" + s, 12)
	panel.add_theme_stylebox_override("panel", sb)
	canvas.add_child(panel)
	
	var vbox = VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 6)
	panel.add_child(vbox)
	
	var title = Label.new()
	title.text = "⚡ SEÇENEK B: MULTIMESH + PHYSICSSERVER3D"
	title.add_theme_font_size_override("font_size", 14)
	title.add_theme_color_override("font_color", Color(0.3, 0.9, 0.7))
	vbox.add_child(title)
	
	fps_label = Label.new()
	fps_label.text = "FPS: --"
	fps_label.add_theme_font_size_override("font_size", 18)
	vbox.add_child(fps_label)
	
	stats_label = Label.new()
	stats_label.text = "Düğüm (Node): 0 | MultiMesh Instancing: 2000"
	stats_label.add_theme_font_size_override("font_size", 13)
	stats_label.add_theme_color_override("font_color", Color(0.85, 0.9, 0.95))
	vbox.add_child(stats_label)
	
	vbox.add_child(HSeparator.new())
	
	instructions_label = Label.new()
	instructions_label.text = "[1] 1.000  |  [2] 2.000  |  [3] 3.500  |  [4] 5.000 Balon\n[R] Balonları Havaya Fırlat\n[Boşluk] Kamera Döndürme\n[ESC] Ana Sahneye Dön"
	instructions_label.add_theme_font_size_override("font_size", 12)
	instructions_label.add_theme_color_override("font_color", Color(0.7, 0.8, 0.9))
	vbox.add_child(instructions_label)

func _setup_physics_server_arena() -> void:
	var space = get_world_3d().space
	
	# Zemin ve duvarları PhysicsServer üzerinden statik body olarak kur
	var floor_body = PhysicsServer3D.body_create()
	PhysicsServer3D.body_set_mode(floor_body, PhysicsServer3D.BODY_MODE_STATIC)
	PhysicsServer3D.body_set_space(floor_body, space)
	
	var floor_shape = PhysicsServer3D.box_shape_create()
	PhysicsServer3D.shape_set_data(floor_shape, Vector3(36, 1, 36))
	PhysicsServer3D.body_add_shape(floor_body, floor_shape, Transform3D(Basis(), Vector3(0, -0.5, 0)))
	
	# Görsel Zemin
	var floor_mesh = MeshInstance3D.new()
	var pm = PlaneMesh.new()
	pm.size = Vector2(36, 36)
	floor_mesh.mesh = pm
	var f_mat = StandardMaterial3D.new()
	f_mat.albedo_color = Color(0.10, 0.13, 0.18)
	floor_mesh.material_override = f_mat
	add_child(floor_mesh)
	
	# 4 Sınır Duvarı
	var wall_transforms = [
		Transform3D(Basis(), Vector3(0, 7.5, -18)),
		Transform3D(Basis(), Vector3(0, 7.5, 18)),
		Transform3D(Basis(), Vector3(-18, 7.5, 0)),
		Transform3D(Basis(), Vector3(18, 7.5, 0)),
		Transform3D(Basis(), Vector3(0, 15.5, 0))
	]
	var wall_sizes = [
		Vector3(36, 15, 1),
		Vector3(36, 15, 1),
		Vector3(1, 15, 36),
		Vector3(1, 15, 36),
		Vector3(36, 1, 36)
	]
	for i in range(wall_transforms.size()):
		var w_body = PhysicsServer3D.body_create()
		PhysicsServer3D.body_set_mode(w_body, PhysicsServer3D.BODY_MODE_STATIC)
		PhysicsServer3D.body_set_space(w_body, space)
		var w_shape = PhysicsServer3D.box_shape_create()
		PhysicsServer3D.shape_set_data(w_shape, wall_sizes[i])
		PhysicsServer3D.body_add_shape(w_body, w_shape, wall_transforms[i])

func _setup_multimesh() -> void:
	multimesh_instance = MultiMeshInstance3D.new()
	multimesh_instance.name = "BalloonMultiMesh"
	add_child(multimesh_instance)
	
	multimesh = MultiMesh.new()
	multimesh.transform_format = MultiMesh.TRANSFORM_3D
	multimesh.use_colors = true
	multimesh.mesh = Design.get_balloon_body()
	
	var mat = StandardMaterial3D.new()
	mat.vertex_color_use_as_albedo = true
	mat.roughness = 0.2
	mat.metallic_specular = 0.5
	mat.rim_enabled = true
	mat.rim = 0.5
	multimesh_instance.material_override = mat
	multimesh_instance.multimesh = multimesh
	
	# Küre şekli oluştur
	shape_rid = PhysicsServer3D.sphere_shape_create()
	PhysicsServer3D.shape_set_data(shape_rid, 0.42)

func _spawn_server_balloons(count: int) -> void:
	active_count = count
	_clear_bodies()
	
	multimesh.instance_count = count
	var space = get_world_3d().space
	
	var colors = [
		Color(0.95, 0.25, 0.25),
		Color(0.25, 0.65, 0.95),
		Color(0.35, 0.85, 0.35),
		Color(0.95, 0.80, 0.20),
		Color(0.85, 0.35, 0.85),
		Color(1.0, 0.55, 0.15)
	]
	
	for i in range(count):
		var body = PhysicsServer3D.body_create()
		PhysicsServer3D.body_set_mode(body, PhysicsServer3D.BODY_MODE_RIGID)
		PhysicsServer3D.body_set_space(body, space)
		PhysicsServer3D.body_add_shape(body, shape_rid)
		
		# Fiziksel balon özellikleri
		PhysicsServer3D.body_set_param(body, PhysicsServer3D.BODY_PARAM_MASS, 0.08)
		PhysicsServer3D.body_set_param(body, PhysicsServer3D.BODY_PARAM_GRAVITY_SCALE, 0.25)
		PhysicsServer3D.body_set_param(body, PhysicsServer3D.BODY_PARAM_LINEAR_DAMP, 1.8)
		PhysicsServer3D.body_set_param(body, PhysicsServer3D.BODY_PARAM_ANGULAR_DAMP, 3.6)
		PhysicsServer3D.body_set_param(body, PhysicsServer3D.BODY_PARAM_FRICTION, 0.35)
		PhysicsServer3D.body_set_param(body, PhysicsServer3D.BODY_PARAM_BOUNCE, 0.30)
		PhysicsServer3D.body_set_state(body, PhysicsServer3D.BODY_STATE_CAN_SLEEP, true)
		PhysicsServer3D.body_set_collision_layer(body, 2)
		PhysicsServer3D.body_set_collision_mask(body, 3)
		
		var init_pos = Vector3(
			randf_range(-14.0, 14.0),
			randf_range(2.0, 12.0),
			randf_range(-14.0, 14.0)
		)
		var t = Transform3D(Basis(), init_pos)
		PhysicsServer3D.body_set_state(body, PhysicsServer3D.BODY_STATE_TRANSFORM, t)
		PhysicsServer3D.body_set_state(body, PhysicsServer3D.BODY_STATE_LINEAR_VELOCITY, Vector3(
			randf_range(-2.0, 2.0),
			randf_range(0.0, 3.0),
			randf_range(-2.0, 2.0)
		))
		
		multimesh.set_instance_transform(i, t)
		multimesh.set_instance_color(i, colors[i % colors.size()])
		body_rids.append(body)

func _clear_bodies() -> void:
	for b in body_rids:
		PhysicsServer3D.free_rid(b)
	body_rids.clear()

func _physics_process(_delta: float) -> void:
	# C++ PhysicsServer'dan koordinatları alıp MultiMesh matrisine yaz
	# 0 Node gezinmesi, doğrudan bellek kopyalama!
	var sleeping_count := 0
	for i in range(body_rids.size()):
		var b = body_rids[i]
		var is_sleep = PhysicsServer3D.body_is_omitting_force_integration(b) or PhysicsServer3D.body_get_state(b, PhysicsServer3D.BODY_STATE_SLEEPING)
		if is_sleep:
			sleeping_count += 1
		var t = PhysicsServer3D.body_get_state(b, PhysicsServer3D.BODY_STATE_TRANSFORM)
		multimesh.set_instance_transform(i, t)
		
	var phys_ms = Performance.get_monitor(Performance.TIME_PHYSICS_PROCESS) * 1000.0
	stats_label.text = "Balon: %d (0 Node!) | Uyuyan: %d (%d%%) | Fizik: %.2f ms" % [
		active_count,
		sleeping_count,
		int(float(sleeping_count) / float(maxi(1, active_count)) * 100.0),
		phys_ms
	]

func _process(delta: float) -> void:
	var cur_fps = Engine.get_frames_per_second()
	min_fps = minf(min_fps, cur_fps)
	fps_label.text = "FPS: %d (Min: %d)" % [cur_fps, int(min_fps)]
	if cur_fps >= 58:
		fps_label.add_theme_color_override("font_color", Color(0.2, 1.0, 0.4))
	else:
		fps_label.add_theme_color_override("font_color", Color(1.0, 0.75, 0.2))
		
	if cam_auto_rotate and camera_pivot:
		camera_pivot.rotate_y(0.35 * delta)

func _input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.is_echo():
		match event.keycode:
			KEY_1:
				min_fps = 999.0
				_spawn_server_balloons(1000)
			KEY_2:
				min_fps = 999.0
				_spawn_server_balloons(2000)
			KEY_3:
				min_fps = 999.0
				_spawn_server_balloons(3500)
			KEY_4:
				min_fps = 999.0
				_spawn_server_balloons(5000)
			KEY_R:
				min_fps = 999.0
				_re_energize()
			KEY_SPACE:
				cam_auto_rotate = not cam_auto_rotate
			KEY_ESCAPE:
				get_tree().change_scene_to_file("res://scenes/main.tscn")

func _re_energize() -> void:
	for b in body_rids:
		PhysicsServer3D.body_set_state(b, PhysicsServer3D.BODY_STATE_SLEEPING, false)
		PhysicsServer3D.body_set_state(b, PhysicsServer3D.BODY_STATE_LINEAR_VELOCITY, Vector3(
			randf_range(-4.0, 4.0),
			randf_range(2.0, 6.0),
			randf_range(-4.0, 4.0)
		))

func _exit_tree() -> void:
	_clear_bodies()
	if shape_rid.is_valid():
		PhysicsServer3D.free_rid(shape_rid)
