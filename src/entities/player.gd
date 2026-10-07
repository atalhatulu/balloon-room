extends CharacterBody3D

signal pop_triggered(is_hit: bool)
signal nudge_triggered()
signal energy_changed(current: float, max_energy: float, is_exhausted: bool)
signal macro_toggled(is_active: bool)

const AirPulse = preload("res://src/entities/air_pulse.gd")
var _next_air_time: int = 0

@export var base_walk_speed: float = 5.2
@export var base_sprint_speed: float = 8.4
@export var mouse_sensitivity: float = 0.003
@export var gravity: float = 9.8

# Dynamic Upgradable Stats
var walk_speed: float = 5.2
var sprint_speed: float = 8.4
var max_energy: float = 100.0
var current_energy: float = 100.0

# Auto-fire toggle [Z / T] uses the purchased needle speed and energy cost.
var macro_click_enabled: bool = false
var macro_click_timer: float = 0.0

# Weapon inventory: 1 = Needle, 2 = Dart, 3 = Shotgun, 4 = Minigun
var current_weapon_slot: int = 1
var dart_weapon: Node3D
var shotgun_weapon: Node3D
var minigun_purchased_level: int = 0
var needle_cooldown_remaining := 0.0

# Minigun Frenzy (Special Chroma Event)
var is_minigun_frenzy: bool = false
var minigun_fire_timer: float = 0.0
var minigun_fire_interval: float = 0.038 # ~26 rounds/sec rapid pop rate
var minigun_heat := 0.0
var minigun_overheated := false
var minigun_cooldown_left := 0.0
# At the 0.038 s firing interval this allows about ten seconds of continuous fire,
# followed by a short two-second overheat lockout.
const MINIGUN_OVERHEAT_SECONDS := 2.0
const MINIGUN_HEAT_PER_SHOT := 0.0038
const MINIGUN_COOL_RATE := 0.20

# Auto-pop (Holding Left Mouse Button)
var auto_pop_unlocked: bool = false
var auto_pop_level: int = 0
var auto_pop_cooldown: float = 0.28
var auto_pop_timer: float = 0.0

# Energy Rules:
# - Single click: 0 energy, subject to the same purchased attack cooldown.
# - Holding left click / toggle macro: same energy drain; drops to 0 at high levels
# - Running (Shift): 0 Energy
# - When Energy hits 0 -> Exhausted: CANNOT POP AT ALL until energy >= 30%!
var pop_hold_energy_cost: float = 16.0
var energy_regen_rate: float = 24.0
var energy_regen_delay: float = 0.60
var time_since_action: float = 0.0
var is_exhausted: bool = false

var magnet_unlocked: bool = false
var magnet_level: int = 0
var magnet_range: float = 6.0
var magnet_force: float = 0.8

var splash_radius: float = 0.0
var splash_max_targets: int = 0

var can_pop: bool = true
var left_hold_time: float = 0.0
var is_ui_open: bool = false

# Cached physics queries to eliminate dynamic allocation on pop hits
var _needle_query: PhysicsShapeQueryParameters3D = null
var _needle_sphere: SphereShape3D = null
var _splash_query: PhysicsShapeQueryParameters3D = null
var _splash_sphere: SphereShape3D = null
static var _active_vfx_count: int = 0

@onready var head: Node3D = $Head
@onready var camera: Camera3D = $Head/Camera3D
@onready var interaction_ray: RayCast3D = $Head/Camera3D/InteractionRay
@onready var hands: Node3D = get_node_or_null("Head/Camera3D/Hands")
@onready var nudge_cone: Area3D = get_node_or_null("Head/Camera3D/WindCone")
var flashlight: SpotLight3D = null
var is_flashlight_on: bool = false

func _setup_flashlight() -> void:
	if not camera: return
	flashlight = SpotLight3D.new()
	flashlight.name = "Flashlight"
	flashlight.light_color = Color(1.0, 0.98, 0.90)
	flashlight.light_energy = 3.2
	flashlight.shadow_enabled = true
	flashlight.spot_range = 28.0
	flashlight.spot_angle = 38.0
	flashlight.spot_attenuation = 0.8
	flashlight.visible = false
	flashlight.position = Vector3(0.18, -0.15, -0.10)
	camera.add_child(flashlight)

