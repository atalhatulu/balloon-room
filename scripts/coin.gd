extends Area3D

var coin_value: int = 1
var velocity: Vector3 = Vector3.ZERO
var is_grounded: bool = false
var is_collecting: bool = false
var lifetime: float = 0.0
var bounce_count: int = 0
var floor_y: float = 0.08

@onready var mesh_instance: MeshInstance3D = $MeshInstance3D

func init(spawn_pos: Vector3, val: int = 1) -> void:
	global_position = spawn_pos
	coin_value = val
	velocity = Vector3(
		randf_range(-2.2, 2.2),
		randf_range(2.2, 4.5),
		randf_range(-2.2, 2.2)
	)

func _ready() -> void:
	add_to_group("coins")

func _process(delta: float) -> void:
	lifetime += delta
	
	# Gentle spinning
	if mesh_instance:
		mesh_instance.rotate_y(4.0 * delta)
		
	# Arc physics drop to floor with bouncing
	if not is_grounded:
		velocity.y -= 15.0 * delta
		global_position += velocity * delta
		if global_position.y <= floor_y:
			global_position.y = floor_y
			if bounce_count < 1 and abs(velocity.y) > 2.0:
				velocity.y = -velocity.y * 0.35
				velocity.x *= 0.6
				velocity.z *= 0.6
				bounce_count += 1
			else:
				velocity = Vector3.ZERO
				is_grounded = true
				
	var main_node = get_node_or_null("/root/Main")
	var player = main_node.get("player") if main_node else null
	
	if not is_collecting and player and is_instance_valid(player):
		var p_pos = player.global_position + Vector3(0, 0.9, 0)
		var dist = global_position.distance_to(p_pos)
		
		# Proximity rules:
		# If on the ground: full magnetic pickup range (3.4m + magnet upgrades)
		# If still falling mid-air: only collect if player is right next to it (< 0.85m) and coin has had time to drop (> 0.25s)
		if is_grounded:
			var magnet_lvl = player.get("magnet_level") if ("magnet_level" in player) else 0
			var magnet_unlocked = player.get("magnet_unlocked") if ("magnet_unlocked" in player) else false
			var pickup_range = 3.4 + (float(magnet_lvl) * 1.5 if magnet_unlocked else 0.0)
			if dist <= pickup_range:
				is_collecting = true
		else:
			if dist <= 0.85 and lifetime > 0.25:
				is_collecting = true
			
	if is_collecting:
		if player and is_instance_valid(player):
			var target_pos = player.global_position + Vector3(0, 0.9, 0)
			global_position = global_position.lerp(target_pos, clamp(16.0 * delta, 0.0, 1.0))
			if global_position.distance_to(target_pos) < 0.45:
				collect_coin()
		else:
			collect_coin()
		return
			
	# Auto sweep after 45 seconds to prevent forgotten clutter
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
