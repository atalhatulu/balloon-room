extends Node3D

# Orders reserve catalog capacity at checkout; opening a package never charges twice.
var portal: Node3D
var requires_wall_start := false
var waiting_for_clear := false
var warning_colors: Dictionary = {}
var warning_environment: Environment
var warning_ambient := Color.WHITE
var clearance_timer := 0.0

var main: Node
var orders: Array = []
var held: Dictionary = {}
var door_open := false
var door_moving := false
var controls: Dictionary = {}
var door_tween: Tween
var bay: Node3D
var gate: StaticBody3D
var package: Node3D
var held_mesh: MeshInstance3D
var display: Label3D
var half_length := 9.0
var target := ""
var notice := ""
var notice_until := 0

func setup(owner_node: Node) -> void:
	main = owner_node
	main.shop_manager.room_transfer_requested.connect(open_room_portal)
	main.room_controller.room_layout_applied.connect(rebuild)
	rebuild(main.shop_manager.current_room)

func box(parent: Node3D, pos: Vector3, size: Vector3, color: Color, solid := false, action := "") -> Node3D:
	var node: Node3D = StaticBody3D.new() if solid else Node3D.new()
	parent.add_child(node)
	node.position = pos
	var mesh := MeshInstance3D.new()
	var shape := BoxMesh.new()
	shape.size = size
	mesh.mesh = shape
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	mat.roughness = 0.6
	mesh.material_override = mat
	node.add_child(mesh)
	if solid:
		var collision := CollisionShape3D.new()
		var bounds := BoxShape3D.new()
		bounds.size = size
		collision.shape = bounds
		node.add_child(collision)
	if action != "": node.set_meta("factory_action", action)
	return node

func label(parent: Node3D, text: String, pos: Vector3, facing := 0.0) -> Label3D:
	var result := Label3D.new()
	parent.add_child(result)
	result.position = pos
	result.rotation.y = facing
	result.text = text
	result.font_size = 40
	result.pixel_size = 0.004
	result.outline_size = 5
	return result

