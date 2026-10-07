extends Node

# GameStateController (Save/Load serializer & state orchestrator)
# Extracted from main.gd to encapsulate full save data gathering and unpacking.

var main: Node = null

func setup(p_main: Node) -> void:
	main = p_main

func save_current_data() -> void:
	if not main or main.is_loading_save:
		return
	if not main.is_inside_tree():
		return
	if not main.save_manager or not main.game_manager or not main.shop_manager or not main.player:
		return
	if not is_instance_valid(main.player) or not main.player.is_inside_tree():
		return
		
	var balloons_data: Array = []
	if main.balloon_container and is_instance_valid(main.balloon_container) and main.balloon_container.is_inside_tree():
		var save_candidates = main.balloon_container.get_children()
		save_candidates.sort_custom(func(a, b): return a.is_in_group("needle_bonus") and not b.is_in_group("needle_bonus"))
		for child in save_candidates:
			if is_instance_valid(child) and child.is_inside_tree() and child is RigidBody3D and not child.is_queued_for_deletion():
				var color_hex = "#ff4757"
				if "balloon_color" in child:
					color_hex = child.balloon_color.to_html(false)
				balloons_data.append({
					"pos": [round(child.global_position.x * 100.0) / 100.0, round(child.global_position.y * 100.0) / 100.0, round(child.global_position.z * 100.0) / 100.0],
					"vel": [round(child.linear_velocity.x * 10.0) / 10.0, round(child.linear_velocity.y * 10.0) / 10.0, round(child.linear_velocity.z * 10.0) / 10.0],
					"tier": child.tier_value,
					"gas": child.gas_type,
					"special_seconds_left": child.special_seconds_left,
					"color": color_hex
				})
				if balloons_data.size() >= 120:
					break
				
	var player_data = {
		"pos": [main.player.global_position.x, main.player.global_position.y, main.player.global_position.z],
		"rot_y": main.player.rotation.y,
		"head_pitch": main.player.head.rotation.x if main.player.head else 0.0,
		"weapon_slot": main.player.current_weapon_slot,
		"energy": main.player.current_energy
	}
	
	var upgrades_data = {}
	for up_id in main.shop_manager.upgrades.keys():
		upgrades_data[up_id] = main.shop_manager.upgrades[up_id].get("level", 0)
		
	var devices_data = {}
	for dev_id in main.shop_manager.devices.keys():
		devices_data[dev_id] = {
			"level": main.shop_manager.devices[dev_id].get("level", 0),
			"count": main.shop_manager.devices[dev_id].get("count", 0)
		}
	devices_data["gravity_mode"] = main.current_gravity_idx
	
	var placed_devices_data: Array = []
	for dev in main.active_placed_devices:
		if is_instance_valid(dev) and (dev.visible or dev == main.carried_device):
			var d_type = dev.get_meta("device_type") if dev.has_meta("device_type") else ""
			if d_type != "":
				var d_lvl = dev.get("level") if ("level" in dev) else 1
				if d_lvl <= 0: d_lvl = 1
				placed_devices_data.append({
					"type": d_type,
					"pos": main._device_save_position(dev),
					"rot_y": main.device_placement.carried_original_rot_y if dev == main.carried_device else dev.rotation.y,
					"level": d_lvl
				})
		
	var coins_data: Array = []
	if main.coin_container and is_instance_valid(main.coin_container) and main.coin_container.is_inside_tree():
		for c in main.coin_container.get_children():
			if is_instance_valid(c) and not c.is_queued_for_deletion() and not c.collected and not c.is_merging:
				coins_data.append({
					"pos": [c.global_position.x, c.global_position.y, c.global_position.z],
					"val": c.get("coin_value") if ("coin_value" in c) else 1,
					"grounded": c.get("is_grounded") if ("is_grounded" in c) else true
				})
		
	var full_state = {
		"version": 11,
		"bonuses": main.bonus_controller.save_state(),
		"quest": main.quest_manager.save_state(),
		"activity": main.game_manager.save_activity(),
		"test_production_multiplier": main.game_manager.turbo_speed_multiplier,
		"test_progress_multiplier": main.game_manager.turbo_pop_multiplier,
		"test_coin_multiplier": main.game_manager.turbo_coin_multiplier,
		"factory": main.factory.save_state() if main.factory else {},
		"active_theme": main.theme_controller.active_theme_id if main.theme_controller else "clean_lab",
		"current_room": main.shop_manager.current_room,
		"unlocked_rooms": main.shop_manager.unlocked_rooms,
		"prestige_level": main.shop_manager.prestige_level,
		"helium_atoms": main.shop_manager.helium_atoms,
		"devices": devices_data,
		"placed_devices": placed_devices_data,
		"total_pops": main.game_manager.total_pops,
		"coins": main.shop_manager.coins,
		"is_victory_shown": main.is_victory_shown,
		"playtime_seconds": main.playtime_seconds,
		"best_speedrun_time": main.best_speedrun_time,
		"upgrades": upgrades_data,
		"player": player_data,
		"balloons": balloons_data,
		"floor_coins": coins_data
	}
	
	main.save_manager.save_full_state(full_state)