func set_flashlight(enabled: bool) -> void:
	is_flashlight_on = enabled
	if enabled:
		macro_click_enabled = false
		macro_toggled.emit(false)
		if hands: hands.cancel_actions()
	if flashlight:
		flashlight.visible = enabled
	if hands and hands.has_method("set_flashlight_mode"):
		hands.set_flashlight_mode(enabled)

func toggle_flashlight() -> void:
	set_flashlight(not is_flashlight_on)

# Camera Movement Inertia & Turning Lag
var target_cam_offset: Vector3 = Vector3.ZERO
var current_cam_offset: Vector3 = Vector3.ZERO
var target_cam_tilt: float = 0.0
var current_cam_tilt: float = 0.0
var target_yaw: float = 0.0
var target_pitch: float = 0.0
var _walk_bob_timer: float = 0.0

func _ready() -> void:
	add_to_group("player")
	walk_speed = base_walk_speed
	sprint_speed = base_sprint_speed
	floor_snap_length = 0.5
	floor_stop_on_slope = true
	platform_floor_layers = 1
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	energy_changed.emit(current_energy, max_energy, is_exhausted)
	
	target_yaw = rotation.y
	if head:
		target_pitch = head.rotation.x
	
	if hands:
		hands.needle_contact.connect(_on_needle_contact)
	
	if interaction_ray:
		interaction_ray.add_exception(self)
		
	_setup_flashlight()
	dart_weapon = preload("res://src/entities/dart_gun.gd").new()
	dart_weapon.name = "DartGun"
	add_child(dart_weapon)
	dart_weapon.setup(self)
	
	shotgun_weapon = preload("res://src/entities/shotgun_dart.gd").new()
	shotgun_weapon.name = "ShotgunDart"
	add_child(shotgun_weapon)
	shotgun_weapon.setup(self)
	
	var shop_manager = get_node_or_null("../ShopManager")
	if shop_manager and shop_manager.has_signal("upgrade_purchased"):
		shop_manager.upgrade_purchased.connect(apply_upgrade)

func set_ui_open(open: bool, use_tablet: bool = false) -> void:
	is_ui_open = open
	velocity.x = 0.0
	velocity.z = 0.0
	left_hold_time = 0.0
	if hands and hands.has_method("set_tablet_mode"):
		if open:
			hands.cancel_actions()
		hands.set_tablet_mode(open and use_tablet)


func apply_upgrade(upgrade_id: String, level: int) -> void:
	match upgrade_id:
		"dart_gun":
			if dart_weapon: dart_weapon.configure(level)
			if level == 0 and current_weapon_slot == 2: switch_weapon_slot(1)
		"shotgun_dart":
			if shotgun_weapon: shotgun_weapon.configure(level)
			if level == 0 and current_weapon_slot == 3: switch_weapon_slot(1)
		"minigun_weapon":
			minigun_purchased_level = level
			if level > 0:
				minigun_fire_interval = [0.045, 0.040, 0.035, 0.030, 0.025][clamp(level - 1, 0, 4)]
			if level == 0 and current_weapon_slot == 4: switch_weapon_slot(1)
		"auto_pop":
			auto_pop_unlocked = (level > 0)
			auto_pop_level = level
			if level == 0:
				macro_click_enabled = false
				macro_toggled.emit(false)
			var cooldowns = [0.20, 0.12, 0.075, 0.045, 0.028, 0.018, 0.012, 0.008]
			auto_pop_cooldown = cooldowns[clamp(level - 1, 0, cooldowns.size() - 1)]
			# Drain per second (NOT per hit!). At Level 8 -> 0 drain (Infinite free auto-fire)!
			pop_hold_energy_cost = max(0.0, 16.0 - (level * 2.0))
		"athlete_training":
			var old_max = max_energy
			max_energy = 100.0 + (level * 25.0)
			current_energy += (max_energy - old_max)
			energy_regen_rate = 24.0 + (level * 8.0)
			energy_regen_delay = max(0.15, 0.50 - (level * 0.05))
			walk_speed = base_walk_speed + (level * 0.35)
			sprint_speed = base_sprint_speed + (level * 0.55)
			energy_changed.emit(current_energy, max_energy, is_exhausted)
		"splash_pop":
			var radii = [0.0, 1.8, 2.4, 3.0, 3.8, 4.6, 5.5, 6.8]
			var limits = [0, 2, 3, 5, 8, 12, 18, 25]
			splash_radius = radii[clamp(level, 0, radii.size() - 1)]
			splash_max_targets = limits[clamp(level, 0, limits.size() - 1)]
		"coin_magnet":
			magnet_unlocked = (level > 0)
			magnet_level = level
			var ranges = [3.5, 5.5, 8.0, 12.0, 17.0, 24.0, 32.0, 45.0]
			magnet_range = ranges[clamp(level - 1, 0, ranges.size() - 1)] if level > 0 else 3.5