func rebuild(_room_id: String) -> void:
	controls.clear()
	if bay:
		remove_child(bay)
		bay.queue_free()
	bay = Node3D.new()
	add_child(bay)
	var room: Dictionary = main.shop_manager.get_current_room_data()
	var size: Vector2 = room.floor_size
	var height: float = room.ceiling_height
	half_length = size.y * 0.5
	bay.position.z = half_length
	door_open = false
	door_moving = false
	if door_tween: door_tween.kill()
	# Replace the solid south wall with two jambs and a lintel.
	main.room_controller.wall_south_mesh.hide()
	main.room_controller.wall_south_shape.disabled = true
	var wall_color := Color(0.49, 0.57, 0.61)
	for side in [-1, 1]:
		box(bay, Vector3(side * (size.x / 4.0 + 0.75), height / 2.0, 0), Vector3(size.x / 2.0 - 1.5, height, 0.5), wall_color, true)
	box(bay, Vector3(0, (height + 3.2) / 2.0, 0), Vector3(3, height - 3.2, 0.5), wall_color, true)
	box(bay, Vector3(0, -0.15, 3.5), Vector3(8, 0.3, 7.5), Color(0.24, 0.29, 0.32), true)
	for side in [-1, 1]:
		box(bay, Vector3(side * 4, 2, 3.5), Vector3(0.25, 4, 7.5), wall_color, true)
	box(bay, Vector3(0, 2, 7), Vector3(8, 4, 0.25), wall_color, true)
	box(bay, Vector3(0, 4, 3.5), Vector3(8, 0.2, 7.5), wall_color)
	gate = box(bay, Vector3(0, 1.6, 0), Vector3(3, 3.2, 0.25), Color(0.07, 0.24, 0.30), true, "door")
	# Recessed door panels, viewing slit and a central seam move with the gate.
	for side in [-1, 1]:
		box(gate, Vector3(side * 0.73, 0, -0.14), Vector3(1.34, 2.95, 0.035), Color(0.13, 0.32, 0.37))
		box(gate, Vector3(side * 0.73, 0.55, -0.17), Vector3(0.90, 0.4, 0.025), Color(0.025, 0.10, 0.14))
		box(gate, Vector3(side * 0.73, 0.55, -0.19), Vector3(0.75, 0.035, 0.025), Color(0.18, 0.78, 0.81))
		for stripe in range(3):
			box(gate, Vector3(side * 0.73, -0.9 + stripe * 0.14, -0.17), Vector3(0.85, 0.035, 0.025), Color(0.06, 0.18, 0.22))
	box(gate, Vector3(0, 0, -0.18), Vector3(0.035, 3.1, 0.025), Color(0.02, 0.07, 0.09))
	label(gate, "SERVİS / 01", Vector3(0, -0.1, -0.20), PI)
	for side in [-1, 1]:
		box(bay, Vector3(side * 1.6, 1.6, -0.1), Vector3(0.15, 3.3, 0.35), Color(0.95, 0.58, 0.12))
		box(bay, Vector3(side * 1.9, 1.3, 0.4), Vector3(0.3, 0.5, 0.25), Color(0.12, 0.64, 0.73), true, "door")
	# Balloon-only barrier keeps existing balloons in the lab when the gate opens.
	var barrier := StaticBody3D.new()
	bay.add_child(barrier)
	barrier.collision_layer = 8
	barrier.collision_mask = 2
	var barrier_shape := CollisionShape3D.new()
	var bounds := BoxShape3D.new()
	bounds.size = Vector3(3, 3.2, 0.15)
	barrier_shape.shape = bounds
	barrier_shape.position.y = 1.6
	barrier.add_child(barrier_shape)
	box(bay, Vector3(2.1, 1.35, -0.65), Vector3(0.5, 0.65, 0.3), Color(0.90, 0.35, 0.08), true, "production")
	box(bay, Vector3(-2.1, 1.35, -0.65), Vector3(0.5, 0.65, 0.3), Color(0.12, 0.64, 0.73), true, "door")
	label(bay, "SERVİS KAPISI\n[E] AÇ / KAPAT", Vector3(-2.1, 2.2, -0.84), PI)
	display = label(bay, "", Vector3(2.1, 2.2, -0.84), PI)

	label(bay, "TESLİMAT NOKTASI", Vector3(0, 2.8, 6.8), PI)
	for side in [-1, 1]:
		box(bay, Vector3(side * 2.1, 1.35, -0.82), Vector3(0.46, 0.60, 0.055), Color(0.045, 0.09, 0.12))
		var button := MeshInstance3D.new()
		var cylinder := CylinderMesh.new()
		cylinder.top_radius = 0.13
		cylinder.bottom_radius = 0.13
		cylinder.height = 0.085
		cylinder.radial_segments = 24
		button.mesh = cylinder
		button.rotation.x = PI / 2
		button.position = Vector3(side * 2.1, 1.37, -0.9)
		var button_mat := StandardMaterial3D.new()
		button_mat.albedo_color = Color(0.95, 0.32, 0.08) if side > 0 else Color(0.08, 0.72, 0.82)
		button_mat.emission_enabled = true
		button_mat.emission = button_mat.albedo_color
		button_mat.emission_energy_multiplier = 0.3
		button.material_override = button_mat
		bay.add_child(button)
		controls["production" if side > 0 else "door"] = button
		label(bay, "DURDUR / BAŞLAT" if side > 0 else "AÇ / KAPAT", Vector3(side * 2.1, 1.16, -0.86), PI).pixel_size = 0.001
	var light := OmniLight3D.new()
	bay.add_child(light)
	light.position = Vector3(0, 3.5, 3.5)
	light.omni_range = 9
	light.light_energy = 2.0
	light.shadow_enabled = false
	package = box(bay, Vector3(0, 0.64, 5), Vector3(1.2, 1, 0.9), Color(0.65, 0.40, 0.18), true, "cargo")
	box(package, Vector3(0, 0.51, 0), Vector3(0.15, 0.012, 0.9), Color(0.94, 0.80, 0.48))
	label(package, "KARGO", Vector3(0, 0.08, -0.46), PI)
	# Marked receiving pallet and compact shelving make the bay readable.
	for x in [-0.55, 0.55]:
		box(bay, Vector3(x, 0.08, 5), Vector3(0.18, 0.16, 1.25), Color(0.35, 0.23, 0.13))
	for z in range(5):
		box(bay, Vector3(0, 0.15, 4.5 + z * 0.25), Vector3(1.6, 0.04, 0.18), Color(0.60, 0.43, 0.24))
	for x in [-1.15, 1.15]:
		box(bay, Vector3(x, 0.012, 5), Vector3(0.05, 0.02, 2), Color(0.94, 0.65, 0.18))
	for z in [4.0, 6.0]:
		box(bay, Vector3(0, 0.012, z), Vector3(2.3, 0.02, 0.05), Color(0.94, 0.65, 0.18))
	for x in [-3.2, 3.2]:
		box(bay, Vector3(x, 0.55, 5.8), Vector3(0.85, 1.1, 1.7), Color(0.07, 0.16, 0.19), true)
		for y in [0.6, 1.15]:
			box(bay, Vector3(x, y, 5.8), Vector3(0.95, 0.055, 1.8), Color(0.42, 0.55, 0.58))
		box(bay, Vector3(x, 1.42, 6.2), Vector3(0.6, 0.5, 0.55), Color(0.37, 0.43, 0.45))
	refresh()