func load_saved_data() -> void:
	if not main or not main.save_manager: return
	var data = main.save_manager.load_full_state()
	if data.is_empty():
		main.update_pop_counter(0)
		return
		
	main.is_loading_save = true
	
	main.is_victory_shown = data.get("is_victory_shown", false)
	main.playtime_seconds = float(data.get("playtime_seconds", 0.0))
	main.best_speedrun_time = float(data.get("best_speedrun_time", 0.0))
	var loaded_pops = int(data.get("total_pops", 0))
	var loaded_coins = int(data.get("coins", 0))
	var loaded_upgrades = data.get("upgrades", {})
	var loaded_devices = data.get("devices", {})
	var loaded_player = data.get("player", {})
	var loaded_balloons = data.get("balloons", [])
	var loaded_room = data.get("current_room", "small_room")
	if loaded_room == "large_room": loaded_room = "medium_room"
	elif loaded_room in ["warehouse", "hyper_lab"]: loaded_room = "hangar"
	if not (main.shop_manager and main.shop_manager.rooms.has(loaded_room)):
		loaded_room = "small_room"
		
	var loaded_unlocked_rooms = data.get("unlocked_rooms", ["small_room"])
	var clean_unlocked_rooms: Array = []
	for r in loaded_unlocked_rooms:
		var target_r = r
		if target_r == "large_room": target_r = "medium_room"
		elif target_r in ["warehouse", "hyper_lab"]: target_r = "hangar"
		if main.shop_manager and main.shop_manager.rooms.has(target_r) and not clean_unlocked_rooms.has(target_r):
			clean_unlocked_rooms.append(target_r)
	if not clean_unlocked_rooms.has("small_room"):
		clean_unlocked_rooms.append("small_room")
		
	var loaded_prestige = int(data.get("prestige_level", 0))
	var loaded_helium = int(data.get("helium_atoms", 0))
	
	# 1. Restore Rooms & Devices
	if main.shop_manager:
		main.shop_manager.unlocked_rooms = clean_unlocked_rooms
		main.shop_manager.current_room = loaded_room
		main.shop_manager.coins = loaded_coins
		main.shop_manager.prestige_level = loaded_prestige
		main.shop_manager.helium_atoms = loaded_helium
	if main.shop_coins_label:
		var coin_multiplier: int = main.game_manager.turbo_coin_multiplier if main.game_manager and main.game_manager.turbo_mode_enabled else 1
		main.shop_coins_label.text = "Coin: " + main.format_number(loaded_coins * maxi(1, coin_multiplier)) + " 🎈"
			
		for up_id in loaded_upgrades.keys():
			if main.shop_manager.upgrades.has(up_id):
				var lvl = int(loaded_upgrades[up_id])
				main.shop_manager.upgrades[up_id]["level"] = lvl
				main.shop_manager.upgrade_purchased.emit(up_id, lvl)
				if up_id == "companion_drone":
					main._update_companion_drone_level(lvl)
					
		# Backwards compatibility migration for athlete_training
		if not loaded_upgrades.has("athlete_training") and main.shop_manager.upgrades.has("athlete_training"):
			var legacy_lvl = max(int(loaded_upgrades.get("energy_cap", 0)), int(loaded_upgrades.get("speed", 0)))
			if legacy_lvl > 0:
				main.shop_manager.upgrades["athlete_training"]["level"] = legacy_lvl
				main.shop_manager.upgrade_purchased.emit("athlete_training", legacy_lvl)
				
		for dev_id in loaded_devices.keys():
			if dev_id == "gravity_mode":
				main.current_gravity_idx = clampi(int(loaded_devices[dev_id]), 0, main.balloon_gravity_scales.size() - 1)
				continue
			if main.shop_manager.devices.has(dev_id):
				var d_info = loaded_devices[dev_id]
				if d_info is Dictionary:
					main.shop_manager.devices[dev_id]["level"] = int(d_info.get("level", 0))
					main.shop_manager.devices[dev_id]["count"] = int(d_info.get("count", 0))
				elif d_info is int or d_info is float:
					main.shop_manager.devices[dev_id]["level"] = int(d_info)
					main.shop_manager.devices[dev_id]["count"] = 1 if int(d_info) > 0 else 0
					
				if dev_id == "gravity_regulator":
					main.max_unlocked_gravity_idx = main.balloon_gravity_scales.size() - 1
					main.apply_gravity_to_active_balloons()
					

		# Clear existing placed devices
		for dev in main.active_placed_devices:
			if is_instance_valid(dev):
				dev.queue_free()
		main.active_placed_devices.clear()
		
		# Restore exact placed device instances at their exact coordinates
		var loaded_placed = data.get("placed_devices", [])
		for p_data in loaded_placed:
			var d_type = p_data.get("type", "")
			if not main.DEVICE_SCENES.has(d_type):
				continue
			if main.shop_manager and not main.shop_manager.devices.has(d_type):
				continue
			if main.env_main_room:
				var dev = main.DEVICE_SCENES[d_type].instantiate()
				dev.set_meta("device_type", d_type)
				dev.add_to_group("devices")
				main.env_main_room.add_child(dev)
				var pos_arr = p_data.get("pos", [0, 0.05, 0])
				dev.position = Vector3(pos_arr[0], pos_arr[1], pos_arr[2])
				dev.rotation.y = float(p_data.get("rot_y", 0.0))
				var d_lvl = int(p_data.get("level", 1))
				if d_lvl <= 0: d_lvl = 1
				if dev.has_method("setup_level"):
					dev.setup_level(d_lvl)
				else:
					dev.set("level", d_lvl)
				main.active_placed_devices.append(dev)
				
	# 2. Restore Progress & Stats in Game Manager
	if main.game_manager:
		main.game_manager.total_pops = loaded_pops
		main.game_manager.current_vent_level = int(loaded_upgrades.get("vent_rate", 0))
		main.game_manager.recalculate_effective_stats()
		
	# 3. Restore Player Transform & Stats
	if main.player and not loaded_player.is_empty():
		var pos_arr = loaded_player.get("pos", [13.5, 0.6, 0.0])
		var target_pos = Vector3(pos_arr[0], max(float(pos_arr[1]), 0.6), pos_arr[2])
		
		var room_w = 16.0
		var room_l = 16.0
		if main.shop_manager and main.shop_manager.has_method("get_current_room_data"):
			var r_data = main.shop_manager.get_current_room_data()
			if r_data.has("floor_size"):
				room_w = r_data["floor_size"].x
				room_l = r_data["floor_size"].y
			
		var half_w = room_w / 2.0
		var half_l = room_l / 2.0
		var in_main_room = abs(target_pos.x) < (half_w - 0.8) and abs(target_pos.z) < (half_l - 0.8)
		
		if not in_main_room:
			target_pos = Vector3(half_w - 2.5, 0.6, 0.0)
			
		target_pos.y = max(target_pos.y, 0.6)
		main.player.global_position = target_pos
		main.player.velocity = Vector3.ZERO
		main.player.rotation.y = loaded_player.get("rot_y", 0.0)
		if main.player.head:
			main.player.head.rotation.x = loaded_player.get("head_pitch", 0.0)
		main.player.current_energy = loaded_player.get("energy", main.player.max_energy)
		main.player.energy_changed.emit(main.player.current_energy, main.player.max_energy, main.player.is_exhausted)
		
	# 4. Restore Exact Active Balloons in Room
	if main.balloon_container and main.balloon_scene:
		for c in main.balloon_container.get_children():
			c.queue_free()
			
		var safe_balloons = loaded_balloons.slice(0, min(loaded_balloons.size(), 250))
		for b_data in safe_balloons:
			var balloon = main.balloon_scene.instantiate()
			var pos_arr = b_data.get("pos", [0, 2, 0])
			var vel_arr = b_data.get("vel", [0, 0, 0])
			var col_str = b_data.get("color", "ff4757")
			var saved_tier := int(b_data.get("tier", 1))
			if main.spawner_controller:
				saved_tier = main.spawner_controller.clamp_tier_for_current_room(saved_tier)
			
			balloon.position = Vector3(pos_arr[0], pos_arr[1], pos_arr[2])
			main.balloon_container.add_child(balloon)
			balloon.setup_tier(saved_tier)
			balloon.setup_gas_type(str(b_data.get("gas", "normal")))
			balloon.special_seconds_left = clampf(float(b_data.get("special_seconds_left", -1.0)), -1.0, 10.0)
			if balloon.special_seconds_left >= 0.0:
				balloon.set_process(true)
			
			if balloon is RigidBody3D:
				var idx = clamp(main.current_gravity_idx, 0, main.balloon_gravity_scales.size() - 1)
				balloon.linear_velocity = Vector3(vel_arr[0], vel_arr[1], vel_arr[2])
				balloon.apply_room_physics(main.balloon_gravity_scales[idx], main.balloon_linear_damps[idx])
				
			if balloon.has_method("set_balloon_color"):
				balloon.set_balloon_color(Color.from_string(col_str, Color("#ff4757")))
				
			if balloon.has_signal("popped"):
				balloon.popped.connect(func(_b, pos, col, combo = 0, b_type = 0, is_midair = false): 
					var now_sec = Time.get_ticks_msec() / 1000.0
					var fan_blown = (now_sec - _b.blown_by_fan_time) < 4.0 if ("blown_by_fan_time" in _b) else false
					var magnet_pulled = (now_sec - _b.pulled_by_magnet_time) < 4.0 if ("pulled_by_magnet_time" in _b) else false
					var pop_src = str(_b.last_pop_source)
					
					var combo_mult = 1
					var combo_tag = ""
					if fan_blown and magnet_pulled:
						combo_mult = 5
						combo_tag = "combo_triple"
					elif fan_blown and (pop_src == "electric_grid" or pop_src == "laser_fence"):
						combo_mult = 3
						combo_tag = "combo_airsweep"
					elif magnet_pulled and pop_src == "spike_wall":
						combo_mult = 2
						combo_tag = "combo_vortex"

					if main.game_manager: 
						main.game_manager.on_balloon_popped(pos, col, combo, b_type, is_midair, pop_src, combo_mult)
					main.spawner_controller.show_pop_visual(pos, combo, b_type, _b.gas_type, is_midair, combo_tag, combo_mult)
				)
				
		if main.game_manager:
			main.game_manager.active_balloons = main.game_manager.get_total_effective_balloons()
			
	# 5. Restore Active Floor Coins
	var loaded_floor_coins = data.get("floor_coins", [])
	if main.coin_container and is_instance_valid(main.coin_container):
		for c in main.coin_container.get_children():
			c.queue_free()
		for cd in loaded_floor_coins:
			if main.coin_scene:
				var coin = main.coin_scene.instantiate()
				main.coin_container.add_child(coin)
				var pos_arr = cd.get("pos", [0, 0.08, 0])
				var pos = Vector3(pos_arr[0], pos_arr[1], pos_arr[2])
				var val = int(cd.get("val", 1))
				coin.global_position = pos
				coin.upgrade_tier(val, false)
				coin.set("is_grounded", cd.get("grounded", true))
				coin.set("is_settled", true)
			
	main.update_pop_counter(loaded_pops)
	main.update_ceiling_vents()
	main.update_all_shop_cards()
	
	# Restore saved theme
	var loaded_theme = data.get("active_theme", "clean_lab")
	if main.theme_controller:
		main.theme_controller.apply_theme(loaded_theme)
		
	if main.is_victory_shown and main.room_controller and main.room_controller.has_method("open_exit_door"):
		main.room_controller.open_exit_door()
	
	if main.factory:
		main.factory.restore(data.get("factory", {}))
	main.bonus_controller.restore(data.get("bonuses", {}))
	# Older saves contain weighted progression; keep earned progress, but reset
	# rate windows and quests so weighted points do not distort physical-pop goals.
	if int(data.get("version", 0)) >= 9:
		main.game_manager.restore_activity(data.get("activity", {}))
		main.quest_manager.restore(data.get("quest", {}))
	else:
		var old_activity: Dictionary = data.get("activity", {})
		main.game_manager.restore_activity({"session_elapsed": old_activity.get("session_elapsed", 0.0)})
	# Keep the independent test multipliers when resuming a saved run.
	main.game_manager.turbo_speed_multiplier = clampi(int(data.get("test_production_multiplier", 1)), 1, 4)
	main.game_manager.turbo_production_multiplier = float(main.game_manager.turbo_speed_multiplier)
	main.game_manager.turbo_pop_multiplier = clampi(int(data.get("test_progress_multiplier", 1)), 1, 4)
	main.game_manager.turbo_coin_multiplier = clampi(int(data.get("test_coin_multiplier", 1)), 1, 4)
	main.game_manager.turbo_mode_enabled = main.game_manager.turbo_speed_multiplier > 1 or main.game_manager.turbo_pop_multiplier > 1 or main.game_manager.turbo_coin_multiplier > 1
	# Restore a valid purchased weapon after upgrades and bonuses have loaded.
	var saved_slot = int(loaded_player.get("weapon_slot", 1))
	if saved_slot == 4 and main.player.minigun_purchased_level > 0:
		main.player.switch_weapon_slot(4)
	elif saved_slot == 3 and int(main.shop_manager.upgrades.shotgun_dart.level) > 0:
		main.player.switch_weapon_slot(3)
	elif saved_slot == 2 and int(main.shop_manager.upgrades.dart_gun.level) > 0:
		main.player.switch_weapon_slot(2)
	else:
		main.player.switch_weapon_slot(1)
	main.is_loading_save = false
	
	if main.game_manager:
		main.game_manager.start_game()
	if main.is_victory_shown:
		main.show_victory_screen(true)

