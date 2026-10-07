extends SceneTree

var records: Array = []
func _init() -> void:
	if not OS.get_environment("XDG_DATA_HOME").begins_with("/tmp/balloon-room-"):
		quit(2)
		return
	run.call_deferred()
func run() -> void:
	root.size = Vector2i(1280, 720)
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	Engine.max_fps = 0
	seed(24571)
	var arena = load("res://scenes/stress_test.tscn").instantiate()
	root.add_child(arena)
	await process_frame
	for count in [100, 380, 720]:
		for moving in [false, true]:
			seed(24571 + count)
			arena.is_moving_mode = moving
			arena._change_target_count(count)
			await create_timer(1.5).timeout
			var frames: Array[float] = []
			var physics: Array[float] = []
			var draw_calls: Array[float] = []
			var primitives: Array[float] = []
			var start := Time.get_ticks_msec()
			var last := Time.get_ticks_usec()
			var shake := start
			while Time.get_ticks_msec() - start < 3500:
				await process_frame
				var now := Time.get_ticks_usec()
				frames.append((now - last) / 1000.0)
				last = now
				physics.append(Performance.get_monitor(Performance.TIME_PHYSICS_PROCESS) * 1000)
				draw_calls.append(Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME))
				primitives.append(Performance.get_monitor(Performance.RENDER_TOTAL_PRIMITIVES_IN_FRAME))
				if moving and Time.get_ticks_msec() - shake > 800:
					arena._apply_dynamic_physics()
					shake = Time.get_ticks_msec()
			frames.sort()
			var record := {"count": count, "moving": moving,
				"frame_mean_ms": average(frames), "frame_p95_ms": frames[int(frames.size() * 0.95)],
				"frame_p99_ms": frames[int(frames.size() * 0.99)], "physics_mean_ms": average(physics),
				"draw_calls_mean": average(draw_calls), "primitives_mean": average(primitives)}
			records.append(record)
			print(JSON.stringify(record))
	var suffix := "after" if "--after" in OS.get_cmdline_user_args() else "before"
	var file := FileAccess.open("/tmp/balloon-room-profile-" + suffix + ".json", FileAccess.WRITE)
	file.store_string(JSON.stringify(records, "  "))
	arena.queue_free()
	await process_frame
	quit()
func average(values: Array[float]) -> float:
	var total := 0.0
	for value in values: total += value
	return total / maxi(1, values.size())