func refresh() -> void:
	if not bay: return
	display.text = ("ÜRETİM AÇIK\n[E] DURDUR" if main.game_manager.production_enabled else "ÜRETİM DURDU\n[E] BAŞLAT") + "\nKargo: %d" % orders.size()
	if waiting_for_clear: display.text = "GEÇİŞ HAZIRLIĞI\nKalan balon: %d\nOdayı temizle" % main.game_manager.get_physical_balloon_count()
	package.visible = not orders.is_empty()
	package.get_child(1).set_deferred("disabled", orders.is_empty())

func tell(message: String, rejected := true) -> void:
	if main.sound_manager: main.sound_manager.play_interaction("denied" if rejected else "confirm", main.player.global_position)
	notice = message
	notice_until = Time.get_ticks_msec() + 2600

func toggle_production(from_wall_button := false) -> void:
	if controls.has("production"): preload("res://src/environment/interaction_feedback.gd").press(controls.production)
	if main.is_blackout:
		tell("Elektrik kesik. Önce elektrik panosundan şebekeyi aç.")
		return
	if main.shop_manager.pending_room != "":
		tell("Üretim kilitli. Portal için odadaki balonları temizle." if waiting_for_clear else "Üretim kilitli. Odanın ortasındaki portaldan geç.")
		return
	if requires_wall_start and not from_wall_button:
		tell("Yeni odada üretimi kapı yanındaki BAŞLAT düğmesinden aç.")
		return
	if not main.game_manager.production_enabled and (door_open or door_moving or main.player.position.z > half_length - 0.6):
		tell("Önce içeri gir ve servis kapısını kapat.")
		return
	if main.sound_manager and main.sound_manager.has_method("play_button_click"):
		main.sound_manager.play_interaction("button", bay.global_position)
	requires_wall_start = false
	main.game_manager.production_enabled = not main.game_manager.production_enabled
	main.game_manager.spawn_accumulator = 0.0
	refresh()
	main.save_current_data()

func toggle_door() -> void:
	if controls.has("door"): preload("res://src/environment/interaction_feedback.gd").press(controls.door)
	if door_moving: return
	if main.game_manager.production_enabled:
		tell("Kapı kilitli: önce turuncu düğmeden üretimi durdur.")
		return
	if door_open and absf(main.player.position.z - half_length) < 0.85 and absf(main.player.position.x) < 1.9:
		tell("Kapı eşiğinden uzaklaş.")
		return
	if main.sound_manager and main.sound_manager.has_method("play_button_click"):
		main.sound_manager.play_interaction("button", bay.global_position)
	if main.sound_manager and main.sound_manager.has_method("play_door_slide"):
		main.sound_manager.play_interaction("door", bay.global_position)
	door_open = not door_open
	gate.get_child(1).set_deferred("disabled", false)
	door_moving = true
	door_tween = create_tween()
	door_tween.tween_property(gate, "position:y", 4.7 if door_open else 1.6, 0.65).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN_OUT)
	door_tween.tween_callback(func():
		door_moving = false
		gate.get_child(1).set_deferred("disabled", door_open)
		main.sound_manager.play_interaction("button", bay.global_position)
	)

func order(device_id: String, level: int) -> void:
	# Orders remain in the delivery queue; unpacking requires explicit player input.
	orders.append({"id": device_id, "level": level})
	refresh()
	tell("Sipariş teslim edildi. Üretimi durdurup kargo alanından al.", false)
	main.save_current_data()