func start_new_game() -> void:
	if not main: return
	get_tree().paused = false
	main.is_victory_shown = false
	main.playtime_seconds = 0.0
	if main.device_placement:
		if main.device_placement.is_carrying(): main.device_placement.cancel_carrying_device()
		for dev in main.active_placed_devices:
			if is_instance_valid(dev): dev.queue_free()
		main.active_placed_devices.clear()
	if main.factory: main.factory.restore({})
	for device in main.shop_manager.devices.values(): device["count"] = 0
	if main.balloon_container:
		for c in main.balloon_container.get_children():
			c.queue_free()
			
	if main.game_manager:
		main.game_manager.total_pops = 0
		main.game_manager.active_balloons = 0
		main.game_manager.restore_activity({})
		main.quest_manager.restore({})
		main.bonus_controller.restore({})
		main.game_manager.current_vent_level = 0
		main.game_manager.current_cap_level = 0
		main.player.minigun_heat = 0.0
		main.player.minigun_overheated = false
		main.player.minigun_cooldown_left = 0.0
		
	if main.shop_manager:
		main.shop_manager.coins = 0
		main.shop_manager.current_room = "small_room"
		main.shop_manager.unlocked_rooms = ["small_room"]
		
		for up_id in main.shop_manager.upgrades.keys():
			main.shop_manager.upgrades[up_id]["level"] = 0
			main.shop_manager.upgrade_purchased.emit(up_id, 0)
			
		for dev_id in main.shop_manager.devices.keys():
			main.shop_manager.devices[dev_id]["level"] = 0
			main._on_device_purchased(dev_id, 0)
			
	main.apply_room_layout("small_room")
	if main.theme_controller:
		main.theme_controller.apply_theme("clean_lab")
	if main.room_controller and main.room_controller.has_method("lock_exit_door"):
		main.room_controller.lock_exit_door()
	
	if main.player:
		main.player.global_position = Vector3(5.5, 0.6, 0.0)
		main.player.velocity = Vector3.ZERO
		main.player.rotation = Vector3.ZERO
		if main.player.head:
			main.player.head.rotation = Vector3.ZERO
		main.player.current_energy = main.player.max_energy
		main.player.is_exhausted = false
		main.player.energy_changed.emit(main.player.current_energy, main.player.max_energy, main.player.is_exhausted)
		if main.player.has_method("set_ui_open"):
			main.player.set_ui_open(false)
			
	main.update_all_shop_cards()
	main.update_pop_counter(0)
	
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	save_current_data()
	
	if main.game_manager:
		main.game_manager.recalculate_effective_stats()
		main.game_manager.start_game()
		main._on_active_count_changed(main.game_manager.active_balloons, main.game_manager.max_room_balloons)

