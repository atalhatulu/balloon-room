extends SceneTree
var failures := 0
var checks := 0
var main: Node3D
func check(ok: bool, msg: String):
	checks += 1
	if not ok:
		failures += 1
		push_error(msg)
	else: print("PASS: ", msg)
func _init():
	if not OS.get_environment("XDG_DATA_HOME").begins_with("/tmp/balloon-room-"):
		quit(2)
		return
	run.call_deferred()
func balloon(kind: String) -> Node3D:
	var b = load("res://src/entities/balloon.tscn").instantiate()
	main.balloon_container.add_child(b)
	b.position = Vector3(0, 1.5, 1)
	b.freeze = true
	b.setup_special_type(kind)
	return b
func capture(path: String):
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(path)
func run():
	main = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	await process_frame
	paused = false
	main.set_process(false)
	main.is_loading_save = true
	main.startup_modal.hide()
	main.player.set_physics_process(false)
	main.player.set_process(false)
	var bonus = main.bonus_controller
	bonus.set_process(false)
	var b = balloon("bonus_coin")
	for source in ["electric_grid", "spike_floor", "bomb", "splash", "sentry_drone", "conveyor_crusher", "manual"]:
		b.pop(source)
		check(not b.is_popped and bonus.multiplier() == 1, source + " cannot trigger needle-only bonus")
	b.pop("needle")
	check(b.is_popped and bonus.multiplier() == 2, "Direct needle contact activates double coin earnings")
	bonus.coin_seconds = 3
	b.pop("needle")
	check(bonus.coin_seconds == 3, "Repeated pop cannot reactivate reward")
	var pops_before: int = main.game_manager.total_pops
	var minute_before: int = main.game_manager.last_minute_pops
	var baseline: int = main.coin_container.get_child_count()
	main.game_manager.on_balloon_popped(Vector3(0, 1, 0), Color.WHITE, 0, 10, false)
	var reward_total := 0
	for index in range(baseline, main.coin_container.get_child_count()):
		reward_total += int(main.coin_container.get_child(index).coin_value)
	check(reward_total == 20, "Double reward is baked into spawned coin exactly once")
	check(main.game_manager.total_pops == pops_before + 1, "Tier 10 balloon with bonus counts as one physical pop")
	check(main.game_manager.last_minute_pops == minute_before + 1, "Rate window counts physical pops")
	var regular_coins_before: int = main.shop_manager.coins
	main.shop_manager.add_coins(7)
	check(main.shop_manager.coins == regular_coins_before + 7, "Coin collection has no implicit Turbo multiplier")
	var gold_before: int = main.shop_manager.coins
	main.spawner_controller.show_pop_visual(Vector3.ZERO, 0, 1, "gold")
	check(main.shop_manager.coins == gold_before + 100, "Gold special reward also doubles")
	bonus.activate("bonus_magnet")
	check(bonus.magnet_seconds == bonus.DURATION and bonus.coin_seconds == 3, "Independent bonuses coexist")
	var saved: Dictionary = bonus.save_state()
	bonus.restore(saved)
	check(bonus.coin_seconds == 3 and bonus.magnet_seconds == bonus.DURATION, "Restore keeps remaining time without extending it")
	main.is_loading_save = false
	main.game_manager.is_game_started = true
	main.game_manager.production_enabled = false
	bonus._process(2)
	check(bonus.coin_seconds == 3, "Production stop pauses bonus")
	main.game_manager.production_enabled = true
	bonus._process(3.5)
	check(bonus.multiplier() == 1 and is_equal_approx(bonus.magnet_seconds, bonus.DURATION - 3.5), "Bonuses expire independently")
	main.is_loading_save = true
	var b1 = balloon("bonus_coin")
	var b2 = balloon("bonus_magnet")
	bonus.spawn_cooldown = 0
	var blocked := true
	for i in range(500): blocked = blocked and bonus.roll_spawn() == ""
	check(blocked, "Unclaimed bonus balloons capped at two")
	for kind in ["spike_wall", "electric_wall"]:
		var device = load("res://src/devices/" + kind + ".tscn").instantiate()
		main.add_child(device)
		device.setup_level(1)
		device.set_physics_process(false)
		device.feedback.update_state(0.1, 1)
		var before_y: float = device.feedback.moving_parts[0].position.y
		device.feedback.pulse()
		device.feedback.update_state(0.04, 0)
		check(device.feedback.moving_parts[0].position.y > before_y, kind + " action moves machine components")
		device.queue_free()
	# Real save/load protects needle-only type and connects all six signal arguments.
	main.is_loading_save = false
	main.save_current_data()
	main.load_saved_data()
	await process_frame
	var loaded: Node3D
	for child in main.balloon_container.get_children():
		if not child.is_queued_for_deletion() and child.gas_type == "bonus_coin": loaded = child
	check(is_instance_valid(loaded) and not loaded.can_pop("electric_grid"), "Saved bonus restores needle-only protection")
	if loaded:
		loaded.pop("needle")
		check(bonus.coin_seconds == bonus.DURATION, "Loaded balloon pop signal and bonus work")
	main.is_loading_save = true
	# Duplicate collection cannot credit twice.
	var c = load("res://src/entities/coin.tscn").instantiate()
	main.coin_container.add_child(c)
	c.init(main.player.position + Vector3(2, 0.1, 0), 7, 1)
	c.is_collecting = true
	c._process(0.2)
	check(c.global_position.y > 0.4, "Collecting coin follows elevated arc")
	var coins_before: int = main.shop_manager.coins
	c.collect_coin()
	c.collect_coin()
	check(main.shop_manager.coins == coins_before + 7, "Collection pays once")
	var stage := 0
	for id in main.shop_manager.rooms:
		stage += 1
		main.shop_manager.current_room = id
		main.apply_room_layout(id)
		await process_frame
		var decor = main.get_node("Environment/MainRoom/LabProps/RoomFurnishings")
		check(not decor.find_children("RoomIdentity%d*" % stage, "Node3D", true, false).is_empty(), id + " has distinctive architecture")
		check(decor.find_children("*", "MeshInstance3D", true, false).is_empty(), id + " static decoration remains batched")
		if "--capture" in OS.get_cmdline_user_args():
			root.size = Vector2i(1280, 720)
			main.get_node("UI").hide()
			main.get_node("QuestCanvasLayer").hide()
			var size: Vector2 = main.shop_manager.rooms[id].floor_size
			var identity = decor.find_children("RoomIdentity%d*" % stage, "Node3D", true, false)[0]
			main.player.position = Vector3(identity.global_position.x + 2, 0, -size.y * 0.5 + 8)
			main.player.rotation = Vector3.ZERO
			main.player.head.rotation = Vector3(-0.05, 0, 0)
			main.player.camera.current = true
			await create_timer(0.2).timeout
			await capture("/tmp/balloon-polish-" + id + ".png")
	if "--capture" in OS.get_cmdline_user_args():
		main.shop_manager.current_room = "small_room"
		main.apply_room_layout("small_room")
		main.player.position = Vector3(0, 0, 5)
		main.player.rotation = Vector3.ZERO
		main.player.head.rotation = Vector3.ZERO
		main.get_node("UI").show()
		main.startup_modal.hide()
		var gold_bonus = balloon("bonus_coin")
		gold_bonus.position = Vector3(-0.8, 1.6, 2)
		var magnet_bonus = balloon("bonus_magnet")
		magnet_bonus.position = Vector3(0.8, 1.6, 2)
		bonus.activate("bonus_coin")
		bonus.activate("bonus_magnet")
		var index := 0
		for kind in ["spike_wall", "electric_wall", "magnet_pylon"]:
			var dev = load("res://src/devices/" + kind + ".tscn").instantiate()
			main.add_child(dev)
			dev.position = Vector3(-3 + index * 3, 0, -1)
			dev.setup_level(1)
			dev.set_physics_process(false)
			dev.feedback.pulse()
			dev.feedback.update_state(0.08, 0.8, true)
			index += 1
		await capture("/tmp/balloon-polish-bonuses.png")
	main.start_new_game()
	check(bonus.multiplier() == 1 and bonus.magnet_seconds == 0, "New game clears buffs")
	print("BONUS & POLISH: %d checks, %d failures" % [checks, failures])
	main.is_loading_save = true
	main.queue_free()
	await process_frame
	quit(1 if failures else 0)
