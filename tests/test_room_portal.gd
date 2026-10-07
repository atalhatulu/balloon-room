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
	var main = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	await process_frame
	paused = false
	main.is_loading_save = true
	main.startup_modal.hide()
	main.player.set_physics_process(false)
	main.game_manager.set_process(false)
	for existing in main.balloon_container.get_children():
		existing.queue_free()
	main.shop_manager.coins = 10037
	var balloon = load("res://src/entities/balloon.tscn").instantiate()
	main.balloon_container.add_child(balloon)
	balloon.freeze = true
	var original_light: Color = main.get_node("DirectionalLight3D").light_color
	var shop = main.shop_manager
	check(shop.buy_room("medium_room", 5000) and shop.coins == 37, "Purchase charges exactly once")
	check(shop.current_room == "small_room" and shop.pending_room == "medium_room" and main.factory.waiting_for_clear and not is_instance_valid(main.factory.portal), "Purchase waits for remaining balloons without moving the player")
	main.factory.toggle_production(true)
	check(not main.game_manager.production_enabled, "Production cannot restart while portal is pending")
	var saved: Dictionary = main.factory.save_state()
	main.factory.restore(saved)
	check(shop.pending_room == "medium_room" and main.factory.waiting_for_clear and not is_instance_valid(main.factory.portal), "Saved cleanup phase restores without spawning a portal")
	check(shop.buy_room("medium_room", 5000) and shop.coins == 37, "Repeated purchase never charges twice")
	main.is_loading_save = false
	main.factory._process(0.5)
	check(main.get_node("DirectionalLight3D").light_color.is_equal_approx(Color("ff983d")), "Transfer preparation turns room lighting orange")
	check(not is_instance_valid(main.factory.portal), "One remaining balloon keeps portal closed")
	balloon.queue_free()
	main.factory._process(0.3)
	check(is_instance_valid(main.factory.portal) and not main.factory.waiting_for_clear, "Portal appears after the final balloon is cleared")
	if not is_instance_valid(main.factory.portal):
		quit(1)
		return
	main.game_manager.is_game_started = true
	main.player.set_ui_open(false)
	main.player.position = Vector3(0, 0.6, 0)
	main.factory.portal._process(0.9)
	check(not main.factory.portal.transitioning, "Portal opening around player does not trigger accidental travel")
	main.player.position = Vector3(0, 0.6, 4)
	main.factory.portal._process(0.1)
	main.player.position = Vector3(0, 0.6, 0)
	main.factory.portal._process(0.1)
	await create_timer(1.0).timeout
	check(shop.current_room == "medium_room" and shop.pending_room == "" and not main.game_manager.production_enabled, "Portal transfers to new room with production stopped")
	check(main.get_node("DirectionalLight3D").light_color.is_equal_approx(original_light), "Normal lighting returns after room transfer")
	main.factory.toggle_production()
	check(not main.game_manager.production_enabled, "Tablet cannot bypass first wall-button start")
	main.factory.interact("production")
	check(main.game_manager.production_enabled and not main.factory.requires_wall_start, "Door-side start button enables production")
	main.factory.restore({})
	check(shop.pending_room == "" and not is_instance_valid(main.factory.portal), "Reset clears pending transfer")
	main.queue_free()
	await process_frame
	print("ROOM PORTAL: ", failures, " failures")
	quit(1 if failures else 0)
