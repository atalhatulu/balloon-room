extends Area3D

const Design = preload("res://src/entities/collectible_design.gd")

var coin_value: int = 1
var velocity: Vector3 = Vector3.ZERO
var tumble_speed: Vector3 = Vector3.ZERO
var is_grounded: bool = false
var is_settled: bool = false
var is_collecting: bool = false
var lifetime: float = 0.0
var ground_time: float = 0.0
var bounce_count: int = 0
var floor_y: float = 0.06
var collect_speed: float = 3.0
var collect_origin := Vector3.ZERO
var collect_progress := 0.0
var collect_started := false
var collected := false
var is_merging := false
var visual_tween: Tween

@onready var mesh_instance: MeshInstance3D = $MeshInstance3D

static var _material_cache: Dictionary = {}
static var _main_ref: Node = null
static var _player_ref: CharacterBody3D = null
static var _shop_manager_ref: Node = null
static var _sound_manager_ref: Node = null

static func ensure_static_refs(context_node: Node) -> void:
	if not is_instance_valid(_main_ref):
		var tree = context_node.get_tree()
		if tree and tree.root:
			_main_ref = tree.root.get_node_or_null("Main")
	if is_instance_valid(_main_ref):
		if not is_instance_valid(_player_ref):
			_player_ref = _main_ref.get("player")
		if not is_instance_valid(_shop_manager_ref):
			_shop_manager_ref = _main_ref.get("shop_manager")
		if not is_instance_valid(_sound_manager_ref):
			_sound_manager_ref = _main_ref.get("sound_manager")

static func get_coin_material(key: int) -> StandardMaterial3D:
	if _material_cache.has(key):
		return _material_cache[key]
		
	var mat := StandardMaterial3D.new()
	# Three medal metals; 50-value bundles retain gold and grow in size.
	mat.albedo_color = Color("b87543") if key < 5 else (Color("c4d2df") if key < 10 else Color("f4c64f"))
	mat.metallic = 0.78
	mat.roughness = 0.32
	mat.clearcoat_enabled = true
	mat.clearcoat = 0.35
	mat.rim_enabled = true
	mat.rim = 0.25

	_material_cache[key] = mat
	return mat

func init(spawn_pos: Vector3, val: int = 1, tier: int = 1) -> void:
	global_position = spawn_pos
	coin_value = val
	is_grounded = false
	is_settled = false
	is_collecting = false
	lifetime = 0.0
	ground_time = 0.0
	bounce_count = 0
	collect_speed = 3.0
	collect_started = false
	collect_progress = 0.0
	collected = false
	is_merging = false
	if visual_tween and visual_tween.is_valid(): visual_tween.kill()
	if mesh_instance: mesh_instance.scale = Vector3.ONE
	
	ensure_static_refs(self)
	
	# Moderate arc burst in random radial direction
	var burst_ang = randf() * TAU
	var h_speed = randf_range(0.8, 2.2)
	velocity = Vector3(
		cos(burst_ang) * h_speed,
		randf_range(2.2, 3.6),
		sin(burst_ang) * h_speed
	)
	
	# Mid-air tumbling spin
	tumble_speed = Vector3(
		randf_range(-10.0, 10.0),
		randf_range(12.0, 20.0),
		randf_range(-10.0, 10.0)
	)
	
	# Visual Coin Tiers
	var target_scale = Vector3.ONE
	var mat_key = 1
	
	if tier == 50 or val >= 50:
		target_scale = Vector3(1.75, 1.75, 1.75)
		mat_key = 50
	elif tier == 10 or val >= 10:
		target_scale = Vector3(1.40, 1.40, 1.40)
		mat_key = 10
	elif tier == 5 or val >= 5:
		target_scale = Vector3(1.12, 1.12, 1.12)
		mat_key = 5
	else:
		target_scale = Vector3(0.92, 0.92, 0.92)
		mat_key = 1
		
	apply_tier_visuals(mat_key, target_scale, true)

func apply_tier_visuals(mat_key: int, target_scale: Vector3, animate_pop: bool = false) -> void:
	if not mesh_instance:
		mesh_instance = get_node_or_null("MeshInstance3D")
	if mesh_instance:
		mesh_instance.mesh = Design.get_coin_mesh()
		mesh_instance.material_override = get_coin_material(mat_key)
		mesh_instance.rotation = Vector3.ZERO
		mesh_instance.position.y = 0.02 if is_grounded else 0.0
		
	if visual_tween and visual_tween.is_valid(): visual_tween.kill()
	if animate_pop:
		scale = target_scale * 0.65
		visual_tween = create_tween()
		visual_tween.tween_property(self, "scale", target_scale, 0.22).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	else:
		scale = target_scale