func _input(event: InputEvent) -> void:
	if is_ui_open:
		return
		
	if event is InputEventKey and event.pressed and not event.is_echo():
		if event.keycode == KEY_1:
			switch_weapon_slot(1)
		elif event.keycode == KEY_2:
			switch_weapon_slot(2)
		elif event.keycode == KEY_3:
			switch_weapon_slot(3)
		elif event.keycode == KEY_4:
			switch_weapon_slot(4)
		elif event.keycode == KEY_Z or event.keycode == KEY_T:
			macro_click_enabled = auto_pop_unlocked and not macro_click_enabled
			macro_toggled.emit(macro_click_enabled)
			
	if event is InputEventMouseButton and event.pressed:
		var main_node = get_node_or_null("/root/Main")
		if main_node and main_node.get("carried_device") != null:
			return
		if Input.mouse_mode != Input.MOUSE_MODE_CAPTURED:
			Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
		elif event.button_index == MOUSE_BUTTON_LEFT:
			left_hold_time = 0.0
			auto_pop_timer = 0.0
			if is_minigun_frenzy or current_weapon_slot == 4:
				execute_minigun_shot()
			elif current_weapon_slot == 2:
				dart_weapon.fire()
			elif current_weapon_slot == 3:
				shotgun_weapon.fire()
			elif not is_exhausted:
				execute_pop_hit(false)

	if event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		rotation.y -= event.relative.x * mouse_sensitivity
		target_yaw = rotation.y
		if head:
			head.rotation.x = clamp(head.rotation.x - event.relative.y * mouse_sensitivity, deg_to_rad(-85), deg_to_rad(85))
			target_pitch = head.rotation.x
		if hands:
			hands.handle_mouse_motion(event.relative)

func _process(delta: float) -> void:
	if is_flashlight_on and hands and hands.flashlight_prop and hands.flashlight_prop.is_visible_in_tree():
		flashlight.global_position = hands.flashlight_prop.to_global(Vector3(0, 0, -0.17))
		flashlight.look_at(camera.global_position - camera.global_basis.z * 12.0, camera.global_basis.y)
	if not is_ui_open:
		# 2. Movement Inertia Lag, Rhythmic Head-Bobbing & Strafe Roll
		var local_vel = transform.basis.inverse() * velocity
		var speed_h = Vector2(local_vel.x, local_vel.z).length()
		
		# Walking / Sprinting Head Bob
		if is_on_floor() and speed_h > 0.4:
			var bob_freq = 11.5 if (speed_h > walk_speed * 1.1) else 8.5
			_walk_bob_timer += delta * bob_freq
			target_cam_offset.y = sin(_walk_bob_timer) * 0.022
			target_cam_offset.x = clamp(-local_vel.x * 0.022 + cos(_walk_bob_timer * 0.5) * 0.012, -0.06, 0.06)
		else:
			_walk_bob_timer = 0.0
			target_cam_offset.y = 0.0
			target_cam_offset.x = clamp(-local_vel.x * 0.018, -0.05, 0.05)
			
		target_cam_offset.z = clamp(local_vel.z * 0.020, -0.07, 0.07)
		target_cam_tilt = clamp(-local_vel.x * 0.009, -0.045, 0.045)
		
		current_cam_offset = current_cam_offset.lerp(target_cam_offset, 10.0 * delta)
		current_cam_tilt = lerp_angle(current_cam_tilt, target_cam_tilt, 12.0 * delta)
		
		if camera:
			camera.position = current_cam_offset
			camera.rotation.z = current_cam_tilt
			
		# Dynamic Hand Reach toward Balloon under crosshair (like toothbrush in just-one-more-floor)
		if hands and hands.has_method("set_target_reach"):
			var is_aiming = false
			var hit_dist = 0.0
			var hit_normal = Vector3.ZERO
			var hit_point = Vector3.ZERO
			if interaction_ray and current_weapon_slot == 1 and not is_minigun_frenzy and not is_flashlight_on:
				interaction_ray.target_position = Vector3(0, 0, -get_needle_reach())
				interaction_ray.collision_mask = 3
				interaction_ray.collide_with_bodies = true
				interaction_ray.force_raycast_update()
				if interaction_ray.is_colliding():
					var col = interaction_ray.get_collider()
					if col and col.is_in_group("balloons") and not col.get("is_popped"):
						is_aiming = true
						var hit_pt = interaction_ray.get_collision_point()
						hit_point = hit_pt
						hit_dist = camera.global_position.distance_to(hit_pt) if camera else 1.5
						hit_normal = interaction_ray.get_collision_normal()
						var surface: Dictionary = col.get_surface_hit(camera.global_position, -camera.global_basis.z)
						if surface.is_empty():
							is_aiming = false
						else:
							hit_point = surface.position
							hit_normal = surface.normal
			hands.set_target_reach(is_aiming, hit_dist, hit_normal, hit_point)

