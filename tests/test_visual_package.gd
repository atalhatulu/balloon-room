extends SceneTree

var failures: int = 0

func check(condition: bool, description: String) -> void:
	if not condition:
		failures += 1
		push_error(description)
	else:
		print("PASS: ", description)

func _init() -> void:
	# This scene exercises live managers; require an isolated user-data directory.
	if not OS.get_environment("XDG_DATA_HOME").begins_with("/tmp/balloon-room-"):
		push_error("Run with XDG_DATA_HOME=/tmp/balloon-room-visual-tests to protect player saves.")
		quit(2)
		return
	run.call_deferred()

func run() -> void:
	var main = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	await process_frame
	paused = false
	main.game_manager.is_game_started = false
	main.get_node("UI").hide()
	main.player.set_physics_process(false)
	var props = main.get_node("Environment/MainRoom/LabProps")
	for room_id in main.shop_manager.rooms:
		main.shop_manager.current_room = room_id
		main.apply_room_layout(room_id)
		var data = main.shop_manager.rooms[room_id]
		check(props.room_size == data.floor_size, room_id + " decor follows room dimensions")
		check(is_equal_approx(props.ceiling_height, data.ceiling_height), room_id + " decor follows ceiling")
		check(props.get_child_count() == 3, room_id + " has no duplicate decoration roots")
		var fixtures_attached := true
		for fixture in props.get_node("FluorescentFixtures").get_children():
			fixtures_attached = fixtures_attached and fixture.position.y < data.ceiling_height and fixture.position.y > data.ceiling_height - 0.3
		check(fixtures_attached, room_id + " fixtures attached below ceiling")
	main.shop_manager.current_room = "small_room"
	main.apply_room_layout("small_room")
	var devices: Array = []
	var n := 0
	for kind in ["spike_wall", "electric_wall", "magnet_pylon"]:
		var device = load("res://src/devices/" + kind + ".tscn").instantiate()
		main.get_node("Environment/MainRoom").add_child(device)
		device.position = Vector3(-4 + n * 4, 0, -1)
		device.setup_level(1)
		check(device.feedback.segments.size() == 8, kind + " status indicator created")
		device.feedback.update_state(0.1, 0.5)
		check(device.feedback.segments[0].emission_energy_multiplier > device.feedback.segments[7].emission_energy_multiplier, kind + " charge has readable progress")
		device.feedback.pulse()
		device.feedback.update_state(0.01, 0.0)
		check(device.feedback.flash > 0.0, kind + " successful action flashes")
		devices.append(device)
		n += 1
	var second = load("res://src/devices/electric_wall.tscn").instantiate()
	main.add_child(second)
	second.setup_level(1)
	check(second.neon_grid.material_override != devices[1].neon_grid.material_override, "Device materials are isolated per instance")
	second.queue_free()
	var effects: Array = []
	for kind in ["normal", "bomb", "air", "gold", "electric", "cryo"]:
		var effect = load("res://src/entities/pop_particle.tscn").instantiate()
		main.add_child(effect)
		effect.init(Color.RED, 1, kind)
		effects.append(effect)
		check(effect.emitting, kind + " burst emits")
		if kind in ["bomb", "air", "electric"]:
			check(effect.get_child_count() == 1, kind + " has shockwave visual")
	main.spawner_controller._active_float_labels = 14
	var before: int = main.shop_manager.coins
	main._on_balloon_popped_visual(Vector3.ZERO, 0, 1, "gold")
	check(main.shop_manager.coins > before, "Gold reward survives full floating-label budget")
	await create_timer(0.8).timeout
	for effect in effects:
		check(not is_instance_valid(effect), "Burst cleans itself up")
	if "--capture" in OS.get_cmdline_user_args():
		root.size = Vector2i(1280, 720)
		var cam := Camera3D.new()
		main.add_child(cam)
		cam.position = Vector3(8, 5.4, 8)
		cam.look_at(Vector3(0, 2.0, -1))
		cam.current = true
		main.drop_balloons_from_vent(35)
		await create_timer(0.4).timeout
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("/tmp/balloon-room-visual-package.png")
	print("VISUAL PACKAGE: ", failures, " failures")
	main.is_loading_save = true
	main.queue_free()
	await process_frame
	quit(1 if failures > 0 else 0)
