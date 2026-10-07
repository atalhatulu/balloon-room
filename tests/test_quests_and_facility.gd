extends SceneTree
var failures := 0
var checks := 0
func check(ok: bool, description: String) -> void:
	checks += 1
	if ok: print("PASS: ", description)
	else:
		failures += 1
		push_error(description)
func _init() -> void:
	if not OS.get_environment("XDG_DATA_HOME").begins_with("/tmp/balloon-room-"):
		quit(2)
		return
	run.call_deferred()

func seed_pressure_balloon_count(main: Node, count: int) -> void:
	for existing in main.balloon_container.get_children(): existing.queue_free()
	await process_frame
	for i in range(count):
		var balloon = load("res://src/entities/balloon.tscn").instantiate()
		main.balloon_container.add_child(balloon)
		balloon.freeze = true
		balloon.set_process(false)
		balloon.set_physics_process(false)
		balloon.setup_tier(1)
func run() -> void:
	root.size = Vector2i(1280, 720)
	var main = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	await process_frame
	main.startup_modal.hide()
	main.victory_modal.hide()
	main.set_process(false)
	main.player.set_physics_process(false)
	main.player.set_ui_open(false)
	main.game_manager.set_process(false)
	main.quest_manager.set_process(false)
	main.game_manager.is_game_started = true
	main.factory.restore({})
	var gm = main.game_manager
	var qm = main.quest_manager
	var shop = main.shop_manager
	var facility = main.shop_ui.tablet_view.facility
	gm.reset_minute_pop_window()
	gm.minute_measured_seconds = 60
	gm.minute_pop_buckets[0] = 60
	gm.last_minute_pops = 60
	gm.active_balloons = 100
	gm.total_pops = 100000
	gm.session_elapsed_time = 1
	check(qm.production_target(60) == mini(69, int(float(qm.supply_profile(60).total) * 0.8)), "Quest target uses measured minute, not lifetime pops divided by fresh session")
	gm.smooth_pps = 10000
	check(qm.production_target(60) == mini(69, int(float(qm.supply_profile(60).total) * 0.8)), "Instantaneous PPS spikes do not change quest target")
	var saved_activity: Dictionary = gm.save_activity()
	gm.restore_activity({})
	gm.restore_activity(saved_activity)
	check(gm.last_minute_pops == 60 and gm.minute_measured_seconds == 60, "Minute activity restores across reload")
	qm.quest_type = "total_pops"
	qm.start_quest("TEST", "TEST", 10, 60, 30)
	gm.total_pops += 4
	gm.pop_registered.emit(gm.total_pops)
	check(qm.current_progress == 4, "Total quest counts progress since its own start")
	var saved_quest: Dictionary = qm.save_state()
	qm.restore({})
	qm.restore(saved_quest)
	gm.total_pops += 2
	gm.pop_registered.emit(gm.total_pops)
	check(qm.current_progress == 6 and qm.time_left == 60, "Restored quest resumes progress without charging offline time")
	var time_before: float = qm.time_left
	paused = true
	qm._process(10)
	check(qm.time_left == time_before and qm.process_mode == Node.PROCESS_MODE_PAUSABLE, "Pause freezes quest timing")
	paused = false
	gm.production_enabled = false
	qm._process(10)
	check(qm.time_left == time_before, "Cargo production stop freezes quest timing")
	gm.production_enabled = true
	qm.quest_type = "combo_chain"
	qm.start_quest("COMBO", "COMBO", 4, 60, 30)
	for i in range(2):
		gm.balloon_popped_detailed.emit(Vector3.ZERO, 1, 0)
		qm._process(0.4)
	check(qm.current_progress == 2, "Ordinary pops form a real timed combo")
	qm._process(1.6)
	gm.balloon_popped_detailed.emit(Vector3.ZERO, 1, 0)
	check(qm.combo_count == 1 and qm.current_progress == 2, "Long gap breaks streak but preserves best progress")
	var coins_before: int = shop.coins
	for i in range(3): gm.balloon_popped_detailed.emit(Vector3.ZERO, 1, 0)
	check(not qm.is_active and shop.coins == coins_before + 30, "Four timed pops complete combo and pay reward")
	qm.complete_quest()
	check(shop.coins == coins_before + 30, "Quest reward cannot be claimed twice")
	var completed: Dictionary = qm.save_state()
	qm.restore(completed)
	check(not qm.is_active and shop.coins == coins_before + 30, "Loading completed quest cannot award again")
	shop.upgrades.auto_pop.level = 0
	shop.upgrades.splash_pop.level = 0
	gm.balloons_per_second = 0.1
	gm.active_balloons = 0
	check(not qm.eligible_types().has("combo_chain") and not qm.eligible_types().has("tier_pops") and not qm.eligible_types().has("pressure_hold"), "Early low-supply room excludes unsuitable quests")
	shop.current_room = "medium_room"
	gm.recalculate_effective_stats()
	shop.upgrades.auto_pop.level = 1
	gm.balloons_per_second = 5
	gm.active_balloons = int(gm.max_room_balloons * 0.5)
	await seed_pressure_balloon_count(main, int(gm.get_physics_budget() * 0.5))
	check(qm.eligible_types().has("combo_chain") and qm.eligible_types().has("tier_pops") and qm.eligible_types().has("pressure_hold"), "Unlocked ability and room supply enable varied quests")
	qm.quest_type = "pressure_hold"
	qm.start_quest("PRESSURE", "PRESSURE", 25, 25, 30)
	gm.production_enabled = false
	qm._process(30)
	check(qm.is_active and qm.current_progress == 0, "Pressure task cannot be farmed with stopped production")
	gm.production_enabled = true
	gm.active_balloons = int(gm.max_room_balloons * 0.9)
	await seed_pressure_balloon_count(main, int(gm.get_physics_budget() * 0.9))
	qm._process(0.1)
	check(not qm.is_active, "Pressure task fails when threshold is crossed")
	facility.select_gravity(4)
	check(main.room_controller.current_gravity_idx == 4 and is_equal_approx(main.room_controller.get_current_gravity_scale(), 6.0), "Facility gravity setting is available without buying a regulator")
	check(not facility.gravity_select.is_item_disabled(0) and not facility.gravity_select.is_item_disabled(4), "All gravity presets are free settings")
	main.player.position = Vector3(0, 0.6, 0)
	facility.production_button.pressed.emit()
	check(not gm.production_enabled, "Tablet stops production through factory interlock")
	main.factory.toggle_door()
	await create_timer(0.45).timeout
	facility.refresh()
	check(facility.production_button.disabled, "Open door disables tablet restart")
	facility.production_button.pressed.emit()
	check(not gm.production_enabled, "Even direct restart callback cannot bypass door interlock")
	main.factory.toggle_door()
	await create_timer(0.45).timeout
	facility.refresh()
	facility.production_button.pressed.emit()
	check(gm.production_enabled, "Closed door enables tablet restart")
	main.factory.order("spike_wall", 1)
	facility.refresh()
	check(facility.cargo_list.text.contains("Zemin Kırıcısı") and facility.cargo_list.text.contains("Teslimat"), "Facility shows named pending cargo")
	var dev = load("res://src/devices/spike_wall.tscn").instantiate()
	main.env_main_room.add_child(dev)
	dev.set_meta("device_type", "spike_wall")
	dev.setup_level(1)
	dev.position = Vector3(-3, 0.05, -3)
	main.active_placed_devices.append(dev)
	dev.feedback.record_output(8)
	facility.refresh()
	check(facility.device_rows[dev.get_instance_id()].text.contains("8 patlatma"), "Facility displays actual device output")
	main.shop_ui.set_category_filter("facility")
	check(main.shop_ui.tablet_view.facility_scroll.visible and not main.shop_modal.get_node("Panel/Margin/VBox/Scroll").visible, "Facility tab switches away from catalog")
	main.shop_ui.set_category_filter("all")
	check(not main.shop_ui.tablet_view.facility_scroll.visible and main.shop_modal.get_node("Panel/Margin/VBox/Scroll").visible, "Catalog restores after leaving facility")
	qm.quest_type = "total_pops"
	qm.start_quest("KAYIT", "Kayıt görevi", 20, 60, 30)
	gm.total_pops += 7
	gm.pop_registered.emit(gm.total_pops)
	main.save_current_data()
	var disk: Dictionary = main.save_manager.load_full_state()
	check(disk.quest.progress == 7 and disk.activity.measured == 60, "Disk save includes quest progress and measured activity")
	qm.restore({})
	main.load_saved_data()
	check(qm.is_active and qm.current_progress == 7 and gm.last_minute_pops == 60, "Real load resumes quest and minute activity")
	main.victory_modal.hide()
	main.player.set_ui_open(false)
	main.shop_ui.set_category_filter("facility")
	main.shop_ui.toggle_shop_modal()
	await create_timer(0.8).timeout
	check(main.shop_ui.tablet_view.panel.visible and facility.is_visible_in_tree(), "Facility works on presented two-handed tablet")
	if "--capture" in OS.get_cmdline_user_args():
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("/tmp/balloon-room-facility.png")
		root.size = Vector2i(960, 540)
		await create_timer(0.3).timeout
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("/tmp/balloon-room-facility-compact.png")
	main.shop_ui.toggle_shop_modal()
	await create_timer(0.4).timeout
	main.start_new_game()
	check(not qm.is_active and gm.last_minute_pops == 0, "New game clears quest and minute history")
	await physics_frame
	await physics_frame
	for player in main.sound_manager.audio_players: player.stop()
	await create_timer(0.1).timeout
	print("QUESTS & FACILITY: %d checks, %d failures" % [checks, failures])
	main.queue_free()
	await process_frame
	quit(1 if failures else 0)