func _physics_process(delta: float) -> void:
	_update_minigun_thermal(delta)
	if is_ui_open:
		if not is_on_floor():
			velocity.y -= gravity * delta
		else:
			velocity.y = 0.0
		velocity.x = 0.0
		velocity.z = 0.0
		move_and_slide()
		return

	if not is_on_floor():
		velocity.y -= gravity * delta
	elif Input.is_key_pressed(KEY_SPACE):
		velocity.y = 4.5

	# Movement (Sprint is 100% free)
	var input_dir := Vector2.ZERO
	if Input.is_key_pressed(KEY_W): input_dir.y -= 1
	if Input.is_key_pressed(KEY_S): input_dir.y += 1
	if Input.is_key_pressed(KEY_A): input_dir.x -= 1
	if Input.is_key_pressed(KEY_D): input_dir.x += 1
	
	var is_moving = input_dir != Vector2.ZERO
	var wants_sprint = Input.is_key_pressed(KEY_SHIFT) and is_moving
	var current_speed = sprint_speed if wants_sprint else walk_speed
	
	var move_vec := (transform.basis * Vector3(input_dir.x, 0, input_dir.y)).normalized()
	if move_vec:
		velocity.x = move_toward(velocity.x, move_vec.x * current_speed, 35.0 * delta)
		velocity.z = move_toward(velocity.z, move_vec.z * current_speed, 35.0 * delta)
	else:
		velocity.x = move_toward(velocity.x, 0, 30.0 * delta)
		velocity.z = move_toward(velocity.z, 0, 30.0 * delta)
		
	move_and_slide()
	
	# Smoothly push and part balloons horizontally on touch
	for i in range(get_slide_collision_count()):
		var collision = get_slide_collision(i)
		var collider = collision.get_collider()
		if collider and collider.is_in_group("balloons") and collider is RigidBody3D:
			if collider.has_method("wake_physics"):
				collider.wake_physics()
			var push_dir = (collider.global_position - global_position)
			push_dir.y = 0.05
			push_dir = push_dir.normalized()
			var move_factor = clamp(velocity.length() / base_walk_speed, 1.0, 2.5)
			collider.apply_central_impulse(push_dir * (2.2 * move_factor))
			if collider.has_method("apply_elastic_impact"):
				collider.apply_elastic_impact(push_dir * (2.5 * move_factor))

	# 0. Ranged weapons do not also trigger the needle.
	needle_cooldown_remaining = maxf(0.0, needle_cooldown_remaining - delta)
	var is_using_minigun = is_minigun_frenzy or current_weapon_slot == 4
	var is_using_ranged = is_flashlight_on or (hands and hands.equipment_busy()) or current_weapon_slot in [2, 3] or is_using_minigun
	if is_using_minigun and not is_minigun_blocked() and not is_ui_open and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		var firing = Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT)
		if firing:
			minigun_fire_timer += delta
			if minigun_fire_timer >= minigun_fire_interval:
				minigun_fire_timer = maxf(0.0, minigun_fire_timer - minigun_fire_interval)
				execute_minigun_shot()
		else:
			minigun_fire_timer = minigun_fire_interval

	# 1. Toggle auto-fire uses the same limits as holding the button.
	if not is_using_ranged and not is_ui_open and auto_pop_unlocked and macro_click_enabled and not is_exhausted and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		macro_click_timer += delta
		if macro_click_timer >= auto_pop_cooldown:
			macro_click_timer = 0.0
			execute_pop_hit(false)

	# 2. Holding Left Click (Auto-Pop Upgrade)
	var is_pressing_left = not is_using_ranged and not is_ui_open and not macro_click_enabled and Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT) and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED
	var is_holding_auto_pop = not is_using_ranged and not is_ui_open and auto_pop_unlocked and macro_click_enabled and not is_exhausted and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED
	if is_holding_auto_pop and pop_hold_energy_cost > 0.0:
		consume_energy(pop_hold_energy_cost * delta)
	if is_pressing_left:
		left_hold_time += delta
		if auto_pop_unlocked and left_hold_time > 0.12 and not is_exhausted:
			is_holding_auto_pop = true
			auto_pop_timer += delta
			if pop_hold_energy_cost > 0.0:
				consume_energy(pop_hold_energy_cost * delta)
				
			if auto_pop_timer >= auto_pop_cooldown:
				auto_pop_timer = 0.0
				execute_pop_hit(false)
	else:
		left_hold_time = 0.0
		auto_pop_timer = 0.0

	# Energy Regeneration & %30 Exhaustion Unlock
	var is_actively_spending = is_holding_auto_pop and (pop_hold_energy_cost > 0.0)
	if not is_actively_spending or is_exhausted:
		time_since_action += delta
		if time_since_action >= energy_regen_delay:
			regenerate_energy(energy_regen_rate * delta)

