extends SceneTree

var failures := 0
var checks := 0
var main: Node3D

func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		push_error(message)
	else: print("PASS: ", message)

func _init() -> void:
	if not OS.get_environment("XDG_DATA_HOME").begins_with("/tmp/balloon-room-"):
		quit(2)
		return
	run.call_deferred()

func target(distance: float, special := "normal") -> Node3D:
	var balloon = load("res://src/entities/balloon.tscn").instantiate()
	main.balloon_container.add_child(balloon)
	balloon.global_position = main.player.camera.global_position - main.player.camera.global_basis.z * distance
	balloon.freeze = true
	balloon.setup_tier(1)
	if special != "normal": balloon.setup_special_type(special)
	balloon.popped.connect(func(_b, pos, color, combo, tier, midair): main.game_manager.on_balloon_popped(pos, color, combo, tier, midair, str(_b.last_pop_source)))
	main.game_manager.on_balloon_spawned(1)
	return balloon

func clear_targets() -> void:
	for balloon in main.balloon_container.get_children(): balloon.queue_free()
	await process_frame

func run() -> void:
	main = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	await process_frame
	paused = false
	main.is_loading_save = true
	main.set_process(false)
	main.game_manager.is_game_started = false
	main.game_manager.set_process(false)
	main.bonus_controller.set_process(false)
	main.quest_manager.set_process(false)
	main.startup_modal.hide()
	var player = main.player
	player.set_ui_open(false)
	player.set_physics_process(false)
	player.set_process(false)
	# Isolate shot geometry above the procedural room and its props.
	player.position = Vector3(0, 30, 0)
	player.rotation = Vector3.ZERO
	player.head.rotation = Vector3.ZERO
	player.camera.rotation = Vector3.ZERO
	await clear_targets()
	var shop = main.shop_manager
	check(shop.rooms.small_room.tier_weights[5] == 0.0 and shop.rooms.small_room.tier_weights[10] == 0.0 and shop.rooms.small_room.tier_weights[50] == 0.0, "Room one spawns only small tier-one balloons")
	check(shop.rooms.medium_room.tier_weights[10] == 0.0 and shop.rooms.medium_room.tier_weights[50] == 0.0, "Room two has no oversized tier-ten or tier-fifty balloons")
	check(main.spawner_controller.clamp_tier_for_current_room(50) == 1, "Loaded or carried tier-fifty balloons shrink to tier one in room one")
	var old_saved_balloon = load("res://src/entities/balloon.tscn").instantiate()
	main.balloon_container.add_child(old_saved_balloon)
	old_saved_balloon.freeze = true
	old_saved_balloon.setup_tier(50)
	main.apply_room_layout("medium_room")
	check(old_saved_balloon.tier_value == 5, "Existing tier-fifty balloons are reduced when entering room two")
	main.apply_room_layout("small_room")
	check(old_saved_balloon.tier_value == 1, "Existing balloons stay small when returning to room one")
	old_saved_balloon.queue_free()
	await process_frame
	shop.current_room = "medium_room"
	check(main.spawner_controller.clamp_tier_for_current_room(50) == 5, "Tier-fifty balloons shrink to tier five in room two")
	shop.current_room = "hangar"
	check(main.spawner_controller.clamp_tier_for_current_room(50) == 50, "Tier-fifty balloons first become valid in room three")
	shop.current_room = "small_room"
	shop.coins = 100000
	player.switch_weapon_slot(2)
	check(player.current_weapon_slot == 1, "Unpurchased dart cannot be equipped")
	main.game_manager.total_pops = 650
	check(shop.buy_upgrade("athlete_training", 650) and shop.buy_upgrade("auto_pop", 650) and shop.buy_upgrade("splash_pop", 650), "Needle skill tree purchases its prerequisites in order")
	var balance: int = shop.coins
	check(not shop.buy_upgrade("dart_gun", 649) and shop.coins == balance, "Dart threshold rejects purchase without charging")
	main.game_manager.total_pops = 650
	main.shop_ui.update_all_shop_cards()
	var dart_button = main.shop_ui.upgrades_container.get_node("CardDartGun/Margin/VBox/BtnBuy")
	check(not dart_button.disabled, "Dart shop button unlocks at 650 physical pops")
	dart_button.pressed.emit()
	check(shop.coins == balance - shop.get_upgrade_cost("dart_gun", 0) and int(shop.upgrades.dart_gun.level) == 1, "Dart shop button buys exactly one level")
	check(player.dart_weapon.level == 1, "Purchase configures player weapon")
	player.switch_weapon_slot(2)
	await process_frame
	check(player.current_weapon_slot == 2 and player.dart_weapon.model.visible, "Dart equips with distinct model")
	check(not player.hands.tool_node.visible, "Needle is stowed while dart is equipped")
	check(main.shop_ui.upgrades_container.has_node("CardDartGun"), "Dart card exists in tablet shop")
	if "--capture" in OS.get_cmdline_user_args():
		player.position = Vector3(5.5, 0.6, 3.0)
		for distance in [3.0, 4.5, 6.0]: target(distance)
		await create_timer(0.6).timeout
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("/tmp/balloon-room-dart.png")
		player.position = Vector3(0, 30, 0)
		await clear_targets()
	var a = target(4)
	var b = target(6)
	var first_cap: int = player.dart_weapon.pierce
	var third = target(8)
	await physics_frame
	await physics_frame
	player.dart_weapon.cooldown = 0
	var before: int = main.game_manager.total_pops
	check(player.dart_weapon.fire(), "Purchased dart fires")
	check(a.is_popped and (b.is_popped == (first_cap >= 2)) and not third.is_popped, "First level stops at catalog pierce cap")
	check(main.game_manager.total_pops == before + mini(first_cap, 2), "Dart credits actual physical hit")
	check(int(main.game_manager.pop_sources.get("dart", 0)) == mini(first_cap, 2) and main.game_manager.dart_shots == 1 and main.game_manager.dart_hit_shots == 1, "F1 tracks actual dart pops and successful shots")
	check(player.dart_weapon.magazine_rounds == player.dart_weapon.magazine_capacity - 1, "Dart consumes one cartridge per trigger pull")
	check(not player.dart_weapon.fire(), "Repeated input cannot bypass dart cooldown")
	await clear_targets()
	a = target(4)
	var side_left = target(5)
	side_left.global_position.x -= 1.2
	var side_right = target(5)
	side_right.global_position.x += 1.2
	var far_side = target(5)
	far_side.global_position.x += 3.2
	await physics_frame
	await physics_frame
	player.dart_weapon.cooldown = 0
	before = main.game_manager.total_pops
	player.dart_weapon.fire()
	check(a.is_popped and side_left.is_popped and side_right.is_popped and not far_side.is_popped, "First dart hit ricochets to two nearby balloons only")
	check(main.game_manager.total_pops == before + 3, "Ricochet credits only physical balloon pops")
	await clear_targets()
	check(shop.buy_upgrade("dart_gun", shop.get_upgrade_req_pops("dart_gun", 1)) and shop.buy_upgrade("dart_gun", shop.get_upgrade_req_pops("dart_gun", 2)), "Piercing upgrades unlock at their milestones")
	a = target(4)
	b = target(6)
	var c = target(8)
	var d = target(10)
	var e = target(12)
	var f = target(14)
	await physics_frame
	await physics_frame
	player.dart_weapon.cooldown = 0
	player.dart_weapon.fire()
	check(a.is_popped and b.is_popped and c.is_popped and (d.is_popped == (player.dart_weapon.pierce >= 4)) and (e.is_popped == (player.dart_weapon.pierce >= 5)) and not f.is_popped, "Third level obeys catalog pierce cap")
	await clear_targets()
	a = target(4)
	b = target(8)
	var behind_cover = target(6)
	behind_cover.global_position.x += 1.0
	var wall := StaticBody3D.new()
	wall.collision_layer = 1
	wall.collision_mask = 0
	var collision := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = Vector3(4, 4, 0.3)
	collision.shape = shape
	wall.add_child(collision)
	main.add_child(wall)
	wall.global_position = player.camera.global_position - player.camera.global_basis.z * 5.3
	await physics_frame
	await physics_frame
	player.dart_weapon.cooldown = 0
	player.dart_weapon.fire()
	check(a.is_popped and not b.is_popped and not behind_cover.is_popped, "Piercing and ricochet stop at solid wall")
	wall.queue_free()
	await clear_targets()
	a = target(4, "bonus_coin")
	await physics_frame
	await physics_frame
	player.dart_weapon.cooldown = 0
	player.dart_weapon.fire()
	check(not a.is_popped, "Dart preserves needle-only special bonus role")
	player.dart_weapon.magazine_rounds = 1
	player.dart_weapon.cooldown = 0
	check(player.dart_weapon.fire() and player.dart_weapon.reload_left > 0.0, "Empty dart magazine starts automatic reload")
	check(not player.dart_weapon.fire(), "Dart cannot fire during reload")
	player.dart_weapon.reload_left = 0.01
	player.dart_weapon._process(0.02)
	check(player.dart_weapon.magazine_rounds == player.dart_weapon.magazine_capacity and player.dart_weapon.reload_left == 0.0, "Automatic reload refills the magazine")
	player.set_ui_open(true)
	player.dart_weapon.cooldown = 0
	check(not player.dart_weapon.fire(), "UI blocks firing")
	player.set_ui_open(false)
	player.set_minigun_frenzy(true)
	check(not player.dart_weapon.fire(), "Minigun frenzy overrides dart")
	player.minigun_heat = 0.0
	player.minigun_overheated = false
	for _i in range(263): player._add_minigun_heat()
	check(player.minigun_overheated and is_equal_approx(player.minigun_cooldown_left, 2.0), "Minigun overheats after about ten seconds of sustained fire and cools for two seconds")
	var locked_heat: float = player.minigun_heat
	player.execute_minigun_shot()
	check(is_equal_approx(player.minigun_heat, locked_heat), "Overheated minigun blocks firing")
	player._update_minigun_thermal(2.0)
	check(not player.minigun_overheated and player.minigun_heat == 0.0, "Minigun is ready after the cooldown")
	player.set_minigun_frenzy(false)
	await create_timer(0.4).timeout
	check(player.current_weapon_slot == 2 and player.dart_weapon.model.visible, "Frenzy returns to equipped dart")
	shop.coins = 0
	check(not shop.buy_room("medium_room", 4999), "Room two remains locked below 5000")
	check(not shop.buy_room("medium_room", 5000) and shop.current_room == "small_room" and not shop.is_room_unlocked("medium_room"), "Room two requires coins as well as the pop milestone")
	shop.coins = int(shop.rooms.medium_room.cost) + 37
	check(shop.buy_room("medium_room", 5000) and shop.coins == 37, "Room purchase deducts its fee exactly once")
	check(shop.buy_room("medium_room", 5000) and shop.coins == 37, "Returning to an owned room is free")
	# Save/load weapon ownership and selection through the existing serializer.
	main.is_loading_save = false
	main.save_current_data()
	shop.upgrades.dart_gun.level = 0
	player.apply_upgrade("dart_gun", 0)
	main.load_saved_data()
	check(player.dart_weapon.level == 3 and player.current_weapon_slot == 2, "Save restores dart upgrades and selection")
	main.game_manager.is_game_started = false
	main.is_loading_save = true
	player.set_minigun_frenzy(true)
	main.start_new_game()
	check(player.dart_weapon.level == 0 and player.current_weapon_slot == 1, "New game resets dart ownership and selection")
	check(not player.macro_click_enabled, "New game clears needle auto-fire")
	check(not player.is_minigun_frenzy, "New game clears the temporary minigun")
	print("ROOM ONE: ", checks, " checks, ", failures, " failures")
	main.queue_free()
	await process_frame
	quit(1 if failures else 0)
