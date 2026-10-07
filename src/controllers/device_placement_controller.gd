class_name DevicePlacementController
extends Node

signal prompt_requested(msg: String)
signal save_requested()
signal shop_refresh_requested()
signal close_shop_requested()

const DEVICE_SCENES = {
	"fan": preload("res://src/devices/fan.tscn"),
	"spike_wall": preload("res://src/devices/spike_wall.tscn"),
	"electric_wall": preload("res://src/devices/electric_wall.tscn"),
	"magnet_pylon": preload("res://src/devices/magnet_pylon.tscn"),
	"conveyor_crusher": preload("res://src/devices/conveyor_crusher.tscn"),
	"sentry_drone": preload("res://src/devices/sentry_drone.tscn")
}

var active_placed_devices: Array[Node3D] = []

var previous_room_size := Vector2.ZERO
var placement_error := ""
var range_ghost: MeshInstance3D

var grid_ghost: MeshInstance3D = null
var carried_device: Node3D = null
var carried_original_pos: Vector3 = Vector3.ZERO
var carried_original_rot_y: float = 0.0
var carried_placement_pos: Vector3 = Vector3.ZERO
var carried_placement_rot_y: float = 0.0
var is_carrying_new_purchase: bool = false
var carried_device_cost: int = 0
var is_wall_mounted: bool = false

var _main: Node3D = null
var player: CharacterBody3D = null
var env_main_room: Node3D = null
var shop_manager: Node = null
var game_manager: Node = null
var sound_manager: Node = null

func setup(main_node: Node3D) -> void:
	_main = main_node
	player = main_node.get_node_or_null("Player")
	env_main_room = main_node.get_node_or_null("Environment/MainRoom")
	shop_manager = main_node.get_node_or_null("ShopManager")
	game_manager = main_node.get_node_or_null("GameManager")
	sound_manager = main_node.get_node_or_null("SoundManager")
	previous_room_size = shop_manager.get_current_room_data().floor_size
	main_node.room_controller.room_layout_applied.connect(_room_changed)

func is_carrying() -> bool:
	return carried_device != null

func start_carrying_device(device_target: Variant, is_new: bool = false, purchase_cost: int = 0) -> void:
	var dev_node: Node3D = null
	if device_target is String:
		if DEVICE_SCENES.has(device_target) and env_main_room:
			dev_node = DEVICE_SCENES[device_target].instantiate()
			dev_node.set_meta("device_type", device_target)
			dev_node.add_to_group("devices")
			env_main_room.add_child(dev_node)
			is_new = true
	elif device_target is Node3D:
		dev_node = device_target
		
	if not dev_node or not is_instance_valid(dev_node): return
	if sound_manager: sound_manager.play_interaction("pickup", player.global_position)
	dev_node.visible = true
	carried_device = dev_node
	if "is_active" in dev_node: dev_node.is_active = false
	dev_node.process_mode = Node.PROCESS_MODE_DISABLED
	is_carrying_new_purchase = is_new
	carried_device_cost = purchase_cost
	carried_original_pos = dev_node.position
	carried_original_rot_y = dev_node.rotation.y
	carried_placement_rot_y = dev_node.rotation.y
	carried_placement_pos = dev_node.position
	var g = _get_or_create_grid_ghost()
	if g:
		g.global_position = dev_node.position
		g.rotation.y = carried_placement_rot_y
		
	if player:
		var hands = player.get_node_or_null("Head/Camera3D/Hands")
		if hands and hands.has_method("set_carrying_device"):
			hands.set_carrying_device(true)