func consume_energy(amount: float) -> void:
	current_energy = clamp(current_energy - amount, 0.0, max_energy)
	time_since_action = 0.0
	
	# Exhausted on 0 energy: completely locked out from popping/nudge
	if current_energy <= 0.0 and not is_exhausted:
		is_exhausted = true
		
	energy_changed.emit(current_energy, max_energy, is_exhausted)

func regenerate_energy(amount: float) -> void:
	if current_energy < max_energy:
		current_energy = clamp(current_energy + amount, 0.0, max_energy)
		
		# Recovery rule: Only unlock popping when energy reaches >= 30%
		var recovery_threshold = max_energy * 0.30
		if is_exhausted and current_energy >= recovery_threshold:
			is_exhausted = false
			
		energy_changed.emit(current_energy, max_energy, is_exhausted)

func execute_pop_hit(costs_energy: bool) -> void:
	if (hands and hands.equipment_busy()) or is_flashlight_on or current_weapon_slot != 1 or is_minigun_frenzy or needle_cooldown_remaining > 0.0 or is_exhausted or is_ui_open or not camera or not interaction_ray:
		return
	if hands and (hands.contact_pending or hands._is_carrying):
		return
	needle_cooldown_remaining = auto_pop_cooldown if auto_pop_unlocked else 0.20
	if costs_energy:
		consume_energy(pop_hold_energy_cost)
	var needle_reach: float = get_needle_reach()
	interaction_ray.target_position = Vector3(0, 0, -needle_reach)
	interaction_ray.collision_mask = 3
	interaction_ray.collide_with_areas = false
	interaction_ray.force_raycast_update()
	if interaction_ray.is_colliding():
		var target = interaction_ray.get_collider()
		if target and target.is_in_group("balloons") and not target.get("is_popped"):
			var surface: Dictionary = target.get_surface_hit(camera.global_position, -camera.global_basis.z)
			if surface.is_empty():
				if hands:
					hands.play_stab()
				pop_triggered.emit(false)
				return
			var point: Vector3 = surface.position
			var normal: Vector3 = surface.normal
			if hands:
				# Fast upgrades shorten the approach; recovery can be interrupted,
				# but an in-flight contact is never overwritten by the next input.
				var approach := 0.075
				if auto_pop_unlocked:
					approach = clampf(auto_pop_cooldown * 0.45, 0.012, 0.075)
				if macro_click_enabled:
					approach = clampf(auto_pop_cooldown * 0.45, 0.012, 0.075)
				hands.play_target_stab(target, point, normal, approach)
			else:
				_on_needle_contact(target)
			return
	if hands:
		hands.play_stab()
	pop_triggered.emit(false)

