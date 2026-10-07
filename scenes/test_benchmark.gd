extends Node3D

# Benchmark & Stress Test Controller
# Tests Jolt Physics 3D scalability with high balloon volumes

@export var balloon_scene: PackedScene = preload("res://src/entities/balloon.tscn")

@onready var balloon_container: Node3D = $BalloonContainer
@onready var spectator_cam: Camera3D = $Spectator/Camera3D
@onready var spectator_node: Node3D = $Spectator

# HUD Elements
@onready var lbl_fps: Label = $UI/Panel/VBox/FPSLabel
@onready var lbl_balloon_count: Label = $UI/Panel/VBox/CountLabel
@onready var lbl_physics_time: Label = $UI/Panel/VBox/PhysicsTimeLabel
@onready var lbl_active_bodies: Label = $UI/Panel/VBox/ActiveBodiesLabel
@onready var lbl_draw_calls: Label = $UI/Panel/VBox/DrawCallsLabel
@onready var lbl_memory: Label = $UI/Panel/VBox/MemoryLabel
@onready var lbl_gravity_mode: Label = $UI/Panel/VBox/GravityLabel

# Spectator Movement Variables
var move_speed: float = 14.0
var mouse_sensitivity: float = 0.0025
var cam_rot_x: float = 0.0
var cam_rot_y: float = 0.0
var mouse_captured: bool = true

# Gravity Settings
var gravity_presets: Array[float] = [0.10, 0.25, 0.80, 1.80, 3.50]
var current_gravity_idx: int = 1

# Performance update throttle
var stats_timer: float = 0.0

# Raycast query for mouse-click pop
var _ray_query: PhysicsRayQueryParameters3D = null

func _ready() -> void:
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	mouse_captured = true
	_ray_query = PhysicsRayQueryParameters3D.new()
	_ray_query.collide_with_areas = false
	_ray_query.collide_with_bodies = true
	_ray_query.collision_mask = 2 # Balloons layer
	
	_connect_ui_buttons()
	_update_gravity_label()
	
	# Spawn initial batch of 200 balloons to begin benchmark
	spawn_balloons_grid(200)

func _connect_ui_buttons() -> void:
	var btn_100 = get_node_or_null("UI/Panel/VBox/HBoxSpawn/Btn100")
	if btn_100: btn_100.pressed.connect(func(): spawn_balloons_grid(100))
	
	var btn_500 = get_node_or_null("UI/Panel/VBox/HBoxSpawn/Btn500")
	if btn_500: btn_500.pressed.connect(func(): spawn_balloons_grid(500))
	
	var btn_1000 = get_node_or_null("UI/Panel/VBox/HBoxSpawn/Btn1000")
	if btn_1000: btn_1000.pressed.connect(func(): spawn_balloons_grid(1000))
	
	var btn_pop50 = get_node_or_null("UI/Panel/VBox/HBoxActions/BtnPop50")
	if btn_pop50: btn_pop50.pressed.connect(burst_pop_random)
	
	var btn_grav = get_node_or_null("UI/Panel/VBox/HBoxActions/BtnGravity")
	if btn_grav: btn_grav.pressed.connect(cycle_gravity)
	
	var btn_clear = get_node_or_null("UI/Panel/VBox/HBoxActions/BtnClear")
	if btn_clear: btn_clear.pressed.connect(clear_all_balloons)
	
	var btn_main = get_node_or_null("UI/Panel/VBox/BtnBackToMain")
	if btn_main: btn_main.pressed.connect(return_to_main_game)

func _input(event: InputEvent) -> void:
	# Mouse Look
	if event is InputEventMouseMotion and mouse_captured:
		cam_rot_y -= event.relative.x * mouse_sensitivity
		cam_rot_x = clamp(cam_rot_x - event.relative.y * mouse_sensitivity, -1.4, 1.4)
		spectator_node.rotation.y = cam_rot_y
		spectator_cam.rotation.x = cam_rot_x
		
	# Mouse Capture Toggle
	if event is InputEventKey and event.pressed:
		if event.keycode == KEY_TAB or event.keycode == KEY_ESCAPE:
			toggle_mouse_mode()
		elif event.keycode == KEY_1:
			spawn_balloons_grid(100)
		elif event.keycode == KEY_2:
			spawn_balloons_grid(500)
		elif event.keycode == KEY_3:
			spawn_balloons_grid(1000)
		elif event.keycode == KEY_C:
			clear_all_balloons()
		elif event.keycode == KEY_P:
			burst_pop_random()
		elif event.keycode == KEY_G:
			cycle_gravity()
		elif event.keycode == KEY_M:
			return_to_main_game()
			
	# Click to Pop Balloon under crosshair
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		if mouse_captured:
			_pop_balloon_at_crosshair()