func place_carried_device() -> void:
	if not carried_device: return
	placement_error = validate_position(carried_device, carried_placement_pos, carried_placement_rot_y)
	if placement_error != "":
		prompt_requested.emit(placement_error)
		return
	_destroy_grid_ghost()
	if player:
		var hands = player.get_node_or_null("Head/Camera3D/Hands")
		if hands and hands.has_method("set_carrying_device"):
			hands.set_carrying_device(false)
	if sound_manager and sound_manager.has_method("play_pop"):
		sound_manager.play_interaction("place", carried_placement_pos)
		
	var dev_to_drop = carried_device
	dev_to_drop.visible = true
	dev_to_drop.scale = Vector3.ONE
	dev_to_drop.process_mode = Node.PROCESS_MODE_INHERIT
	if "is_active" in dev_to_drop: dev_to_drop.is_active = true
	if dev_to_drop.has_meta("cargo_order"): dev_to_drop.remove_meta("cargo_order")
	var target_p = carried_placement_pos
	var target_r_y = carried_placement_rot_y
	carried_device = null
	is_carrying_new_purchase = false
	carried_device_cost = 0
	
	dev_to_drop.position = target_p
	dev_to_drop.rotation = Vector3(0, target_r_y, 0)

	if not active_placed_devices.has(dev_to_drop):
		active_placed_devices.append(dev_to_drop)
	
	save_requested.emit()

func cancel_carrying_device() -> void:
	if not carried_device: return
	_destroy_grid_ghost()
	if player:
		var hands = player.get_node_or_null("Head/Camera3D/Hands")
		if hands and hands.has_method("set_carrying_device"):
			hands.set_carrying_device(false)
	
	carried_device.visible = true
	carried_device.scale = Vector3.ONE
	carried_device.process_mode = Node.PROCESS_MODE_INHERIT
	if carried_device.has_meta("cargo_order"):
		var order_data: Dictionary = carried_device.get_meta("cargo_order")
		carried_device.queue_free()
		carried_device = null
		is_carrying_new_purchase = false
		_main.factory.return_package(order_data)
		return
	if "is_active" in carried_device: carried_device.is_active = true
	if is_carrying_new_purchase:
		var d_id = carried_device.get_meta("device_type") if carried_device.has_meta("device_type") else ""
		if shop_manager and shop_manager.devices.has(d_id):
			var d_data = shop_manager.devices[d_id]
			d_data["count"] = max(0, d_data.get("count", 1) - 1)
			if carried_device_cost > 0:
				shop_manager.coins += carried_device_cost
				shop_manager.coins_changed.emit(shop_manager.coins)
				
		active_placed_devices.erase(carried_device)
		carried_device.queue_free()
		carried_device = null
		
		prompt_requested.emit("Satın alma iptal edildi! " + str(carried_device_cost) + " Coin iade edildi.")
		is_carrying_new_purchase = false
		carried_device_cost = 0
		shop_refresh_requested.emit()
		save_requested.emit()
	else:
		carried_device.position = carried_original_pos
		carried_device.rotation.y = carried_original_rot_y
		carried_device.rotation.x = 0.0
		carried_device.rotation.z = 0.0
		carried_device = null
		is_carrying_new_purchase = false
		carried_device_cost = 0
		prompt_requested.emit("Taşıma iptal edildi, cihaz eski yerine bırakıldı.")

func rotate_carried_device(angle: float = PI * 0.25) -> void:
	carried_placement_rot_y += angle

