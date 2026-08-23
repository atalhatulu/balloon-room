extends CharacterBody3D

signal pop_triggered(is_hit: bool)
signal nudge_triggered()
signal energy_changed(current: float, max_energy: float, is_exhausted: bool)

@export var base_walk_speed: float = 5.2
@export var base_sprint_speed: float = 8.4
@export var mouse_sensitivity: float = 0.003
@export var gravity: float = 9.8

# Dynamic Upgradable Stats
var walk_speed: float = 5.2
var sprint_speed: float = 8.4
var max_energy: float = 100.0
var current_energy: float = 100.0

# Auto-pop (Hold Left Click) is locked at start, purchased from shop
var auto_pop_unlocked: bool = false
var auto_pop_cooldown: float = 0.28
var auto_pop_timer: float = 0.0

# Energy Rules:
# - Single Click: 0 Energy (Always available unless exhausted)
# - Holding Left Click: Only active when Auto-Pop upgrade is bought; drains energy
# - Holding Right Click: Continuous Sweeper, drains energy
# - Running (Shift): 0 Energy
# - When Energy hits 0 -> Exhausted: CANNOT POP AT ALL until energy >= 30%!
var pop_hold_energy_cost: float = 6.0
var continuous_nudge_cost_per_sec: float = 24.0
var energy_regen_rate: float = 24.0
var energy_regen_delay: float = 0.60
var time_since_action: float = 0.0
var is_exhausted: bool = false

var nudge_power_mult: float = 1.0
var magnet_unlocked: bool = false
var magnet_level: int = 0
var magnet_range: float = 6.0
var magnet_force: float = 0.8

var splash_radius: float = 0.0
var splash_max_targets: int = 0

var can_pop: bool = true
var left_hold_time: float = 0.0
var is_ui_open: bool = false

@onready var head: Node3D = $Head
@onready var camera: Camera3D = $Head/Camera3D
@onready var interaction_ray: RayCast3D = $Head/Camera3D/InteractionRay
@onready var nudge_cone: Area3D = $Head/Camera3D/WindCone

func _ready() -> void:
	add_to_group("player")
	walk_speed = base_walk_speed
	sprint_speed = base_sprint_speed
	floor_snap_length = 0.5
	floor_stop_on_slope = true
	platform_floor_layers = 1
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	energy_changed.emit(current_energy, max_energy, is_exhausted)
	
	if interaction_ray:
		interaction_ray.add_exception(self)
		if nudge_cone:
			interaction_ray.add_exception_rid(nudge_cone.get_rid())
	
	var shop_manager = get_node_or_null("../ShopManager")
	if shop_manager and shop_manager.has_signal("upgrade_purchased"):
		shop_manager.upgrade_purchased.connect(apply_upgrade)

func set_ui_open(open: bool) -> void:
	is_ui_open = open
	velocity.x = 0.0
	velocity.z = 0.0
	left_hold_time = 0.0

func apply_upgrade(upgrade_id: String, level: int) -> void:
	match upgrade_id:
		"auto_pop":
			auto_pop_unlocked = (level > 0)
			var cooldowns = [0.20, 0.12, 0.075, 0.045, 0.028, 0.018, 0.012, 0.008]
			auto_pop_cooldown = cooldowns[clamp(level - 1, 0, cooldowns.size() - 1)]
		"energy_cap":
			var old_max = max_energy
			max_energy = 100.0 + (level * 25.0)
			current_energy += (max_energy - old_max)
			energy_changed.emit(current_energy, max_energy, is_exhausted)
		"energy_regen":
			energy_regen_rate = 24.0 + (level * 10.0)
			energy_regen_delay = max(0.25, 0.60 - (level * 0.05))
		"sprint_efficiency":
			pop_hold_energy_cost = max(1.2, 6.0 - (level * 0.65))
			continuous_nudge_cost_per_sec = max(6.0, 24.0 - (level * 2.5))
		"speed":
			walk_speed = base_walk_speed + (level * 0.4)
			sprint_speed = base_sprint_speed + (level * 0.65)
		"reach":
			if interaction_ray:
				interaction_ray.target_position = Vector3(0, 0, -4.5 - (level * 0.8))
		"nudge":
			nudge_power_mult = 1.0 + (level * 0.25)
		"splash_pop":
			var radii = [0.0, 2.8, 4.2, 6.0, 8.5, 11.5, 15.5, 22.0]
			var limits = [0, 15, 30, 55, 90, 140, 220, 350]
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
		
	if event is InputEventKey and event.pressed and event.keycode == KEY_ESCAPE:
		if Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
			Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
		else:
			Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
			
	if event is InputEventMouseButton and event.pressed:
		var main_node = get_node_or_null("/root/Main")
		if main_node and main_node.get("carried_device") != null:
			return
		if Input.mouse_mode != Input.MOUSE_MODE_CAPTURED:
			Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
		elif event.button_index == MOUSE_BUTTON_LEFT:
			left_hold_time = 0.0
			auto_pop_timer = 0.0
			if not is_exhausted:
				execute_pop_hit(false)

	if event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		rotate_y(-event.relative.x * mouse_sensitivity)
		head.rotate_x(-event.relative.y * mouse_sensitivity)
		head.rotation.x = clamp(head.rotation.x, deg_to_rad(-85), deg_to_rad(85))