func upgrade_tier(new_val: int, animate: bool = true) -> void:
	coin_value = new_val
	var target_scale = Vector3.ONE
	var mat_key = 1
	if new_val >= 50:
		target_scale = Vector3(1.75, 1.75, 1.75)
		mat_key = 50
	elif new_val >= 10:
		target_scale = Vector3(1.40, 1.40, 1.40)
		mat_key = 10
	elif new_val >= 5:
		target_scale = Vector3(1.12, 1.12, 1.12)
		mat_key = 5
	else:
		target_scale = Vector3(0.92, 0.92, 0.92)
		mat_key = 1

	apply_tier_visuals(mat_key, target_scale, animate)

func _ready() -> void:
	add_to_group("coins")
	ensure_static_refs(self)
	upgrade_tier(coin_value, false)

func _process(delta: float) -> void:
	if is_merging or collected: return
	lifetime += delta
	
	if not is_instance_valid(_player_ref):
		ensure_static_refs(self)
	
	# Check for magnetic attraction to player (optimized squared distance checks)
	if not is_collecting and is_instance_valid(_player_ref):
		var p_pos = _player_ref.global_position + Vector3(0, 0.9, 0)
		var dist_sq = global_position.distance_squared_to(p_pos)
		
		if is_grounded:
			var pickup_range = _player_ref.get("magnet_range") if ("magnet_range" in _player_ref) else 3.8
			if is_instance_valid(_main_ref) and _main_ref.bonus_controller.magnet_seconds > 0: pickup_range = maxf(pickup_range, 30.0)
			if dist_sq <= (pickup_range * pickup_range):
				is_collecting = true
		else:
			if dist_sq <= 1.21 and lifetime > 0.25: # 1.1 * 1.1 = 1.21
				is_collecting = true
				
	# 1. State: Collecting (Accelerating Swoop & Scale into Player)
	if is_collecting:
		if is_instance_valid(_player_ref):
			var target_pos = _player_ref.global_position + Vector3(0, 0.9, 0)
			if not collect_started:
				collect_started = true
				collect_origin = global_position
			collect_progress = minf(1, collect_progress + delta / 0.45)
			var t := collect_progress * collect_progress * (3.0 - 2.0 * collect_progress)
			global_position = collect_origin.lerp(target_pos, t) + Vector3.UP * sin(t * PI) * 0.65

			if mesh_instance:
				mesh_instance.rotate_y(22.0 * delta)
			scale = scale.lerp(Vector3(0.15, 0.15, 0.15), 14.0 * delta)
			
			if collect_progress >= 1.0 or global_position.distance_squared_to(target_pos) < 0.08: # 0.55 * 0.55 ≈ 0.30
				collect_coin()
		else:
			collect_coin()
		return
		
	# 2. State: Falling in Air (Crisp Gravity, Air Drag & Tumble)
	if not is_grounded:
		velocity.y -= 22.0 * delta
		velocity.x = move_toward(velocity.x, 0.0, 3.5 * delta)
		velocity.z = move_toward(velocity.z, 0.0, 3.5 * delta)
		global_position += velocity * delta
		
		if mesh_instance:
			mesh_instance.rotate_x(tumble_speed.x * delta)
			mesh_instance.rotate_y(tumble_speed.y * delta)
			mesh_instance.rotate_z(tumble_speed.z * delta)
			
		# Floor Impact: Direct solid thud, no excessive bouncing
		if global_position.y <= floor_y:
			global_position.y = floor_y
			if bounce_count < 1 and abs(velocity.y) > 3.0:
				bounce_count += 1
				velocity.y = -velocity.y * 0.12 # single tiny micro-damp hop
				velocity.x = 0.0
				velocity.z = 0.0
				tumble_speed = Vector3.ZERO
			else:
				velocity = Vector3.ZERO
				tumble_speed = Vector3.ZERO
				is_grounded = true
				is_settled = true
				
				# Immediate flat rest on floor with quick subtle landing squish
				if mesh_instance:
					mesh_instance.rotation.x = 0.0
					mesh_instance.rotation.z = 0.0
					mesh_instance.position.y = 0.02
					var tw = create_tween()
					tw.tween_property(mesh_instance, "scale", Vector3(1.12, 0.80, 1.12), 0.03)
					tw.tween_property(mesh_instance, "scale", Vector3.ONE, 0.06).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
				
	# 3. State: Grounded (Resting flat and stable on the floor)
	else:
		ground_time += delta
		if mesh_instance and not is_settled:
			is_settled = true
			mesh_instance.rotation.x = 0.0
			mesh_instance.rotation.z = 0.0
			mesh_instance.position.y = 0.02

	# Auto sweep after 45 seconds to prevent performance drag
	if lifetime > 45.0:
		is_collecting = true

func collect_coin() -> void:
	if collected or is_merging: return
	collected = true
	if is_instance_valid(_shop_manager_ref) and _shop_manager_ref.has_method("add_coins"):
		_shop_manager_ref.add_coins(coin_value)
	if is_instance_valid(_sound_manager_ref):
		if _sound_manager_ref.has_method("play_coin_pickup"):
			_sound_manager_ref.play_coin_pickup(coin_value)
		elif _sound_manager_ref.has_method("play_pop"):
			_sound_manager_ref.play_pop(7)
	queue_free()