func perform_prestige() -> void:
	if not main or not main.shop_manager: return
	get_tree().paused = false
	if main.device_placement and main.device_placement.is_carrying():
		main.device_placement.cancel_carrying_device()
	if main.factory: main.factory.restore({})
	for dev in main.active_placed_devices:
		if is_instance_valid(dev): dev.queue_free()
	main.active_placed_devices.clear()
	var total = main.game_manager.total_pops if main.game_manager else 1000000
	var _he_earned = main.shop_manager.perform_prestige(total)
	
	if main.modal_manager:
		main.modal_manager.hide_victory_modal()
	if main.player and main.player.has_method("set_ui_open"):
		main.player.set_ui_open(false)
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	
	# Reset speedrun playtime for the next prestige lap
	main.playtime_seconds = 0.0
	main.is_victory_shown = false
	
	main.apply_room_layout("small_room")
	if main.player:
		main.player.global_position = Vector3(5.5, 0.6, 0.0)
		main.player.velocity = Vector3.ZERO
	if main.game_manager:
		main.game_manager.total_pops = 0
		main.game_manager.active_balloons = 0
		main.game_manager.restore_activity({})
		main.quest_manager.restore({})
		main.bonus_controller.restore({})
		main.game_manager.current_vent_level = 0
		main.game_manager.current_cap_level = 0
		main.game_manager.recalculate_effective_stats()
		main.game_manager.start_game()
	if main.balloon_container:
		for b in main.balloon_container.get_children():
			b.queue_free()
			
	main.update_all_shop_cards()
	main.update_pop_counter(0)
	save_current_data()