func _on_needle_contact(target: Node) -> void:
	if (hands and hands.equipment_busy()) or is_flashlight_on or is_ui_open or not is_instance_valid(target) or target.is_queued_for_deletion() or target.get("is_popped"):
		return
	var point: Vector3 = hands.last_contact_point if hands else target.global_position
	var needle_reach: float = get_needle_reach()
	if camera.global_position.distance_to(point) > needle_reach + 0.2:
		return
	# A moving target must still be on this side of walls/furniture at impact.
	var visibility_ray := PhysicsRayQueryParameters3D.create(camera.global_position, point, 1, [get_rid()])
	if not get_world_3d().direct_space_state.intersect_ray(visibility_ray).is_empty():
		return
	var pop_pos: Vector3 = target.global_position
	var color: Color = target.balloon_color
	if hands: hands.pop_recoil(1.4 if target.gas_type != "normal" else 1.0)
	target.pop("needle")
	if splash_radius > 0.0:
		trigger_splash_pop(pop_pos, color)
	pop_triggered.emit(true)

func switch_weapon_slot(slot: int) -> void:
	if slot not in [1, 2, 3, 4] or is_ui_open or (hands and hands._is_carrying): return
	var main = get_node_or_null("/root/Main")
	if slot == 2 and (not dart_weapon or dart_weapon.level == 0):
		if main and main.hud_controller:
			main.hud_controller.show_prompt("Dart tabancası: 650 patlatmada marketten açılır.", 2.0)
		return
	if slot == 3 and (not shotgun_weapon or shotgun_weapon.level == 0):
		if main and main.hud_controller:
			main.hud_controller.show_prompt("Pompalı Dart: Oda 2'de (5.000 patlatma) marketten açılır.", 2.0)
		return
	if slot == 4 and minigun_purchased_level == 0:
		if main and main.hud_controller:
			main.hud_controller.show_prompt("Ağır Minigun: Oda 3'te (60.000 patlatma) marketten açılır.", 2.0)
		return
	if current_weapon_slot == slot: return
	if current_weapon_slot != slot:
		macro_click_enabled = false
		macro_toggled.emit(false)
	current_weapon_slot = slot
	left_hold_time = 0.0
	auto_pop_timer = 0.0
	if hands:
		hands.cancel_actions()
		hands.set_target_reach(false)
		if slot == 4 and not hands.minigun_model:
			hands._setup_minigun_model()
	if main and main.hud_controller:
		var name_str = "İĞNE [1]"
		if slot == 2: name_str = "DART [2] • Basılı tut: seri atış"
		elif slot == 3: name_str = "POMPALI DART [3] • Geniş alan saçma"
		elif slot == 4: name_str = "MİNİGUN [4] • Ağır yaylım ateşi"
		main.hud_controller.show_prompt(name_str, 2.0)

func set_minigun_frenzy(enabled: bool) -> void:
	is_minigun_frenzy = enabled
	if hands and hands.has_method("set_minigun_mode"):
		hands.set_minigun_mode(enabled)

func is_minigun_blocked() -> bool:
	return minigun_overheated or minigun_cooldown_left > 0.0

func _update_minigun_thermal(delta: float) -> void:
	if minigun_overheated:
		minigun_cooldown_left = maxf(0.0, minigun_cooldown_left - delta)
		minigun_heat = minigun_cooldown_left / MINIGUN_OVERHEAT_SECONDS
		if minigun_cooldown_left <= 0.0:
			minigun_overheated = false
			minigun_heat = 0.0
	elif not ((is_minigun_frenzy or current_weapon_slot == 4) and not is_ui_open and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED and Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT)):
		minigun_heat = maxf(0.0, minigun_heat - delta * MINIGUN_COOL_RATE)

func _add_minigun_heat() -> void:
	minigun_heat = minf(1.0, minigun_heat + MINIGUN_HEAT_PER_SHOT)
	if minigun_heat >= 0.999:
		minigun_heat = 1.0
		minigun_overheated = true
		minigun_cooldown_left = MINIGUN_OVERHEAT_SECONDS
		minigun_fire_timer = 0.0

