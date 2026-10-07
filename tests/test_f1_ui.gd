extends SceneTree

var failures := 0

func check(ok: bool, label: String) -> void:
	if ok: print("PASS: ", label)
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
	main.game_manager.is_game_started = false
	main.game_manager.total_pops = 12000
	main.game_manager.session_elapsed_time = 180.0
	main.shop_manager.current_room = "medium_room"
	main.game_manager.balloons_per_second = 110.0
	main.game_manager.pop_sources = {"needle": 1100, "splash": 1500, "dart": 400, "spike_floor": 2000}
	main.game_manager.weapon_active_seconds = {"needle": 100.0, "dart": 40.0}
	main.game_manager.dart_shots = 100
	main.game_manager.dart_hit_shots = 60
	main.game_manager.minute_snapshots.clear()
	main.game_manager.minute_snapshots.append({"minute": 1, "room": "medium_room", "pops": 4000, "coins": 1000,
		"pop_sources": {"needle": 100, "splash": 500, "dart": 100, "spike_floor": 1000},
		"weapon_active_seconds": {"needle": 50.0, "dart": 20.0}, "dart_shots": 50, "dart_hit_shots": 30})
	main.debug_panel._refresh_analytics_view()
	var card: String = main.debug_panel.analytics_balance_lbl.text
	check(card.contains("60.000") and card.contains("48.000"), "F1 shows current room target and remaining physical pops")
	check(card.contains("İğne") and card.contains("Dart") and card.contains("40.0 balon/sn") and card.contains("15.0 balon/sn"), "F1 compares actual weapon output per active second")
	check(card.contains("Dart isabetli atış 60%"), "F1 reports dart shot accuracy")
	main.queue_free()
	await process_frame
	print("F1 UI: %d failures" % failures)
	quit(1 if failures else 0)