func toggle_mouse_mode() -> void:
	mouse_captured = not mouse_captured
	if mouse_captured:
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	else:
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE

func _process(delta: float) -> void:
	# Spectator Movement
	_handle_spectator_movement(delta)
	
	# Update Diagnostics HUD & Pile Optimization
	stats_timer += delta
	if stats_timer >= 0.15:
		stats_timer = 0.0
		_update_diagnostics()
		_update_pile_optimization()

func _handle_spectator_movement(delta: float) -> void:
	if not mouse_captured:
		return
		
	var input_dir = Vector3.ZERO
	if Input.is_key_pressed(KEY_W): input_dir.z -= 1.0
	if Input.is_key_pressed(KEY_S): input_dir.z += 1.0
	if Input.is_key_pressed(KEY_A): input_dir.x -= 1.0
	if Input.is_key_pressed(KEY_D): input_dir.x += 1.0
	if Input.is_key_pressed(KEY_SPACE): input_dir.y += 1.0
	if Input.is_key_pressed(KEY_CTRL) or Input.is_key_pressed(KEY_SHIFT): input_dir.y -= 1.0
	
	if input_dir.length_squared() > 0.0:
		input_dir = input_dir.normalized()
		var speed = move_speed
		if Input.is_key_pressed(KEY_SHIFT) and not Input.is_key_pressed(KEY_CTRL):
			speed *= 2.2 # Sprint
			
		var forward = -spectator_cam.global_transform.basis.z
		var right = spectator_cam.global_transform.basis.x
		var move_vec = (right * input_dir.x + forward * -input_dir.z + Vector3.UP * input_dir.y)
		spectator_node.global_position += move_vec * speed * delta

func _update_diagnostics() -> void:
	var cur_fps = Engine.get_frames_per_second()
	if lbl_fps:
		lbl_fps.text = "FPS: %d" % cur_fps
		if cur_fps >= 60:
			lbl_fps.add_theme_color_override("font_color", Color("#2ecc71"))
		elif cur_fps >= 30:
			lbl_fps.add_theme_color_override("font_color", Color("#f1c40f"))
		else:
			lbl_fps.add_theme_color_override("font_color", Color("#e74c3c"))
			
	var count = balloon_container.get_child_count()
	var sleeping_count := 0
	var frozen_count := 0
	for c in balloon_container.get_children():
		if c is RigidBody3D and not c.is_queued_for_deletion():
			if c.freeze: frozen_count += 1
			elif c.sleeping: sleeping_count += 1
			
	if lbl_balloon_count:
		lbl_balloon_count.text = "Toplam: %d (Donan: %d | Uyuyan: %d)" % [count, frozen_count, sleeping_count]
		
	if lbl_physics_time:
		var p_time = Performance.get_monitor(Performance.TIME_PHYSICS_PROCESS) * 1000.0
		lbl_physics_time.text = "Fizik Süresi: %.2f ms" % p_time
		
	if lbl_active_bodies:
		var active = int(Performance.get_monitor(Performance.PHYSICS_3D_ACTIVE_OBJECTS))
		lbl_active_bodies.text = "Aktif Fizik Gövdesi: %d" % active
		
	if lbl_draw_calls:
		var dc = int(Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME))
		lbl_draw_calls.text = "Draw Calls: %d" % dc
		
	if lbl_memory:
		var mem_mb = Performance.get_monitor(Performance.MEMORY_STATIC) / (1024.0 * 1024.0)
		lbl_memory.text = "Statik Bellek: %.1f MB" % mem_mb