func execute_minigun_shot() -> void:
	var can_fire_minigun = is_minigun_frenzy or current_weapon_slot == 4
	if (hands and hands.equipment_busy()) or is_flashlight_on or not can_fire_minigun or is_minigun_blocked() or is_ui_open or not camera or (hands and (hands._is_carrying or hands._is_tablet_open)): return
	_add_minigun_heat()
	var sm = get_node_or_null("../SoundManager")
	if sm and sm.has_method("play_minigun_shot"):
		sm.play_minigun_shot()
	if hands and hands.has_method("pop_recoil"):
		hands.pop_recoil(0.4)
	if hands and hands.has_method("minigun_shot_feedback"):
		hands.minigun_shot_feedback()
	
	# Raycast forward with slight ballistic spread
	var spread = Vector3(randf_range(-0.020, 0.020), randf_range(-0.020, 0.020), 0.0)
	var ray_dir = (-camera.global_basis.z + camera.global_basis * spread).normalized()
	
	# Get real-time muzzle position from minigun model
	var muzzle_pos = hands.get_minigun_muzzle_position() if (hands and hands.has_method("get_minigun_muzzle_position")) else (camera.global_position + camera.global_basis * Vector3(0.18, -0.20, -0.75))
	var max_range = 65.0
	
	var world = get_world_3d()
	if not world: return
	var space = world.direct_space_state
	if not space: return
	
	# 1. Determine bullet endpoint by finding first solid obstacle (wall/floor/furniture - collision mask 1)
	var wall_query = PhysicsRayQueryParameters3D.create(camera.global_position, camera.global_position + ray_dir * max_range, 1, [get_rid()])
	var wall_hit = space.intersect_ray(wall_query)
	var hit_end = wall_hit.position if not wall_hit.is_empty() else (camera.global_position + ray_dir * max_range)
	
	# 2. Piercing / Penetration: Pop ALL balloons along the trajectory from muzzle to wall
	var current_start = camera.global_position
	var hit_count = 0
	var excluded_rids = [get_rid()]
	
	while hit_count < 24:
		var balloon_query = PhysicsRayQueryParameters3D.create(current_start, hit_end, 2, excluded_rids)
		var b_hit = space.intersect_ray(balloon_query)
		if b_hit.is_empty():
			break
		var col = b_hit.collider
		excluded_rids.append(b_hit.rid)
		if col and col.is_in_group("balloons") and not col.get("is_popped"):
			col.pop("needle")
			hit_count += 1
		# Advance start slightly past current hit point to pierce through
		current_start = b_hit.position + ray_dir * 0.08
		if current_start.distance_to(camera.global_position) >= hit_end.distance_to(camera.global_position):
			break
			
	if hit_count > 0:
		pop_triggered.emit(true)
	else:
		pop_triggered.emit(false)
		
	# 3. Spawn fast visible tracer beam traveling from muzzle to wall endpoint
	_spawn_minigun_tracer(muzzle_pos, hit_end)

static var _tracer_count: int = 0
static var _tracer_mesh: CylinderMesh = null
static var _tracer_mat: StandardMaterial3D = null

func _spawn_minigun_tracer(from_pos: Vector3, to_pos: Vector3) -> void:
	if _tracer_count >= 24:
		return
	_tracer_count += 1
	
	if _tracer_mesh == null:
		_tracer_mesh = CylinderMesh.new()
		_tracer_mesh.top_radius = 0.018
		_tracer_mesh.bottom_radius = 0.018
		_tracer_mesh.height = 1.0
		_tracer_mesh.radial_segments = 6
		_tracer_mesh.rings = 1
		
	if _tracer_mat == null:
		_tracer_mat = StandardMaterial3D.new()
		_tracer_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		_tracer_mat.albedo_color = Color(1.0, 0.88, 0.35, 1.0)
		_tracer_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		
	var tracer = MeshInstance3D.new()
	tracer.mesh = _tracer_mesh
	tracer.material_override = _tracer_mat
	tracer.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	
	var length = maxf(0.1, from_pos.distance_to(to_pos))
	var dir = (to_pos - from_pos).normalized()
	
	# Position at midpoint and orient along trajectory (CylinderMesh height is on UP axis)
	var midpoint = (from_pos + to_pos) * 0.5
	var q = Quaternion(Vector3.UP, dir)
	tracer.global_transform = Transform3D(Basis(q).scaled_local(Vector3(1.0, length, 1.0)), midpoint)
		
	var tree = get_tree()
	if tree and tree.current_scene:
		tree.current_scene.add_child(tracer)
		var t = tracer.create_tween()
		t.tween_property(tracer, "scale:x", 0.0, 0.08)
		t.parallel().tween_property(tracer, "scale:z", 0.0, 0.08)
		t.finished.connect(func():
			_tracer_count = max(0, _tracer_count - 1)
			if is_instance_valid(tracer):
				tracer.queue_free()
		)
	else:
		_tracer_count = max(0, _tracer_count - 1)

