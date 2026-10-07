extends SceneTree
var failures := 0
var main: Node3D
func check(ok: bool, message: String) -> void:
	if not ok:
		failures += 1
		push_error(message)
	else: print("PASS: ", message)
func _init() -> void:
	if not OS.get_environment("XDG_DATA_HOME").begins_with("/tmp/balloon-room-"):
		quit(2)
		return
	run.call_deferred()
func balloon(pos: Vector3, frozen := true) -> Node3D:
	var b = load("res://src/entities/balloon.tscn").instantiate()
	main.balloon_container.add_child(b)
	b.position = pos
	b.freeze = frozen
	b.gravity_scale = 0
	return b
func run() -> void:
	main = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	await process_frame
	paused = false
	main.is_loading_save = true
	main.set_process(false)
	main.game_manager.set_process(false)
	main.bonus_controller.set_process(false)
	main.startup_modal.hide()
	main.player.set_ui_open(false)
	main.player.set_physics_process(false)
	main.game_manager.total_pops = 12000
	main.shop_manager.coins = 100000
	main.shop_manager.current_room = "medium_room"
	main.shop_manager.unlocked_rooms = ["small_room", "medium_room"]
	main.apply_room_layout("medium_room")
	main.shop_ui.update_all_shop_cards()
	main.shop_ui.set_category_filter("devices")
	check(main.shop_ui.btn_tab_devices.visible and main.shop_ui.upgrades_container.get_node("CardFan").visible, "Facility exposes fan in automation catalog")
	var magnet_host = load("res://src/devices/spike_wall.tscn").instantiate()
	magnet_host.set_meta("device_type", "spike_wall")
	main.env_main_room.add_child(magnet_host)
	magnet_host.position = Vector3(0, 0.05, 0)
	magnet_host.setup_level(1)
	main.active_placed_devices.append(magnet_host)
	var nested_magnet = load("res://src/devices/magnet_pylon.tscn").instantiate()
	nested_magnet.set_meta("device_type", "magnet_pylon")
	main.env_main_room.add_child(nested_magnet)
	check(main.device_placement.validate_position(nested_magnet, Vector3(0.2, 0.05, 0), 0.0) == "", "Magnet can be nested near the center of another placed device")
	check(main.device_placement.validate_position(nested_magnet, Vector3(1.3, 0.05, 0), 0.0) == "Başka bir cihazla çakışıyor", "Magnet cannot overlap beyond the host device's interior")
	main.active_placed_devices.erase(magnet_host)
	magnet_host.queue_free()
	nested_magnet.queue_free()
	check(not main.shop_manager.buy_device_unit("fan", 12000), "Fan is locked until a crusher is purchased")
	check(main.shop_manager.buy_device_unit("spike_wall", 12000), "First automation tier purchases the crusher")
	check(main.shop_manager.buy_device_unit("fan", 12000) and main.factory.orders.size() == 2, "Crusher purchase unlocks the fan cargo order")
	main.device_placement.start_carrying_device("fan", true)
	var carried = main.device_placement.carried_device
	check(is_instance_valid(carried) and carried.has_method("toggle"), "Fan exists in placement scene registry")
	main.device_placement.cancel_carrying_device()
	# Controlled physics test above the room, free of existing furniture.
	var fan = load("res://src/devices/fan.tscn").instantiate()
	fan.set_meta("device_type", "fan")
	main.env_main_room.add_child(fan)
	fan.position = Vector3(0, 30, 0)
	fan.set_physics_process(false)
	main.active_placed_devices.append(fan)
	var b = balloon(Vector3(0, 31.7, -3), false)
	await physics_frame
	await physics_frame
	fan._physics_process(0.04)
	await physics_frame
	await physics_frame
	check(b.linear_velocity.z < 0 and not b.is_popped, "Fan pushes a real balloon forward without popping")
	check(fan.feedback.recent_contacts.size() == 1, "Fan reports actual contact, not fabricated pops")
	b.queue_free()
	# Burst accounting uses actual victims; the advertised cap is a ceiling.
	for kind in ["spike_wall", "electric_wall"]:
		var device = main.DEVICE_SCENES[kind].instantiate()
		main.env_main_room.add_child(device)
		device.position = Vector3(20, 30, 0)
		device.setup_level(1)
		device.set_physics_process(false)
		var targets: Array = []
		for i in range(12): targets.append(balloon(Vector3(19.4 + (i % 4) * 0.4, 30.6, -0.4 + (i / 4) * 0.4)))
		await physics_frame
		await physics_frame
		if kind == "spike_wall": device.execute_spike_thrust()
		else: device.process_electric_discharge()
		var popped := 0
		for target in targets:
			if target.is_popped: popped += 1
		check(popped == 12 and device.feedback.last_output() == 12, kind + " reports exactly 12 physical pops from 12 targets")
		device.queue_free()
		await process_frame
	# Confirm saved fan no longer disappears in the retired-device cleanup.
	fan.position = Vector3(4, 0.05, -4)
	main.is_loading_save = false
	main.save_current_data()
	main.load_saved_data()
	var restored := false
	for device in main.active_placed_devices:
		if device.get_meta("device_type", "") == "fan": restored = true
	check(restored, "Saved fan survives reload")
	main.game_manager.is_game_started = false
	main.queue_free()
	await process_frame
	print("AUTOMATION CONSISTENCY: ", failures, " failures")
	quit(1 if failures else 0)