func _update_pile_optimization() -> void:
	if not balloon_container: return
	var cam_pos = spectator_cam.global_position if spectator_cam else Vector3.ZERO
	
	for b in balloon_container.get_children():
		if not is_instance_valid(b) or b.is_queued_for_deletion() or not (b is RigidBody3D):
			continue
			
		var b_pos: Vector3 = b.global_position
		# Kameranın 6 metre yakınındakiler veya tıkla vurulanlar canlı (Active)
		var near_cam = b_pos.distance_squared_to(cam_pos) < 36.0
		
		if near_cam:
			if b.freeze:
				b.freeze = false
				b.sleeping = false
			if b.can_sleep:
				b.can_sleep = false
		else:
			# Yere inmiş balonlar (y <= 2.2m) uzaktaysa uyur ve dondurulur
			var is_grounded = b_pos.y <= 2.2
			if is_grounded:
				if not b.can_sleep:
					b.can_sleep = true
				if not b.freeze and (b.sleeping or b.linear_velocity.length_squared() < 0.04):
					b.freeze = true
					b.freeze_mode = RigidBody3D.FREEZE_MODE_STATIC
			else:
				# Havadaki balonlar serbest düşer, asla donamaz
				if b.freeze:
					b.freeze = false
					b.sleeping = false
				if b.can_sleep:
					b.can_sleep = false

func spawn_balloons_grid(count: int) -> void:
	if not balloon_scene or not balloon_container:
		return
		
	# Hangar ölçeğinde yayılım: X [-16, 16], Z [-16, 16], Y [2.5, 12]
	var room_min = Vector3(-15.0, 2.5, -15.0)
	var room_max = Vector3(15.0, 11.0, 15.0)
	var g_scale = gravity_presets[current_gravity_idx]
	
	for i in range(count):
		var b = balloon_scene.instantiate()
		var spawn_pos = Vector3(
			randf_range(room_min.x, room_max.x),
			randf_range(room_min.y, room_max.y),
			randf_range(room_min.z, room_max.z)
		)
		b.position = spawn_pos
		b.gravity_scale = g_scale
		b.linear_damp = 1.0
		b.angular_damp = 2.0
		b.lock_rotation = false
		b.can_sleep = false
		b.rotation = Vector3(randf_range(-0.3, 0.3), randf_range(0.0, TAU), randf_range(-0.3, 0.3))
		b.angular_velocity = Vector3.ZERO
		
		# Tier distribution for variety
		var r = randf()
		if r < 0.65:
			b.setup_tier(1)
		elif r < 0.85:
			b.setup_tier(5)
		elif r < 0.95:
			b.setup_tier(10)
		else:
			b.setup_tier(50)
			
		balloon_container.add_child(b)

func burst_pop_random() -> void:
	var children = balloon_container.get_children()
	if children.is_empty():
		return
	children.shuffle()
	var pop_count = min(50, children.size())
	for i in range(pop_count):
		var b = children[i]
		if b and is_instance_valid(b) and b.has_method("pop"):
			b.pop("benchmark")

func cycle_gravity() -> void:
	current_gravity_idx = (current_gravity_idx + 1) % gravity_presets.size()
	var g_scale = gravity_presets[current_gravity_idx]
	_update_gravity_label()
	
	for c in balloon_container.get_children():
		if c and is_instance_valid(c) and c is RigidBody3D:
			c.gravity_scale = g_scale
			c.sleeping = false # Wake up to test dynamic load

func _update_gravity_label() -> void:
	if lbl_gravity_mode:
		lbl_gravity_mode.text = "Yerçekimi: %.2f G" % gravity_presets[current_gravity_idx]

func clear_all_balloons() -> void:
	for c in balloon_container.get_children():
		c.queue_free()

func _pop_balloon_at_crosshair() -> void:
	if not spectator_cam or not _ray_query:
		return
		
	var space = get_world_3d().direct_space_state
	if not space: return
	
	var from_pos = spectator_cam.global_position
	var to_pos = from_pos - spectator_cam.global_transform.basis.z * 100.0
	_ray_query.from = from_pos
	_ray_query.to = to_pos
	
	var hit = space.intersect_ray(_ray_query)
	if not hit.is_empty() and hit.has("collider"):
		var col = hit.collider
		if col and is_instance_valid(col) and col.has_method("pop"):
			col.pop("click")

func return_to_main_game() -> void:
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	get_tree().change_scene_to_file("res://scenes/main.tscn")