func get_needle_reach() -> float:
	var gm = get_node_or_null("../GameManager")
	return gm.get_needle_reach() if gm and gm.has_method("get_needle_reach") else 5.7

func _ensure_physics_queries() -> void:
	if _needle_sphere == null:
		_needle_sphere = SphereShape3D.new()
		_needle_sphere.radius = 0.55
	if _needle_query == null:
		_needle_query = PhysicsShapeQueryParameters3D.new()
		_needle_query.shape = _needle_sphere
		_needle_query.collision_mask = 2 # Balloons layer
		_needle_query.collide_with_bodies = true
		_needle_query.collide_with_areas = false
		
	if _splash_sphere == null:
		_splash_sphere = SphereShape3D.new()
	if _splash_query == null:
		_splash_query = PhysicsShapeQueryParameters3D.new()
		_splash_query.shape = _splash_sphere
		_splash_query.collision_mask = 2 # Balloons layer
		_splash_query.collide_with_bodies = true
		_splash_query.collide_with_areas = false

func trigger_splash_pop(origin: Vector3, match_color: Color = Color.WHITE, custom_radius: float = 0.0) -> void:
	var r = custom_radius if custom_radius > 0.0 else splash_radius
	if r <= 0.0:
		return
		
	spawn_shockwave_vfx(origin, r, match_color)
	
	var world = get_world_3d()
	if not world: return
	var space_state = world.direct_space_state
	if not space_state: return
	
	_ensure_physics_queries()
	_splash_sphere.radius = r
	_splash_query.transform = Transform3D(Basis(), origin)
	
	var max_t = (splash_max_targets + 25) if custom_radius > 0.0 else splash_max_targets
	# Yoğun odalarda farklı renkteki yakın balonlar da şekil sorgusunun
	# sonucunu doldurup aynı renkli komşuları listeden düşürmesin.
	var candidate_limit = 256
	var hits = space_state.intersect_shape(_splash_query, candidate_limit)
	
	var popped_so_far = 0
	for res in hits:
		var b = res.collider
		if b is RigidBody3D and is_instance_valid(b) and not b.is_queued_for_deletion():
			if not b.get("is_popped"):
				# Enforce same-color matching rule
				if match_color != Color.WHITE:
					var b_col = b.get("balloon_color") if ("balloon_color" in b) else Color.WHITE
					if not b_col.is_equal_approx(match_color):
						continue
						
				if b.has_method("pop"):
					b.pop("splash")
					popped_so_far += 1
					if max_t > 0 and popped_so_far >= max_t:
						break

func spawn_shockwave_vfx(origin: Vector3, radius: float, shock_color: Color = Color(0.35, 0.85, 1.0)) -> void:
	if _active_vfx_count >= 6:
		return
	_active_vfx_count += 1
	var mesh_inst = MeshInstance3D.new()
	var sphere = SphereMesh.new()
	sphere.radius = 0.25
	sphere.height = 0.5
	mesh_inst.mesh = sphere
	mesh_inst.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	
	var mat = StandardMaterial3D.new()
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.albedo_color = Color(shock_color.r, shock_color.g, shock_color.b, 0.45)
	mat.emission_enabled = true
	mat.emission = shock_color
	mat.emission_energy_multiplier = 2.5
	mesh_inst.material_override = mat
	
	mesh_inst.position = origin
	get_parent().add_child(mesh_inst)
	
	var tween = create_tween()
	tween.set_parallel(true)
	tween.tween_property(mesh_inst, "scale", Vector3.ONE * radius * 1.5, 0.18)
	tween.tween_property(mat, "albedo_color:a", 0.0, 0.18)
	tween.finished.connect(func(): 
		_active_vfx_count = max(0, _active_vfx_count - 1)
		if is_instance_valid(mesh_inst): 
			mesh_inst.queue_free()
	)

func perform_nudge_slap() -> void:
	# No unarmed left-hand action. Right click remains available for placement cancel.
	nudge_triggered.emit()
	return

func _release_air_pulse() -> void:
	return