func load_room_preset(room_id: String) -> void:
	if not main or not main.shop_manager or not main.game_manager: return
	if not main.shop_manager.rooms.has(room_id): return
	
	if main.device_placement:
		if main.device_placement.is_carrying(): main.device_placement.cancel_carrying_device()
		for dev in main.active_placed_devices:
			if is_instance_valid(dev): dev.queue_free()
		main.active_placed_devices.clear()
	if main.factory: main.factory.restore({})
	if main.balloon_container:
		for b in main.balloon_container.get_children():
			b.queue_free()

	main.is_loading_save = true
	main.shop_manager.coins = 0
	main.shop_manager.current_room = room_id
	main.game_manager.restore_activity({})
	main.quest_manager.restore({})
	main.bonus_controller.restore({})
	if main.player:
		main.player.minigun_heat = 0.0
		main.player.minigun_overheated = false
		main.player.minigun_cooldown_left = 0.0

	var unlocked: Array = ["small_room"]
	var target_pops: int = 0
	var target_upgrades: Dictionary = {}
	var target_devices: Dictionary = {}
	var placed_devs: Array = []

	match room_id:
		"small_room":
			target_pops = 0
			unlocked = ["small_room"]
			target_upgrades = {"athlete_training": 0, "auto_pop": 0, "coin_magnet": 0, "dart_gun": 0, "shotgun_dart": 0, "minigun_weapon": 0, "pipe_count": 0, "splash_pop": 0, "vent_rate": 0, "companion_drone": 0}
			target_devices = {}
			placed_devs = []
		"medium_room":
			# Oda 1'de (Small Room: 0 - 15.000) alınabilecek TÜM maksimum cihazlar (Kapasite: 2 cihaz, Sv.2)
			# test_oda2.tscn açıldığında fabrikadaki kargo paletinde hazır bekler
			target_pops = 15000
			unlocked = ["small_room", "medium_room"]
			target_upgrades = {
				"athlete_training": 4,
				"auto_pop": 3,
				"splash_pop": 3,
				"dart_gun": 2,
				"shotgun_dart": 0,
				"minigun_weapon": 0,
				"coin_magnet": 3,
				"pipe_count": 1,
				"vent_rate": 5,
				"companion_drone": 0
			}
			target_devices = {
				"spike_wall": {"level": 2, "count": 1},
				"fan": {"level": 2, "count": 1}
			}
			placed_devs = []
		"hangar":
			# Oda 2'de (Medium Room: 15.000 - 250.000) alınabilecek TÜM maksimum cihazlar (Kapasite: 6 cihaz, Sv.4)
			# test_oda3.tscn açıldığında fabrikadaki kargo paletinde hazır bekler
			target_pops = 250000
			unlocked = ["small_room", "medium_room", "hangar"]
			target_upgrades = {
				"athlete_training": 6,
				"auto_pop": 5,
				"splash_pop": 5,
				"dart_gun": 4,
				"shotgun_dart": 3,
				"minigun_weapon": 0,
				"coin_magnet": 5,
				"pipe_count": 3,
				"vent_rate": 6,
				"companion_drone": 2
			}
			target_devices = {
				"spike_wall": {"level": 4, "count": 2},
				"fan": {"level": 4, "count": 2},
				"magnet_pylon": {"level": 3, "count": 1},
				"electric_wall": {"level": 3, "count": 1}
			}
			placed_devs = []

	main.shop_manager.unlocked_rooms = unlocked
	main.game_manager.total_pops = target_pops
	main.game_manager.active_balloons = 0
	main.game_manager.current_vent_level = int(target_upgrades.get("vent_rate", 0))
	main.game_manager.current_cap_level = 0

	for u_id in main.shop_manager.upgrades.keys():
		var lvl = int(target_upgrades.get(u_id, 0))
		main.shop_manager.upgrades[u_id]["level"] = lvl
		main.shop_manager.upgrade_purchased.emit(u_id, lvl)

	main.apply_room_layout(room_id)

	# Önceki odalarda alınabilen tüm cihazlar fabrikaya kargo paketi olarak teslim edilir
	if main.factory:
		main.factory.orders.clear()
		for d_id in main.shop_manager.devices.keys():
			var d_info = target_devices.get(d_id, {"level": 0, "count": 0})
			var d_lvl = int(d_info.get("level", 0))
			var d_cnt = int(d_info.get("count", 0))
			main.shop_manager.devices[d_id]["level"] = d_lvl
			main.shop_manager.devices[d_id]["count"] = d_cnt
			main._on_device_purchased(d_id, d_lvl)
			if d_cnt > 0 and d_lvl > 0:
				for _i in range(d_cnt):
					main.factory.orders.append({"id": d_id, "level": d_lvl})
		main.factory.refresh()
	
	if main.env_main_room:
		for p_data in placed_devs:
			var d_type = p_data.get("type", "")
			if main.DEVICE_SCENES.has(d_type):
				var dev = main.DEVICE_SCENES[d_type].instantiate()
				dev.set_meta("device_type", d_type)
				dev.add_to_group("devices")
				main.env_main_room.add_child(dev)
				dev.position = p_data.get("pos", Vector3.ZERO)
				dev.rotation.y = float(p_data.get("rot_y", 0.0))
				var d_lvl = int(p_data.get("level", 1))
				if dev.has_method("setup_level"): dev.setup_level(d_lvl)
				else: dev.set("level", d_lvl)
				main.active_placed_devices.append(dev)

	if main.player:
		var half_l = main.shop_manager.get_current_room_data().floor_size.y * 0.5
		main.player.global_position = Vector3(0.0, 0.6, half_l - 3.0)
		main.player.velocity = Vector3.ZERO
		main.player.rotation.y = PI
		if main.player.head: main.player.head.rotation.x = 0.0
		# Silahları oyuncuya tanımla ve aktifleştir
		var dart_lvl = int(target_upgrades.get("dart_gun", 0))
		var shotgun_lvl = int(target_upgrades.get("shotgun_dart", 0))
		var minigun_lvl = int(target_upgrades.get("minigun_weapon", 0))
		if main.player.dart_weapon: main.player.dart_weapon.configure(dart_lvl)
		if main.player.shotgun_weapon: main.player.shotgun_weapon.configure(shotgun_lvl)
		main.player.minigun_purchased_level = minigun_lvl
		
		# En yüksek açık silahı eline ver (Oda 3'te Minigun [4] veya Pompalı [3])
		if minigun_lvl > 0:
			main.player.switch_weapon_slot(4)
		elif shotgun_lvl > 0:
			main.player.switch_weapon_slot(3)
		elif dart_lvl > 0:
			main.player.switch_weapon_slot(2)
		else:
			main.player.switch_weapon_slot(1)

		main.player.current_energy = main.player.max_energy
		main.player.is_exhausted = false
		main.player.energy_changed.emit(main.player.current_energy, main.player.max_energy, main.player.is_exhausted)
		if main.player.has_method("set_ui_open"):
			main.player.set_ui_open(false)

	main.update_ceiling_vents()
	main.update_all_shop_cards()
	main.update_pop_counter(target_pops)

	main.is_loading_save = false
	main.game_manager.recalculate_effective_stats()
	main.game_manager.start_game()
	main._on_active_count_changed(main.game_manager.active_balloons, main.game_manager.max_room_balloons)
	save_current_data()
