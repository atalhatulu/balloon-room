extends SceneTree
var failures := 0
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
func run() -> void:
	root.size = Vector2i(1366, 768)
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
	main.shop_manager.current_room = "medium_room"
	main.shop_manager.unlocked_rooms = ["small_room", "medium_room"]
	main.game_manager.total_pops = 6500
	main.shop_manager.coins = 1750
	main.apply_room_layout("medium_room")
	# Reproduce Continue: the requested saved room can differ from the
	# startup default when the room layout signal triggers dependent rebuilds.
	main.shop_manager.current_room = "small_room"
	main.apply_room_layout("medium_room")
	check(main.shop_manager.current_room == "medium_room" and is_equal_approx(main.factory.half_length, 13.0) and is_equal_approx(main.factory.bay.position.z, 13.0), "Continue rebuilds the factory bay using the restored room dimensions")
	main.game_manager.recalculate_effective_stats()
	main.player.position = Vector3(10, 0.6, 11)
	main.player.rotation.y = 0.6
	main.player.head.rotation.x = 0.06
	main.player.apply_upgrade("dart_gun", 2)
	main.player.switch_weapon_slot(2)
	var atmosphere = main.room_controller.env_main_room.get_node("FacilityAtmosphere")
	check(atmosphere.rotors.size() == 4, "Facility has four visual ventilation rotors")
	var old_angle: float = atmosphere.rotors[0].rotation.z
	await create_timer(0.6).timeout
	check(atmosphere.rotors[0].rotation.z != old_angle, "Production drives rotor movement")
	check(main.hud_controller.room_identity.text == "Üretim Tesisi", "HUD identifies active room")
	main.game_manager.production_enabled = false
	atmosphere._process(2.0)
	check(is_zero_approx(atmosphere.activity) and atmosphere.status.text.contains("BEKLEMEDE"), "Stopped production settles animation and status")
	main.game_manager.production_enabled = true
	if "--capture" in OS.get_cmdline_user_args():
		await create_timer(1).timeout
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("/tmp/balloon-room-facility.png")
	main.shop_ui.toggle_shop_modal()
	await create_timer(0.8).timeout
	main.shop_ui.set_category_filter("all")
	var grid = main.shop_ui.upgrades_container
	check(grid.get_node("CardDartGun/Margin/VBox/UnlockProgress") != null, "Shop cards show progression to unlock")
	check(main.shop_ui.tablet_view.panel.size.x <= root.get_visible_rect().size.x and main.shop_ui.tablet_view.panel.size.y <= root.get_visible_rect().size.y, "Tablet fits normal viewport")
	if "--capture" in OS.get_cmdline_user_args():
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("/tmp/balloon-room-market.png")
	root.size = Vector2i(960, 540)
	await create_timer(0.4).timeout
	check(main.shop_ui.tablet_view.panel.size.x <= root.get_visible_rect().size.x and main.shop_ui.tablet_view.panel.size.y <= root.get_visible_rect().size.y, "Tablet fits compact viewport")
	main.shop_ui.toggle_shop_modal()
	await create_timer(0.5).timeout
	main.apply_room_layout("small_room")
	check(not main.room_controller.env_main_room.has_node("FacilityAtmosphere"), "Room switch removes facility-only animation nodes")
	main.queue_free()
	await process_frame
	print("FACILITY POLISH: ", failures, " failures")
	quit(1 if failures else 0)