func interact(action: String) -> void:
	match action:
		"production": toggle_production(true)
		"door": toggle_door()
		"cargo":
			if orders.is_empty() or not held.is_empty(): return
			main.sound_manager.play_interaction("pickup", package.global_position)
			held = orders.pop_front()
			show_held()
			refresh()
			main.save_current_data()
		"unpack":
			if held.is_empty() or main.player.position.z > half_length - 1.2: return
			main.sound_manager.play_interaction("unpack", main.player.global_position)
			var id: String = held.id
			main.device_placement.start_carrying_device(id)
			var dev: Node3D = main.device_placement.carried_device
			dev.set_meta("cargo_order", held.duplicate())
			dev.setup_level(maxi(1, int(held.get("level", 1))))
			dev.is_active = false
			held = {}
			if held_mesh: held_mesh.queue_free(); held_mesh = null

func show_held() -> void:
	if held_mesh: held_mesh.queue_free()
	held_mesh = MeshInstance3D.new()
	var mesh := BoxMesh.new()
	mesh.size = Vector3(0.55, 0.38, 0.38)
	held_mesh.mesh = mesh
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.68, 0.43, 0.21)
	held_mesh.material_override = mat
	main.player.get_node("Head/Camera3D").add_child(held_mesh)
	held_mesh.position = Vector3(0, -0.3, -0.65)
	main.player.get_node("Head/Camera3D/Hands").set_carrying_device(true)

func return_package(order_data: Dictionary) -> void:
	orders.push_front(order_data)
	refresh()
	main.save_current_data()

func update_prompt() -> bool:
	target = ""
	if held_mesh: held_mesh.visible = not main.player.is_ui_open
	if main.player.is_ui_open: return false
	var cam: Camera3D = main.player.get_node("Head/Camera3D")
	var query := PhysicsRayQueryParameters3D.create(cam.global_position, cam.global_position - cam.global_basis.z * 3.8, 1)
	query.exclude = [main.player.get_rid()]
	var hit := get_world_3d().direct_space_state.intersect_ray(query)
	if not hit.is_empty(): target = str(hit.collider.get_meta("factory_action", ""))
	if target == "" and not held.is_empty() and main.player.position.z < half_length - 1.2: target = "unpack"
	var prompts := {"production": "[E] Üretimi durdur / başlat", "door": "[E] Servis kapısını aç / kapat", "cargo": "[E] Kargoyu al (%d paket)" % orders.size(), "unpack": "[E] Paketi aç ve cihazı yerleştir"}
	if target != "" or Time.get_ticks_msec() < notice_until:
		main.raycast_target_type = ""
		main.raycast_target_device = null
		main.nearby_device = null
		main.desk_prompt.text = notice if Time.get_ticks_msec() < notice_until else prompts.get(target, "")
		main.desk_prompt.show()
		return true
	return false

func save_state() -> Dictionary:
	var pending := orders.duplicate(true)
	if not held.is_empty(): pending.push_front(held.duplicate())
	var dev = main.device_placement.carried_device
	if is_instance_valid(dev) and dev.has_meta("cargo_order"): pending.push_front(dev.get_meta("cargo_order"))
	return {"production": main.game_manager.production_enabled, "orders": pending, "pending_room": main.shop_manager.pending_room, "requires_wall_start": requires_wall_start}

func restore(state: Dictionary) -> void:
	set_transfer_lighting(false)
	waiting_for_clear = false
	if is_instance_valid(portal): portal.queue_free()
	portal = null
	main.shop_manager.pending_room = ""
	requires_wall_start = bool(state.get("requires_wall_start", false))
	orders = state.get("orders", []).duplicate(true)
	held = {}
	if held_mesh: held_mesh.queue_free(); held_mesh = null
	main.player.get_node("Head/Camera3D/Hands").set_carrying_device(false)
	main.game_manager.production_enabled = state.get("production", true)
	door_open = false
	door_moving = false
	if door_tween: door_tween.kill()
	gate.position.y = 1.6
	gate.get_child(1).set_deferred("disabled", false)
	refresh()

	var pending_room: String = str(state.get("pending_room", ""))
	if pending_room != main.shop_manager.current_room and main.shop_manager.rooms.has(pending_room) and main.shop_manager.is_room_unlocked(pending_room):
		main.shop_manager.pending_room = pending_room
		open_room_portal(pending_room, false)
	if requires_wall_start:
		main.game_manager.production_enabled = false
	refresh()