func update_placement_process(delta: float) -> bool:
	if not carried_device or not player or not is_instance_valid(player):
		return false
		
	carried_device.visible = not player.is_ui_open
	if grid_ghost: grid_ghost.visible = not player.is_ui_open
	if range_ghost: range_ghost.visible = not player.is_ui_open
	if player.is_ui_open: return false
	var cam: Camera3D = player.get_node_or_null("Head/Camera3D")
	if not cam:
		return false
		
	var ray_orig = cam.global_position
	var ray_dir = -cam.global_transform.basis.z
	var dev_type = carried_device.get_meta("device_type") if carried_device.has_meta("device_type") else ""
	
	var room_w = 16.0
	var room_l = 16.0
	var ceiling_h = 6.0
	if shop_manager and shop_manager.has_method("get_current_room_data"):
		var r_data = shop_manager.get_current_room_data()
		room_w = r_data.get("floor_size", Vector2(16, 16)).x
		room_l = r_data.get("floor_size", Vector2(16, 16)).y
		ceiling_h = r_data.get("ceiling_height", 6.0)
		
	var half_w = room_w / 2.0
	var half_l = room_l / 2.0
	
	# Floor Placement (Default for all devices including Fan)
	var floor_plane = Plane(Vector3.UP, 0.05)
	var intersect = floor_plane.intersects_ray(ray_orig, ray_dir)
	var hit_pos = player.global_position + ray_dir * 3.5
	if intersect != null:
		var dist = ray_orig.distance_to(intersect)
		if dist < 12.0 and intersect.y <= (ray_orig.y + 0.5):
			hit_pos = intersect
	var bounds := placement_half_extents(carried_device, carried_placement_rot_y)
	var max_x := maxf(0.0, half_w - bounds.x - 0.4)
	var max_z := maxf(0.0, half_l - bounds.y - 0.4)
	# Snap first, then clamp so large devices can still be placed against room edges.
	var grid_step := 0.75
	var snap_x := clampf(round(hit_pos.x / grid_step) * grid_step, -max_x, max_x)
	var snap_z := clampf(round(hit_pos.z / grid_step) * grid_step, -max_z, max_z)
	carried_placement_pos = Vector3(snap_x, 0.05, snap_z)
	
	# Update Holographic Grid Ghost
	var g = _get_or_create_grid_ghost()
	if g:
		g.global_position = carried_placement_pos
		g.rotation.y = carried_placement_rot_y
		placement_error = validate_position(carried_device, carried_placement_pos, carried_placement_rot_y)
		var valid_color := Color(0.1, 0.9, 0.65, 0.35) if placement_error == "" else Color(1.0, 0.12, 0.08, 0.5)
		g.material_override.albedo_color = valid_color
		g.material_override.emission = valid_color
		var footprint_size := placement_local_size(carried_device)
		g.mesh.size = Vector3(footprint_size.x, 0.04, footprint_size.y)
		if not range_ghost:
			range_ghost = MeshInstance3D.new()
			var ring := TorusMesh.new()
			ring.rings = 64
			ring.ring_segments = 6
			range_ghost.mesh = ring
			range_ghost.material_override = g.material_override
			range_ghost.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			env_main_room.add_child(range_ghost)
		var radius := effect_radius(carried_device)
		range_ghost.mesh.inner_radius = maxf(0.05, radius - 0.04)
		range_ghost.mesh.outer_radius = radius + 0.04
		range_ghost.position = carried_placement_pos + Vector3(0, 0.05, 0)
		
	# Hold the Physical Device in Front of the Camera (Held in Hands)
	var bob = sin(Time.get_ticks_msec() * 0.0045) * 0.012
	var hand_offset = (-cam.global_transform.basis.z * 0.90) + (cam.global_transform.basis.y * (-0.28 + bob)) + (cam.global_transform.basis.x * 0.24)
	var target_hand_pos = cam.global_position + hand_offset
	carried_device.global_position = carried_device.global_position.lerp(target_hand_pos, delta * 22.0)
	
	carried_device.scale = Vector3.ONE * minf(0.22, 0.32 / footprint(carried_device))
	# Keep the hand preview's yaw equal to the orientation that will be placed.
	var target_rot_y := carried_placement_rot_y
	carried_device.global_rotation.y = lerp_angle(carried_device.global_rotation.y, target_rot_y, delta * 18.0)
	carried_device.global_rotation.x = lerp_angle(carried_device.global_rotation.x, cam.global_rotation.x * 0.3, delta * 18.0)
	carried_device.global_rotation.z = lerp_angle(carried_device.global_rotation.z, 0.0, delta * 18.0)
	
	var place_status := "Yerleştirilebilir" if placement_error == "" else "Yerleştirilemez: " + placement_error
	prompt_requested.emit("%s  |  Konum: %.1f, %.1f  |  Etki: %.1f m  |  [Sol Tık / E] Yerleştir  [R] Döndür  [Q] İptal" % [place_status, snap_x, snap_z, effect_radius(carried_device)])
	return true

func handle_input(event: InputEvent) -> bool:
	if player and player.is_ui_open: return false
	if carried_device == null:
		return false
		
	if event is InputEventMouseButton and event.pressed:
		if event.button_index == MOUSE_BUTTON_LEFT:
			place_carried_device()
			return true
		elif event.button_index == MOUSE_BUTTON_RIGHT:
			cancel_carrying_device()
			return true
	elif event is InputEventKey and event.pressed and not event.is_echo():
		if event.keycode == KEY_E:
			place_carried_device()
			return true
		elif event.keycode == KEY_Q or event.keycode == KEY_ESCAPE:
			cancel_carrying_device()
			return true
		elif event.keycode == KEY_R:
			rotate_carried_device(PI * 0.25)
			return true
			
	return false

