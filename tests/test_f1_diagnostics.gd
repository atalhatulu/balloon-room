extends SceneTree

const Diagnostics = preload("res://src/core/balance_diagnostics.gd")
var failures := 0

func check(ok: bool, label: String) -> void:
	if ok: print("PASS: ", label)
	else:
		failures += 1
		push_error(label)

func _init() -> void:
	var data := {"room": "medium_room", "pops": 12000, "seconds": 180.0, "coins": 2000,
		"actual_spawn_rate": 100.0, "nominal_spawn_rate": 110.0, "physical_balloons": 120,
		"physics_budget": 480, "physics_limited_seconds": 0.0, "production_enabled": true,
		"pop_sources": {"needle": 1100, "splash": 1500, "dart": 400, "spike_floor": 2000},
		"weapon_active_seconds": {"needle": 100.0, "dart": 40.0}, "dart_shots": 100, "dart_hit_shots": 60,
		"timeline_events": [{"minute": 2, "cost": 500}],
		"minute_snapshots": [{"minute": 1, "room": "medium_room", "pops": 4000, "coins": 1000, "physics_limited_seconds": 0.0,
			"pop_sources": {"needle": 100, "splash": 500, "dart": 100, "spike_floor": 1000},
			"weapon_active_seconds": {"needle": 50.0, "dart": 20.0}, "dart_shots": 50, "dart_hit_shots": 30}]}
	var result := Diagnostics.analyze(data)
	check(result.has_window and result.target == 60000 and result.remaining == 48000, "Room milestone uses real pops")
	check(is_equal_approx(result.pop_rate, 8000.0 / 120.0) and is_equal_approx(result.eta_minutes, 12.0), "ETA uses recent real pop rate")
	check(result.needle_pops == 2000 and result.dart_pops == 300 and result.device_pops == 1000, "Weapon and device pops stay separate")
	check(is_equal_approx(result.needle_pps, 40.0) and is_equal_approx(result.dart_pps, 15.0) and is_equal_approx(result.dart_hit_ratio, 0.6), "Active weapon time and shot accuracy are comparable")
	check(is_equal_approx(result.coin_per_pop, 1500.0 / 8000.0), "Coin rate adds purchases back to wallet delta")
	data.physical_balloons = 440
	check(Diagnostics.analyze(data).diagnosis.begins_with("Fizik bütçesi"), "Physical saturation takes priority")
	data.production_enabled = false
	check(Diagnostics.analyze(data).eta_minutes < 0.0, "Stopped production suppresses ETA")
	data.minute_snapshots = []
	check(not Diagnostics.analyze(data).has_window, "Insufficient samples do not invent a forecast")
	print("F1 DIAGNOSTICS: %d failures" % failures)
	quit(1 if failures else 0)
