extends Area3D

var coin_value: int = 1
var velocity: Vector3 = Vector3.ZERO
var tumble_speed: Vector3 = Vector3.ZERO
var is_grounded: bool = false
var is_settled: bool = false
var is_collecting: bool = false
var lifetime: float = 0.0
var ground_time: float = 0.0
var bounce_count: int = 0
var floor_y: float = 0.08
var collect_speed: float = 2.0

@onready var mesh_instance: MeshInstance3D = $MeshInstance3D

func init(spawn_pos: Vector3, val: int = 1) -> void:
	global_position = spawn_pos
	coin_value = val
	
	# Dynamic explosive burst arc
	velocity = Vector3(
		randf_range(-2.6, 2.6),
		randf_range(3.5, 6.2),
		randf_range(-2.6, 2.6)
	)
	
	# Organic multi-axis tumbling rotation in flight
	tumble_speed = Vector3(
		randf_range(-14.0, 14.0),
		randf_range(8.0, 16.0),
		randf_range(-14.0, 14.0)
	)
	
	# Initial spawn squash and stretch
	var target_scale = Vector3(1.25, 1.25, 1.25) if val >= 10 else Vector3.ONE
	scale = target_scale * 0.4
	var tween = create_tween()
	tween.tween_property(self, "scale", target_scale, 0.12).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)

func _ready() -> void:
	add_to_group("coins")

func _process(delta: float) -> void:
	lifetime += delta
	
	var main_node = get_node_or_null("/root/Main")
	var player = main_node.get("player") if main_node else null
	
	# Check for magnetic attraction to player
	if not is_collecting and player and is_instance_valid(player):
		var p_pos = player.global_position + Vector3(0, 0.9, 0)
		var dist = global_position.distance_to(p_pos)
		
		if is_grounded:
			var pickup_range = player.get("magnet_range") if ("magnet_range" in player) else 3.5
			if dist <= pickup_range:
				is_collecting = true
		else:
			# Mid-air catch only if player is right on top of it after initial burst
			if dist <= 0.9 and lifetime > 0.3:
				is_collecting = true
				
	# 1. State: Collecting (Accelerating Swoop & Scale into Player)
	if is_collecting:
		if player and is_instance_valid(player):
			var target_pos = player.global_position + Vector3(0, 0.9, 0)
			collect_speed = move_toward(collect_speed, 24.0, 48.0 * delta)
			
			var dir = (target_pos - global_position).normalized()
			global_position += dir * collect_speed * delta
			
			if mesh_instance:
				mesh_instance.rotate_y(16.0 * delta)
			scale = scale.lerp(Vector3(0.2, 0.2, 0.2), 12.0 * delta)
			
			if global_position.distance_to(target_pos) < 0.5:
				collect_coin()
		else:
			collect_coin()
		return
		
	# 2. State: Falling in Air (Realistic Gravity, Air Drag & 3D Tumble)
	if not is_grounded:
		velocity.y -= 16.0 * delta
		velocity.x = move_toward(velocity.x, 0.0, 1.6 * delta)
		velocity.z = move_toward(velocity.z, 0.0, 1.6 * delta)
		global_position += velocity * delta
		
		# Multi-axis tumbling through the air
		if mesh_instance:
			mesh_instance.rotate_x(tumble_speed.x * delta)
			mesh_instance.rotate_y(tumble_speed.y * delta)
			mesh_instance.rotate_z(tumble_speed.z * delta)
			
		# Floor Impact & Organic Double Bounce
		if global_position.y <= floor_y:
			global_position.y = floor_y
			if bounce_count < 2 and abs(velocity.y) > 1.4:
				bounce_count += 1
				var b_factor = 0.45 if bounce_count == 1 else 0.25
				velocity.y = -velocity.y * b_factor
				velocity.x *= 0.55
				velocity.z *= 0.55
				tumble_speed *= 0.45
			else:
				velocity = Vector3.ZERO
				is_grounded = true
				
	# 3. State: Grounded (Quick settle to completely flat, resting stationary state)
	else:
		ground_time += delta
		if mesh_instance:
			if not is_settled:
				# Spin-down and flatten to the floor in 0.35s
				tumble_speed = tumble_speed.lerp(Vector3.ZERO, 10.0 * delta)
				mesh_instance.rotate_y(tumble_speed.y * delta)
				mesh_instance.rotation.x = lerp_angle(mesh_instance.rotation.x, 0.0, 14.0 * delta)
				mesh_instance.rotation.z = lerp_angle(mesh_instance.rotation.z, 0.0, 14.0 * delta)
				mesh_instance.position.y = lerp(mesh_instance.position.y, 0.02, 14.0 * delta)
				if ground_time >= 0.35:
					is_settled = true
					mesh_instance.rotation.x = 0.0
					mesh_instance.rotation.z = 0.0
					mesh_instance.position.y = 0.02
			# Once settled: completely still and flat on the floor (no continuous spinning or wobbling)

	# Auto sweep after 45 seconds to prevent performance drag
	if lifetime > 45.0:
		is_collecting = true

func collect_coin() -> void:
	var main_node = get_node_or_null("/root/Main")
	if main_node:
		if main_node.get("shop_manager") and main_node.shop_manager.has_method("add_coins"):
			main_node.shop_manager.add_coins(coin_value)
		if main_node.get("sound_manager") and main_node.sound_manager.has_method("play_pop"):
			main_node.sound_manager.play_pop(7) # High chime
	queue_free()