func _get_or_create_grid_ghost() -> MeshInstance3D:
	if grid_ghost and is_instance_valid(grid_ghost):
		return grid_ghost
	grid_ghost = MeshInstance3D.new()
	var mesh = BoxMesh.new()
	mesh.size = Vector3(1.48, 0.08, 1.48)
	grid_ghost.mesh = mesh
	var mat = StandardMaterial3D.new()
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.albedo_color = Color(0.1, 0.85, 1.0, 0.45)
	mat.emission_enabled = true
	mat.emission = Color(0.1, 0.85, 1.0)
	mat.emission_energy_multiplier = 1.2
	grid_ghost.material_override = mat
	if env_main_room:
		env_main_room.add_child(grid_ghost)
	return grid_ghost

func _destroy_grid_ghost() -> void:
	if is_instance_valid(range_ghost): range_ghost.queue_free()
	range_ghost = null
	if grid_ghost and is_instance_valid(grid_ghost):
		grid_ghost.queue_free()
		grid_ghost = null

func upgrade_specific_device(d_node: Node3D) -> bool:
	if not d_node or not is_instance_valid(d_node) or not shop_manager: return false
	var d_type = d_node.get_meta("device_type") if d_node.has_meta("device_type") else ""
	if not shop_manager.devices.has(d_type): return false
	
	var d_data = shop_manager.devices[d_type]
	var cur_lvl = d_node.get("level") if ("level" in d_node) else 1
	if cur_lvl <= 0: cur_lvl = 1
	var max_lvl = mini(int(d_data.get("max_level", 6)), shop_manager.device_level_limit())
	if cur_lvl >= max_lvl:
		prompt_requested.emit(d_data.get("name", d_type) + " maksimum seviyede! (Sv. " + str(max_lvl) + ")")
		return false
		
	var cost: int = shop_manager.get_device_tech_cost(d_type, cur_lvl) if shop_manager.has_method("get_device_tech_cost") else 500
	var needed_pops = shop_manager.get_device_tech_req_pops(d_type, cur_lvl)
	
	if game_manager and game_manager.total_pops < needed_pops:
		prompt_requested.emit("Kilitli! Seviye " + str(cur_lvl + 1) + " için " + str(needed_pops) + " Pop gerekli!")
		return false
		
	if not shop_manager.can_afford(cost):
		prompt_requested.emit("Yetersiz Coin! Yükseltme için " + str(cost) + " Coin gerekli.")
		return false
		
	var invalid := validate_position(d_node, d_node.position, d_node.rotation.y, cur_lvl + 1)
	if invalid != "":
		prompt_requested.emit("Yükseltmeden önce cihazı taşı: " + invalid)
		return false
	if not shop_manager.spend_coins(cost): return false
	
	var next_lvl = cur_lvl + 1
	if d_node.has_method("setup_level"):
		d_node.setup_level(next_lvl)
	else:
		d_node.set("level", next_lvl)
		
	if sound_manager and sound_manager.has_method("play_pop"):
		sound_manager.play_interaction("confirm", d_node.global_position)
		
	if game_manager and game_manager.has_method("log_timeline_event"):
		game_manager.log_timeline_event("device_tech_inworld", d_type, d_data.get("name", d_type), next_lvl, cost)
		
	if "feedback" in d_node and is_instance_valid(d_node.feedback): d_node.feedback.pulse()
	
	save_requested.emit()
	shop_refresh_requested.emit()
	return true

func on_device_tech_upgraded(_device_id: String, _level: int) -> void:
	# Placeable devices own their levels. No catalog-wide propagation.
	shop_refresh_requested.emit()
	save_requested.emit()

func effect_radius(dev: Node3D, level_override: int = -1) -> float:
	var level: int = maxi(1, int(dev.get("level"))) if level_override < 0 else level_override
	if "trigger_radii" in dev: return dev.trigger_radii[clampi(level, 1, 6)]
	if "zap_radii" in dev: return dev.zap_radii[clampi(level, 1, 6)]
	if "pull_ranges" in dev: return dev.pull_ranges[clampi(level, 1, 6)]
	if "wind_range" in dev: return dev.ranges[clampi(level, 1, 6)]
	return 1.0

