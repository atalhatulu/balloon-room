extends SceneTree
var failures := 0
var checks := 0
func check(ok: bool, description: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		push_error(description)
	else: print("PASS: ", description)
func _init() -> void:
	if not OS.get_environment("XDG_DATA_HOME").begins_with("/tmp/balloon-room-"):
		quit(2)
		return
	run.call_deferred()
func run() -> void:
	root.size = Vector2i(1280, 720)
	var main = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	await process_frame
	paused = false
	main.is_loading_save = true
	main.set_process(false)
	main.startup_modal.hide()
	main.player.set_ui_open(false)
	main.player.set_physics_process(false)
	main.game_manager.is_game_started = false
	main.shop_manager.coins = 1000000
	main.game_manager.total_pops = 1000000
	var factory = main.factory
	var placement = main.device_placement
	factory.toggle_door()
	check(not factory.door_open, "Running production locks service door")
	factory.toggle_production()
	var before: int = main.game_manager.get_physical_balloon_count()
	main.drop_balloons_from_vent(10)
	check(main.game_manager.get_physical_balloon_count() == before, "Stopped production rejects direct spawning")
	factory.toggle_door()
	await create_timer(0.45).timeout
	check(factory.door_open, "Stopped production allows door to open")
	factory.toggle_production()
	check(not main.game_manager.production_enabled, "Open door prevents restart")
	await physics_frame
	var player_shape: Shape3D = main.player.get_node("CollisionShape3D").shape
	var query := PhysicsShapeQueryParameters3D.new()
	query.shape = player_shape
	query.transform.origin = Vector3(0, 1.3, factory.half_length)
	query.collision_mask = main.player.collision_mask
	query.exclude = [main.player.get_rid()]
	check(main.get_world_3d().direct_space_state.intersect_shape(query).is_empty(), "Open doorway physically passable by player")
	var barrier_ray := PhysicsRayQueryParameters3D.create(Vector3(0, 1.5, 8), Vector3(0, 1.5, 10), 8)
	check(not main.get_world_3d().direct_space_state.intersect_ray(barrier_ray).is_empty(), "Balloon-only barrier remains across open door")
	main.shop_manager.current_room = "medium_room"
	main.apply_room_layout("medium_room")
	await physics_frame
	var coins_before: int = main.shop_manager.coins
	var price: int = main.shop_manager.get_device_unit_cost("spike_wall", 0)
	main.shop_manager.buy_device_unit("spike_wall", main.game_manager.total_pops)
	check(factory.orders.size() == 1 and placement.active_placed_devices.is_empty(), "Purchased device arrives as cargo, not installed")
	check(main.shop_manager.coins == coins_before - price and main.shop_manager.devices.spike_wall.count == 1, "Order charges once and reserves one slot")
	main.player.position = Vector3(0, 0.6, factory.half_length + 4)
	factory.interact("cargo")
	check(factory.orders.is_empty() and factory.held.id == "spike_wall", "Cargo can be carried back from delivery bay")
	factory.interact("unpack")
	check(not placement.is_carrying(), "Cannot unpack outside the lab")
	check(factory.save_state().orders.size() == 1, "Held cargo is durable across saves")
	main.player.position = Vector3(0, 0.6, 3)
	factory.interact("unpack")
	check(placement.is_carrying() and not placement.carried_device.is_active, "Unpacked device remains inactive while carried")
	check(factory.save_state().orders.size() == 1, "Unplaced device persists as cargo")
	placement.carried_placement_pos = Vector3(0, 0.05, factory.half_length - 2.0)
	placement.place_carried_device()
	check(placement.is_carrying(), "Doorway cannot be obstructed by a device")
	placement.carried_placement_pos = Vector3(0, 0.05, 0)
	placement.place_carried_device()
	check(not placement.is_carrying() and placement.active_placed_devices.size() == 1, "Valid placement installs the device")
	var installed = placement.active_placed_devices[0]
	check(installed.is_active and installed.scale == Vector3.ONE, "Placed device resumes at full size")
	check(factory.save_state().orders.is_empty(), "Placed package removed from pending cargo")
	main.shop_manager.buy_device_unit("spike_wall", main.game_manager.total_pops)
	factory.interact("cargo")
	factory.interact("unpack")
	placement.carried_placement_pos = Vector3(0, 0.05, 0)
	placement.place_carried_device()
	check(placement.is_carrying(), "Overlapping device placement rejected")
	placement.cancel_carrying_device()
	check(factory.orders.size() == 1 and main.shop_manager.devices.spike_wall.count == 2, "Cancelled cargo placement returns package without losing purchase")
	placement.start_carrying_device(installed)
	placement.update_placement_process(0.1)
	check(placement.range_ghost != null and not installed.is_active, "Moving existing device shows range and suspends operation")
	placement.cancel_carrying_device()
	check(installed.position.is_equal_approx(Vector3(0, 0.05, 0)) and installed.is_active, "Cancel restores installed device position and operation")
	check(not factory.door_open, "Room rebuild closes the service door")
	factory.toggle_production()
	check(main.game_manager.production_enabled and not factory.door_open, "Closed door allows production restart")
	var scales = main.room_controller.balloon_gravity_scales
	check(scales[0] < scales[1] and scales[1] < scales[2] and scales[2] < scales[3] and scales[3] < scales[4], "All gravity upgrades have distinct increasing forces")
	installed.feedback.record_output(7)
	check(installed.feedback.last_output() == 7, "Device telemetry counts actual output")
	installed.feedback.advance_window(installed.feedback.bucket_second + 11)
	check(installed.feedback.output_buckets.reduce(func(a, b): return a + b, 0) == 0, "Telemetry expires outside ten-second window")
	main.shop_manager.current_room = "medium_room"
	main.shop_manager.upgrades.vent_rate.level = 2
	main.game_manager.current_vent_level = 2
	main.game_manager.recalculate_effective_stats()
	check(main.shop_manager.upgrade_value("vent_rate", 2) == "%.2f balon/sn" % main.game_manager.balloons_per_second, "Market rate preview matches actual room-adjusted production")
	installed.position = Vector3(3, 0.05, -3)
	var last_budget := 0
	for id in main.shop_manager.rooms:
		main.shop_manager.current_room = id
		main.apply_room_layout(id)
		await physics_frame
		await physics_frame
		var room = main.shop_manager.rooms[id]
		check(is_equal_approx(factory.half_length, room.floor_size.y / 2), id + " delivery bay follows room wall")
		check(is_equal_approx(installed.position.x / room.floor_size.x, 3.0 / 26.0), id + " installed device distribution scales with floor (x=%.2f)" % installed.position.x)
		var budget: int = main.game_manager.get_physics_budget()
		check(budget > last_budget and budget <= 720, id + " uses bounded physical body budget")
		last_budget = budget
		var furnishings = main.get_node("Environment/MainRoom/LabProps/RoomFurnishings")
		check(furnishings.find_children("*", "MultiMeshInstance3D", true, false).size() <= 12 and furnishings.find_children("*", "MeshInstance3D", true, false).is_empty(), id + " furniture batched by material")
	var special_balloon = load("res://src/entities/balloon.tscn").instantiate()
	main.balloon_container.add_child(special_balloon)
	special_balloon.position = Vector3(1, 2, 1)
	special_balloon.freeze = true
	special_balloon.setup_tier(50)
	special_balloon.setup_gas_type("cryo")
	# Autosave during a tablet visit while moving an existing device keeps its original transform.
	placement.start_carrying_device(installed)
	main.player.is_ui_open = true
	placement.update_placement_process(0.1)
	main.is_loading_save = false
	main.save_current_data()
	var carrying_save: Dictionary = main.save_manager.load_full_state()
	check(carrying_save.placed_devices.size() == 1 and carrying_save.factory.orders.size() == 1, "Hidden carried device is preserved during tablet autosave")
	main.player.is_ui_open = false
	placement.cancel_carrying_device()
	main.save_current_data()
	var saved: Dictionary = main.save_manager.load_full_state()
	check(saved.factory.orders.size() == 1 and saved.placed_devices.size() == 1, "Disk save separates installed devices and pending orders")
	factory.orders.clear()
	main.load_saved_data()
	check(factory.orders.size() == 1 and placement.active_placed_devices.size() == 1, "Load restores orders and installed device exactly once")
	var restored_special := false
	for balloon in main.balloon_container.get_children():
		if balloon is RigidBody3D and not balloon.is_queued_for_deletion() and balloon.tier_value == 50 and balloon.gas_type == "cryo": restored_special = true
	check(restored_special, "Save preserves balloon tier and gas")
	check(main.game_manager.active_balloons == main.game_manager.get_total_effective_balloons(), "Loaded weighted capacity matches restored balloons")
	main.game_manager.is_game_started = false
	if "--capture" in OS.get_cmdline_user_args():
		main.shop_manager.current_room = "small_room"
		main.apply_room_layout("small_room")
		main.get_node("UI").hide()
		main.player.camera.position = Vector3.ZERO
		main.player.position = Vector3(0, 0.5, 3)
		main.player.camera.global_position = Vector3(0, 2.0, 3)
		main.player.camera.look_at(Vector3(0, 1.7, 9))
		await create_timer(0.5).timeout
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("/tmp/balloon-room-factory.png")
		factory.toggle_production()
		factory.toggle_door()
		await create_timer(0.5).timeout
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("/tmp/balloon-room-factory-open.png")
		main.player.position = Vector3(-2.5, 0.6, 12)
		main.player.camera.global_position = Vector3(-2.5, 2, 12)
		main.player.camera.look_at(Vector3(0, 0.7, 14))
		await create_timer(0.2).timeout
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("/tmp/balloon-room-cargo.png")
		main.get_node("UI").show()
		main.victory_modal.hide()
		main.player.set_ui_open(false)
		main.shop_ui.toggle_shop_modal()
		await create_timer(0.8).timeout
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("/tmp/balloon-room-market-preview.png")
		main.shop_ui.toggle_shop_modal()
		await create_timer(0.4).timeout
	main.start_new_game()
	check(factory.orders.is_empty() and placement.active_placed_devices.is_empty() and main.shop_manager.devices.spike_wall.count == 0, "New game clears deliveries and installed devices")
	print("FACTORY FLOW: %d checks, %d failures" % [checks, failures])
	await physics_frame
	await physics_frame
	await process_frame
	for audio_player in main.sound_manager.audio_players: audio_player.stop()
	await create_timer(0.1).timeout
	main.queue_free()
	await process_frame
	quit(1 if failures else 0)