func _physics_process(delta: float) -> void:
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

	# Left Click Handling (Hold mode only works if Auto-Pop is bought)
	var is_pressing_left = Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT) and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED
	if is_pressing_left:
		left_hold_time += delta
		if auto_pop_unlocked and left_hold_time > 0.15 and not is_exhausted:
			auto_pop_timer += delta
			if auto_pop_timer >= auto_pop_cooldown:
				auto_pop_timer = 0.0
				execute_pop_hit(true)
	else:
		left_hold_time = 0.0
		auto_pop_timer = 0.0

	# Right Click: Continuous Air Sweeper (drains energy)
	var is_pressing_right = Input.is_mouse_button_pressed(MOUSE_BUTTON_RIGHT) and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED
	if is_pressing_right and not is_exhausted:
		try_continuous_nudge(delta)

	# Energy Regeneration & %30 Exhaustion Unlock
	var is_actively_spending = (auto_pop_unlocked and is_pressing_left and left_hold_time > 0.20) or is_pressing_right
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
	if is_exhausted:
		return
		
	if costs_energy:
		consume_energy(pop_hold_energy_cost)
		
	if interaction_ray:
		interaction_ray.target_position = Vector3(0, 0, -5.5)
		interaction_ray.collision_mask = 3
		interaction_ray.collide_with_bodies = true
		interaction_ray.force_raycast_update()
		if interaction_ray.is_colliding():
			var col = interaction_ray.get_collider()
			if col and col.is_in_group("balloons") and col.has_method("pop"):
				var col_color = col.get("balloon_color") if ("balloon_color" in col) else Color.WHITE
				var pop_pos = col.global_position
				col.pop("needle")
				pop_triggered.emit(true)
				if splash_radius > 0.0:
					trigger_splash_pop(pop_pos, col_color, splash_radius)
				return
				
	# Direct Sphere Sweep fallback if direct center crosshair slightly misses sphere edge
	var world = get_world_3d()
	if world and camera:
		var space_state = world.direct_space_state
		if space_state:
			var cam_pos = camera.global_position
			var cam_fwd = -camera.global_transform.basis.z.normalized()
			
			var query = PhysicsShapeQueryParameters3D.new()
			var sphere = SphereShape3D.new()
			sphere.radius = 0.55
			query.shape = sphere
			query.transform = Transform3D(Basis(), cam_pos + cam_fwd * 2.2)
			query.collision_mask = 2
			query.collide_with_bodies = true
			query.collide_with_areas = false
			
			var results = space_state.intersect_shape(query, 6)
			var best_b: RigidBody3D = null
			var best_dist: float = 999.0
			for res in results:
				var b = res.collider
				if b is RigidBody3D and is_instance_valid(b) and not b.is_queued_for_deletion() and not b.get("is_popped"):
					var d = cam_pos.distance_to(b.global_position)
					if d < best_dist:
						best_dist = d
						best_b = b
						
			if best_b:
				var col_color = best_b.get("balloon_color") if ("balloon_color" in best_b) else Color.WHITE
				var pop_pos = best_b.global_position
				best_b.pop("needle")
				pop_triggered.emit(true)
				if splash_radius > 0.0:
					trigger_splash_pop(pop_pos, col_color, splash_radius)
				return
				
	pop_triggered.emit(false)

func trigger_splash_pop(origin: Vector3, match_color: Color = Color.WHITE, custom_radius: float = 0.0) -> void:
	var r = custom_radius if custom_radius > 0.0 else splash_radius
	if r <= 0.0:
		return
		
	spawn_shockwave_vfx(origin, r, match_color)
	
	var r_sq = r * r
	var balloons = get_tree().get_nodes_in_group("balloons")
	var popped_so_far = 0
	var max_t = (splash_max_targets + 25) if custom_radius > 0.0 else splash_max_targets
	
	for b in balloons:
		if b is RigidBody3D and is_instance_valid(b) and not b.is_queued_for_deletion():
			if not b.get("is_popped"):
				if origin.distance_squared_to(b.global_position) <= r_sq:
					if b.has_method("pop"):
						b.pop("splash")
						popped_so_far += 1
						if max_t > 0 and popped_so_far >= max_t:
							break

func spawn_shockwave_vfx(origin: Vector3, radius: float, shock_color: Color = Color(0.35, 0.85, 1.0)) -> void:
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
	tween.finished.connect(func(): if is_instance_valid(mesh_inst): mesh_inst.queue_free())

func try_continuous_nudge(delta: float) -> void:
	if is_exhausted:
		return
		
	consume_energy(continuous_nudge_cost_per_sec * delta)
	nudge_triggered.emit()
		
	if nudge_cone:
		var look_dir = -camera.global_transform.basis.z.normalized()
		var bodies = nudge_cone.get_overlapping_bodies()
		var push_dir = look_dir + Vector3.UP * 0.15
		push_dir = push_dir.normalized()
		for body in bodies:
			if body.is_in_group("balloons") and body is RigidBody3D:
				var dist = camera.global_position.distance_to(body.global_position)
				var strength = clamp(1.0 - (dist / 6.5), 0.25, 1.0) * (3.2 * nudge_power_mult)
				body.apply_central_force(push_dir * (strength * 12.0))