func footprint(dev: Node3D, level_override: int = -1) -> float:
	# Placement clearance follows the machine's physical body, not its much wider
	# working range. This keeps room fitting proportional as the rooms get smaller.
	match str(dev.get_meta("device_type", "")):
		"conveyor_crusher": return 1.3 # 2.4 x 1.6 m chassis
		"spike_wall": return effect_radius(dev, level_override) + 0.05 # The plate grows with its level.
		"electric_wall":
			var widths: Array = dev.get("fence_widths")
			var current_level := int(dev.get("level")) if level_override < 0 else level_override
			var fence_level := clampi(current_level, 1, widths.size() - 1) if not widths.is_empty() else 1
			return (float(widths[fence_level]) * 0.5 + 0.25) if not widths.is_empty() else 2.75
		"fan": return 0.75 # 1.1 m floor base; wall fans use wall snapping
		"magnet_pylon": return 0.65 # 1.1 m pedestal
		"sentry_drone": return 0.4 # 0.44 m body
	return 0.65

func placement_local_size(dev: Node3D, level_override: int = -1) -> Vector2:
	if str(dev.get_meta("device_type", "")) == "electric_wall":
		var widths: Array = dev.get("fence_widths")
		var current_level := int(dev.get("level")) if level_override < 0 else level_override
		var idx := clampi(current_level, 1, widths.size() - 1) if not widths.is_empty() else 1
		return Vector2(float(widths[idx]) if not widths.is_empty() else 5.0, 0.7)
	var side := footprint(dev, level_override) * 2.0
	return Vector2(side, side)

func placement_half_extents(dev: Node3D, angle: float, level_override: int = -1) -> Vector2:
	var local_size := placement_local_size(dev, level_override)
	var cos_y := absf(cos(angle))
	var sin_y := absf(sin(angle))
	return Vector2((local_size.x * cos_y + local_size.y * sin_y) * 0.5,
		(local_size.x * sin_y + local_size.y * cos_y) * 0.5)

func validate_position(dev: Node3D, pos: Vector3, angle: float, level_override: int = -1) -> String:
	var half: Vector2 = shop_manager.get_current_room_data().floor_size * 0.5
	var extents := placement_half_extents(dev, angle, level_override)
	var dev_type := str(dev.get_meta("device_type", ""))
	if not active_placed_devices.has(dev):
		if active_placed_devices.size() >= shop_manager.get_current_room_max_devices():
			return "Oda cihaz kapasitesi dolu (%d/%d)" % [active_placed_devices.size(), shop_manager.get_current_room_max_devices()]
		if shop_manager.devices.has(dev_type):
			var max_type_cnt = int(shop_manager.devices[dev_type].get("max_count", 6))
			var cur_type_cnt = 0
			for active_d in active_placed_devices:
				if is_instance_valid(active_d) and str(active_d.get_meta("device_type", "")) == dev_type:
					cur_type_cnt += 1
			if cur_type_cnt >= max_type_cnt:
				return "Bu cihazdan en fazla %d adet yerleştirilebilir" % max_type_cnt

	if absf(pos.x) + extents.x > half.x - 0.4 or absf(pos.z) + extents.y > half.y - 0.4:
		return "Cihaz oda sınırının dışında"
	if absf(pos.x) < extents.x + 2.5 and pos.z + extents.y > half.y - 3.2:
		return "Servis kapısının önünü boş bırak"
	for other in active_placed_devices:
		if not is_instance_valid(other) or other == dev or other.is_queued_for_deletion(): continue
		var other_extents := placement_half_extents(other, other.rotation.y)
		if absf(pos.x - other.position.x) < extents.x + other_extents.x + 0.15 and absf(pos.z - other.position.z) < extents.y + other_extents.y + 0.15:
			var other_type := str(other.get_meta("device_type", ""))
			if dev_type == "magnet_pylon" or other_type == "magnet_pylon":
				# Let a magnet sit inside another device's footprint. Keep it near
				# the host's center so this does not become a general overlap pass.
				var host: Node3D = other if dev_type == "magnet_pylon" else dev
				var host_level := int(host.get("level")) if "level" in host else 1
				var host_radius := footprint(host, host_level) * (absf(cos(host.rotation.y)) + absf(sin(host.rotation.y)))
				var magnet_radius := footprint(dev) if dev_type == "magnet_pylon" else footprint(other)
				var nested_limit := maxf(0.25, host_radius - magnet_radius - 0.15)
				if Vector2(pos.x - other.position.x, pos.z - other.position.z).length() <= nested_limit:
					continue
			return "Başka bir cihazla çakışıyor"
	var shape := BoxShape3D.new()
	shape.size = Vector3(extents.x * 2, 0.8, extents.y * 2)
	var query := PhysicsShapeQueryParameters3D.new()
	query.shape = shape
	query.transform = Transform3D(Basis(), pos + Vector3(0, 0.65, 0))
	query.collision_mask = 1
	query.exclude = [player.get_rid()]
	if not env_main_room.get_world_3d().direct_space_state.intersect_shape(query, 1).is_empty():
		return "Mobilya veya duvarla çakışıyor"
	return ""

