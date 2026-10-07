extends SceneTree

var failures := 0
var checks := 0

func check(ok: bool, label: String) -> void:
	checks += 1
	if ok:
		print("PASS: ", label)
	else:
		failures += 1
		push_error(label)

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
	main.is_loading_save = false
	main.startup_modal.hide()
	main.shop_manager.current_room = "medium_room"
	main.quest_manager._on_guide_room_switched("medium_room")
	check(main.quest_manager.automation_guide_stage == 1, "Oda two starts the setup guide")
	var crusher = load("res://src/devices/spike_wall.tscn").instantiate()
	crusher.set_meta("device_type", "spike_wall")
	crusher.position = Vector3.ZERO
	main.add_child(crusher)
	main.active_placed_devices.append(crusher)
	main.quest_manager._update_automation_guide(0.4)
	check(main.quest_manager.automation_guide_stage == 2, "Crusher placement advances the guide")
	var fan = load("res://src/devices/fan.tscn").instantiate()
	fan.set_meta("device_type", "fan")
	fan.position = Vector3(0, 0, 3)
	main.add_child(fan)
	main.active_placed_devices.append(fan)
	main.quest_manager._update_automation_guide(0.4)
	check(main.quest_manager.automation_guide_stage == 3, "Fan aimed at crusher advances the guide")
	var magnet = load("res://src/devices/magnet_pylon.tscn").instantiate()
	magnet.set_meta("device_type", "magnet_pylon")
	magnet.position = Vector3(0.5, 0, 0)
	main.add_child(magnet)
	main.active_placed_devices.append(magnet)
	main.quest_manager._update_automation_guide(0.4)
	check(main.quest_manager.automation_guide_stage == 4, "Magnet nested within one meter advances the guide")
	var coins_before: int = main.shop_manager.coins
	crusher.feedback.record_output(1)
	main.quest_manager._update_automation_guide(0.4)
	check(main.quest_manager.automation_guide_stage == 5 and main.shop_manager.coins == coins_before + 500, "First real crusher output completes the guide and pays once")
	main.quest_manager._update_automation_guide(0.4)
	check(main.shop_manager.coins == coins_before + 500, "Completed guide cannot pay twice")
	print("AUTOMATION GUIDE: ", checks, " checks, ", failures, " failures")
	main.queue_free()
	await process_frame
	quit(1 if failures else 0)