func open_room_portal(room_id: String, save_now := true) -> void:
	main.game_manager.production_enabled = false
	main.game_manager.spawn_accumulator = 0.0
	requires_wall_start = true
	if is_instance_valid(portal): portal.queue_free()
	portal = null
	waiting_for_clear = true
	set_transfer_lighting(true)
	if main.game_manager.get_physical_balloon_count() == 0:
		spawn_transfer_portal(room_id)
	elif main.hud_controller:
		main.hud_controller.show_prompt("Üretim durdu. Portalın açılması için odadaki balonları temizle.", 5.0)
	refresh()
	main.update_all_shop_cards()
	if save_now: main.save_current_data()

func spawn_transfer_portal(room_id: String) -> void:
	if is_instance_valid(portal) or main.game_manager.get_physical_balloon_count() > 0: return
	waiting_for_clear = false
	portal = preload("res://src/environment/room_portal.gd").new()
	add_child(portal)
	portal.setup(main, room_id)
	refresh()
	main.update_all_shop_cards()
	if main.hud_controller:
		main.hud_controller.show_prompt("Oda temizlendi. Ortadaki portaldan yeni odaya geç.", 5.0)

func set_transfer_lighting(enabled: bool) -> void:
	if main.get_node_or_null("LightingModes"): return
	if enabled:
		if not warning_colors.is_empty(): return
		for light in [main.get_node_or_null("MainRoomLight"), main.get_node_or_null("DirectionalLight3D")]:
			if light is Light3D: warning_colors[light] = light.light_color
		var world = main.get_node_or_null("WorldEnvironment")
		if world and world.environment:
			warning_environment = world.environment
			warning_ambient = warning_environment.ambient_light_color
	else:
		for light in warning_colors:
			if is_instance_valid(light): light.light_color = warning_colors[light]
		warning_colors.clear()
		if warning_environment: warning_environment.ambient_light_color = warning_ambient
		warning_environment = null

func _process(delta: float) -> void:
	if not main or main.is_loading_save or get_tree().paused: return
	if main.shop_manager.pending_room == "": return
	if not main.is_blackout:
		for light in warning_colors:
			if is_instance_valid(light): light.light_color = Color.WHITE
		if warning_environment:
			warning_environment.ambient_light_color = Color.WHITE
	clearance_timer += delta
	if not waiting_for_clear or clearance_timer < 0.2: return
	clearance_timer = 0.0
	_cleanup_escaped_transfer_balloons()
	# Portal creation itself requires an empty room. The former <= 5 threshold
	# could never pass spawn_transfer_portal's > 0 guard and strand the run.
	if main.game_manager.get_physical_balloon_count() == 0:
		spawn_transfer_portal(main.shop_manager.pending_room)
	refresh()

func _cleanup_escaped_transfer_balloons() -> void:
	if not main.balloon_container or not main.shop_manager: return
	var room: Dictionary = main.shop_manager.get_current_room_data()
	var size: Vector2 = room.get("floor_size", Vector2(18.0, 18.0))
	var half_w := size.x * 0.5
	var half_l := size.y * 0.5
	for balloon in main.balloon_container.get_children():
		if not (balloon is RigidBody3D) or not is_instance_valid(balloon) or balloon.is_queued_for_deletion() or balloon.get("is_popped"): continue
		var pos: Vector3 = balloon.global_position
		if absf(pos.x) <= half_w + 1.0 and absf(pos.z) <= half_l + 1.0 and pos.y >= -0.4: continue
		# A body that escaped the room cannot be popped by the player. Remove it
		# without rewards, and reconcile the weighted room-pressure counter.
		balloon.set("is_popped", true)
		var tier_value := maxi(1, int(balloon.get("tier_value")))
		main.game_manager.active_balloons = maxi(0, main.game_manager.active_balloons - tier_value)
		balloon.hide()
		balloon.queue_free()
	main.game_manager.active_count_changed.emit(main.game_manager.active_balloons, main.game_manager.max_room_balloons)

func complete_room_transfer(room_id: String) -> void:
	if room_id != main.shop_manager.pending_room or waiting_for_clear: return
	set_transfer_lighting(false)
	main.shop_manager.pending_room = ""
	portal = null
	main.game_manager.production_enabled = false
	main.game_manager.spawn_accumulator = 0.0
	main.shop_manager.switch_to_room(room_id)
	refresh()
	main.save_current_data()