func fit_devices_to_room(_room_id: String) -> void:
	# Search a bounded grid; devices that cannot fit are repacked without charging.
	var half: Vector2 = shop_manager.get_current_room_data().floor_size * 0.5
	var accepted := 0
	for dev in active_placed_devices.duplicate():
		if not is_instance_valid(dev) or dev == carried_device: continue
		if accepted >= shop_manager.get_current_room_max_devices():
			active_placed_devices.erase(dev)
			_main.factory.orders.append({"id": str(dev.get_meta("device_type")), "level": int(dev.level)})
			dev.queue_free()
			continue
		if validate_position(dev, dev.position, dev.rotation.y) == "":
			accepted += 1
			continue
		var placed := false
		var candidates: Array[Vector3] = []
		for z in range(int(-half.y + 2), int(half.y - 2), 2):
			for x in range(int(-half.x + 2), int(half.x - 2), 2):
				candidates.append(Vector3(x, 0.05, z))
		var origin: Vector3 = dev.position
		candidates.sort_custom(func(a: Vector3, b: Vector3): return a.distance_squared_to(origin) < b.distance_squared_to(origin))
		for candidate in candidates:
			if validate_position(dev, candidate, dev.rotation.y) == "":
				dev.position = candidate
				placed = true
				accepted += 1
				break

		if not placed:
			active_placed_devices.erase(dev)
			_main.factory.orders.append({"id": str(dev.get_meta("device_type")), "level": int(dev.level)})
			dev.queue_free()
	_main.factory.refresh()

func _room_changed(id: String) -> void:
	var size: Vector2 = shop_manager.get_current_room_data().floor_size
	# Translate the complete layout as one unit: fan directions and nested magnets
	# keep their relative distances while the layout follows the larger floor.
	if previous_room_size.x > 0 and previous_room_size != size and not active_placed_devices.is_empty():
		var center := Vector2.ZERO
		var count := 0
		for dev in active_placed_devices:
			if not is_instance_valid(dev) or dev == carried_device: continue
			center += Vector2(dev.position.x, dev.position.z)
			count += 1
		if count > 0:
			center /= float(count)
			var shift := center * (size / previous_room_size - Vector2.ONE)
			for dev in active_placed_devices:
				if is_instance_valid(dev) and dev != carried_device:
					dev.position += Vector3(shift.x, 0, shift.y)
	previous_room_size = size
	await get_tree().physics_frame
	await get_tree().physics_frame
	if shop_manager.current_room == id:
		fit_devices_to_room(id)
		save_requested.emit()

func device_stats(dev: Node3D, level: int) -> String:
	var radius := effect_radius(dev, level)
	if "cooldown_intervals" in dev:
		return "%.1f m / %.2f sn" % [radius, dev.cooldown_intervals[clampi(level, 1, 6)]]
	return "%.1f m / %.1f çekim" % [radius, dev.pull_strengths[clampi(level, 1, 6)]] if "pull_strengths" in dev else "%.1f m" % radius
