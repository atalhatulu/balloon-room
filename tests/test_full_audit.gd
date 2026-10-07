extends SceneTree

# Full Headless System Audit & Regression Test Suite
# Tests all core game systems, controllers, entities, and devices

var passed_count: int = 0
var failed_count: int = 0

func _init() -> void:
	print("\n==========================================")
	print("       BALLOON ROOM FULL AUDIT SUITE       ")
	print("==========================================\n")
	
	run_tests()

func run_tests() -> void:
	# 1. Test Scene Load
	print("[TEST 1] Loading scenes/main.tscn...")
	var main_scene = load("res://scenes/main.tscn")
	if not main_scene:
		_record_failure("scenes/main.tscn could not be loaded!")
		quit(1)
		return
	_record_success("scenes/main.tscn loaded successfully.")
	
	var main = main_scene.instantiate()
	root.add_child(main)
	
	# Wait one frame for _ready
	await process_frame
	
	# 2. Test Core Node References
	print("[TEST 2] Verifying Core Nodes & Controllers...")
	_assert_not_null(main.game_manager, "game_manager")
	_assert_not_null(main.shop_manager, "shop_manager")
	_assert_not_null(main.sound_manager, "sound_manager")
	_assert_not_null(main.save_manager, "save_manager")
	_assert_not_null(main.room_controller, "room_controller")
	_assert_not_null(main.device_placement, "device_placement")
	_assert_not_null(main.shop_ui, "shop_ui")
	_assert_not_null(main.theme_controller, "theme_controller")
	_assert_not_null(main.player, "player")
	_assert_not_null(main.balloon_container, "balloon_container")
	_assert_not_null(main.coin_container, "coin_container")
	
	# 3. Test Room Layout Switching
	print("[TEST 3] Testing Room Layouts & Scaling...")
	for room_id in ["small_room", "medium_room", "large_room", "mega_hangar"]:
		main.apply_room_layout(room_id)
		var current_r = main.shop_manager.get_current_room_data()
		_assert_true(main.room_controller.active_vent_positions.size() > 0, "Vent positions generated for " + room_id)
		_record_success("Room layout applied: " + room_id + " (Vents: " + str(main.room_controller.active_vent_positions.size()) + ")")
		
	# 4. Test Balloon Spawning & Physics
	print("[TEST 4] Testing Balloon Spawning & Dynamic Tiers & Realistic Physics...")
	main.drop_balloons_from_vent(10)
	await process_frame
	var b_count = main.balloon_container.get_child_count()
	_assert_true(b_count == 10, "10 balloons spawned in container (got " + str(b_count) + ")")
	
	var b_sample = main.balloon_container.get_child(0)
	_assert_true(b_sample.mass > 0.01, "Balloon has valid physical mass (%f kg)" % b_sample.mass)
	_assert_true(b_sample.physics_material_override != null and b_sample.physics_material_override.bounce > 0.1, "Balloon has realistic rubber bounce (%f)" % b_sample.physics_material_override.bounce)
	
	# Test Tier 50 mass scaling
	b_sample.setup_tier(50)
	_assert_true(b_sample.mass >= 2.0, "Tier 50 cosmic balloon has heavy mass (>= 2.0 kg)")
	b_sample.apply_elastic_impact(Vector3(0, -5, 0))
	await process_frame
	
	# 5. Test Balloon Pop Mechanics
	print("[TEST 5] Testing Balloon Pop & Coin Generation...")
	var initial_pops = main.game_manager.total_pops
	var first_balloon = main.balloon_container.get_child(0)
	if first_balloon and first_balloon.has_method("pop"):
		first_balloon.pop("audit_test")
		await process_frame
		_assert_true(main.game_manager.total_pops > initial_pops, "Pop registered in GameManager")
	else:
		_record_failure("First balloon has no pop() method!")
		
	# 6. Test Save / Load Integrity (Atomic write & load)
	print("[TEST 6] Testing Save & Load Atomic Operations...")
	var test_state = {
		"version": 2,
		"coins": 9999,
		"total_pops": 1234,
		"current_room": "medium_room",
		"devices": {
			"fan": {"level": 2, "count": 1}
		}
	}
	var save_res = main.save_manager.save_full_state(test_state)
	_assert_true(save_res, "save_full_state returned true")
	var loaded_state = main.save_manager.load_full_state()
	_assert_true(loaded_state.get("coins") == 9999, "Saved coins verified (9999)")
	_assert_true(loaded_state.get("total_pops") == 1234, "Saved pops verified (1234)")
	_assert_true(loaded_state.get("current_room") == "medium_room", "Saved room verified (medium_room)")
	
	# 7. Test Device Placement & Carrying
	print("[TEST 7] Testing Device Placement System...")
	main.start_carrying_device("spike_wall")
	_assert_not_null(main.device_placement.carried_device, "carried_device created")
	_assert_true(main.device_placement.carried_device.visible, "carried_device is visible")
	
	# Place the carried device
	main.place_carried_device()
	await process_frame
	_assert_true(main.device_placement.active_placed_devices.size() > 0, "Device added to active_placed_devices")
	_assert_null(main.device_placement.carried_device, "carried_device cleared after placement")
	
	# 8. Test Device Upgrades
	print("[TEST 8] Testing Device Tech Upgrades...")
	var dev_node = main.device_placement.active_placed_devices[0]
	main.shop_manager.coins = 100000
	main.game_manager.total_pops = 100000
	main.device_placement.upgrade_specific_device(dev_node)
	_assert_true(dev_node.get("level") >= 1, "Device level upgraded")
	
	# 9. Test Shop Modal & Filtering
	print("[TEST 9] Testing Shop UI Controller...")
	main.toggle_shop_modal()
	_assert_true(main.shop_modal.visible, "Shop modal opened")
	main.shop_ui.set_category_filter("devices")
	_assert_true(main.shop_ui.current_filter == "devices", "Filter set to devices")
	main.toggle_shop_modal()
	_assert_false(main.shop_modal.visible, "Shop modal closed")
	
	# 10. Test Locked Authentic Laboratory Theme & Lab Props
	print("[TEST 10] Testing Authentic Material Testing Lab Theme & Props...")
	_assert_true(main.theme_controller.active_theme_id == "clean_lab", "Theme locked to clean_lab")
	main.theme_controller.apply_theme("any_other")
	_assert_true(main.theme_controller.active_theme_id == "clean_lab", "Theme remains strictly locked to clean_lab")
	
	var lab_props = main.get_node_or_null("Environment/MainRoom/LabProps")
	_assert_true(lab_props != null, "LabProps node created and present in MainRoom")
	if lab_props:
		_assert_true(lab_props.get_node_or_null("HVAC_Ductwork") != null, "HVAC Ductwork prop present")
		_assert_true(lab_props.get_node_or_null("FluorescentFixtures") != null, "FluorescentFixtures prop present")
	# 11. Test Elemental Reactions & Room Pressure
	print("[TEST 11] Testing Elemental Gas Reactions & Room Pressure...")
	var b_scene = load("res://src/entities/balloon.tscn")
	var b_elem = b_scene.instantiate()
	main.balloon_container.add_child(b_elem)
	b_elem.setup_gas_type("electric")
	_assert_true(b_elem.gas_type == "electric", "Balloon initialized with electric gas")
	b_elem.pop("test_electric")
	await process_frame
	
	main._on_active_count_changed(150, 150)
	_assert_true(main.current_pressure_ratio >= 1.0, "Critical pressure detected (>= 100%)")
	main._on_active_count_changed(50, 150)
	_assert_true(main.current_pressure_ratio < 0.60, "Overpressure relief threshold triggered (< 60%)")
	
	# 12. Test Exit Door, Green Pipes, Camera Delay & Enhanced Coins
	print("[TEST 12] Testing Exit Door, Green Pipes, Camera Delay & Enhanced Coins...")
	var exit_door = main.room_controller.exit_door if main.room_controller else null
	_assert_not_null(exit_door, "ExitDoor node exists in environment")
	if exit_door:
		_assert_true(exit_door.is_locked, "Exit door starts in locked state")
		_assert_false(exit_door.is_open, "Exit door starts closed")
		main.show_victory_screen()
		_assert_false(exit_door.is_locked, "Exit door unlocks on game victory")
		_assert_true(exit_door.is_open, "Exit door opens on game victory")
		
	# Verify camera lag variables exist on player
	_assert_true("target_cam_offset" in main.player, "Player has camera translation lag offset")
	_assert_true("target_cam_tilt" in main.player, "Player has camera banking tilt")
	_assert_true("target_yaw" in main.player, "Player has smooth camera yaw target")
	
	# Verify coin enhanced physics and tiers
	var coin_scene = load("res://src/entities/coin.tscn")
	var coin_inst = coin_scene.instantiate()
	main.coin_container.add_child(coin_inst)
	coin_inst.init(Vector3(0, 2, 0), 10, 10)
	_assert_true("tumble_speed" in coin_inst, "Coin has tumbling tumble_speed physics")
	_assert_true("bounce_count" in coin_inst, "Coin has multi-bounce squash logic")
	_assert_true("is_settled" in coin_inst, "Coin has gyro wobble settling state")
	coin_inst.queue_free()
	
	# Verify pipe spawn sound and white circle removal
	_assert_true(main.sound_manager.has_method("play_vent_spawn"), "SoundManager has play_vent_spawn method")
	main.sound_manager.play_vent_spawn()
	_assert_false("_spawn_vent_puff" in main, "White circle puff function removed from main")
	
	# Verify sparkling coin pickup sound system
	_assert_true(main.sound_manager.has_method("play_coin_pickup"), "SoundManager has play_coin_pickup method")
	main.sound_manager.play_coin_pickup(1)
	main.sound_manager.play_coin_pickup(10)
	main.sound_manager.play_coin_pickup(50)
	
	# Verify Splash Pop & Needle Reach Mechanics
	print("[TEST 12b] Testing Splash Pop Trigger & Dynamic Needle Reach...")
	main.player.splash_radius = 4.0
	main.player.splash_max_targets = 5
	_assert_true(main.player.has_method("trigger_splash_pop"), "Player has trigger_splash_pop method")
	_assert_true(main.player.hands.has_method("play_stab"), "Player hands have play_stab method")
	main.player.hands.play_stab(2.5) # Reach forward test
	_assert_not_null(main.player.hands._right_tween, "Needle reach tween created on play_stab")
	
	# 13. Testing Power Outage, Exit Door Interactive Toggle, & Generator Room
	print("[TEST 13] Testing Power Outage, Interactive Door & Power Room...")
	_assert_not_null(main.room_controller.exit_door, "ExitDoor controller node")
	_assert_not_null(main.room_controller.power_room, "PowerRoom generator room node")
	
	# Test Door toggle (Test 12 opened the door during victory test, so close it first)
	main.room_controller.close_exit_door()
	_assert_false(main.room_controller.exit_door.is_open, "Exit door closed with close_exit_door")
	main.room_controller.toggle_exit_door()
	_assert_true(main.room_controller.exit_door.is_open, "Exit door opened with toggle")
	main.room_controller.toggle_exit_door()
	_assert_false(main.room_controller.exit_door.is_open, "Exit door closed with second toggle")
	
	# Test Blackout trigger
	_assert_false(main.is_blackout, "Power active initially")
	main.trigger_blackout()
	_assert_true(main.is_blackout, "Blackout triggered")
	_assert_true(main.player.is_flashlight_on, "Player flashlight auto-activated during blackout")
	_assert_false(main.room_controller.power_room.is_power_active, "Power room breaker tripped down")
	
	# Test Power restore
	main.restore_power()
	_assert_false(main.is_blackout, "Power restored")
	_assert_true(main.room_controller.power_room.is_power_active, "Power room breaker active")
	_assert_true(main.sound_manager.has_method("play_power_trip"), "SoundManager has play_power_trip")
	
	# 13. Summary
	print("\n==========================================")
	print("AUDIT RESULTS: %d PASSED, %d FAILED" % [passed_count, failed_count])
	print("==========================================\n")
	
	main.queue_free()
	await process_frame
	await process_frame
	if failed_count > 0:
		quit(1)
	else:
		quit(0)

func _record_success(msg: String) -> void:
	passed_count += 1
	print("  [PASS] ", msg)

func _record_failure(msg: String) -> void:
	failed_count += 1
	printerr("  [FAIL] ", msg)

func _assert_not_null(val: Variant, name_str: String) -> void:
	if val != null and is_instance_valid(val):
		_record_success(name_str + " is valid and not null.")
	else:
		_record_failure(name_str + " is NULL or invalid!")

func _assert_null(val: Variant, name_str: String) -> void:
	if val == null:
		_record_success(name_str + " is null as expected.")
	else:
		_record_failure(name_str + " is NOT null!")

func _assert_true(cond: bool, msg: String) -> void:
	if cond:
		_record_success(msg)
	else:
		_record_failure(msg)

func _assert_false(cond: bool, msg: String) -> void:
	if not cond:
		_record_success(msg)
	else:
		_record_failure(msg)
