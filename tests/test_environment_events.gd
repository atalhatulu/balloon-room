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
	main.is_loading_save = true
	main.startup_modal.hide()
	var env: Environment = main.get_node("WorldEnvironment").environment
	var directional: Light3D = main.get_node("DirectionalLight3D")
	var original_energy := directional.light_energy
	var original_ambient := env.ambient_light_energy
	var pipe = main.room_controller.broken_pipe
	check(pipe != null and pipe.visible and not pipe.is_ruptured, "Visible intact pipe hazard exists before an outage")
	check(main.room_controller.power_room != null and main.room_controller.exit_door != null, "Maintenance room, generator panel and access door exist in the room")
	main.room_controller.exit_door.open_door()
	await create_timer(0.7).timeout
	var half_width: float = main.shop_manager.get_current_room_data().floor_size.x * 0.5
	var passage_ray := PhysicsRayQueryParameters3D.create(Vector3(half_width - 0.7, 1.4, 0), Vector3(half_width + 0.7, 1.4, 0), 1)
	passage_ray.exclude = [main.player.get_rid()]
	var passage_hit: Dictionary = main.get_world_3d().direct_space_state.intersect_ray(passage_ray)
	check(passage_hit.is_empty(), "Opening the service door gives physical access to the generator panel")
	main.environment_controller.trigger_blackout(false)
	await create_timer(0.75).timeout
	check(main.is_blackout and main.player.is_flashlight_on, "Grid outage activates blackout and player flashlight")
	check(directional.light_energy < original_energy * 0.1, "Directional room lighting dims during blackout")
	check(env.ambient_light_energy < original_ambient * 0.2 and env.background_energy_multiplier <= 0.11, "Ambient and background lighting dim during blackout")
	check(not pipe.is_ruptured, "Ordinary outage leaves the pressure pipe intact")
	check(main.hud_controller.maintenance_panel.visible and main.hud_controller.maintenance_label.text.contains("ELEKTRİK KESİK") and main.hud_controller.maintenance_hint.text.contains("m"), "HUD keeps a directional, distance-marked generator objective visible")
	main.player.global_position = Vector3(half_width + 1.4, 0.6, 0)
	main.player.rotation.y = -PI / 2.0
	main.player.head.rotation = Vector3.ZERO
	await physics_frame
	main.interaction_controller.update_interaction()
	check(main.interaction_controller.raycast_target_type == "breaker_panel", "Looking at the generator panel selects its E interaction")
	main.interaction_controller.handle_key_action("interact")
	await create_timer(0.8).timeout
	check(not main.is_blackout and not main.player.is_flashlight_on, "Power restoration clears blackout and flashlight")
	check(not main.hud_controller.maintenance_panel.visible, "Maintenance objective clears after power returns")
	check(is_equal_approx(directional.light_energy, original_energy) and is_equal_approx(env.ambient_light_energy, original_ambient), "Room lighting returns to its saved levels")
	main.environment_controller.trigger_blackout(true)
	check(pipe.is_ruptured, "Sustained overpressure ruptures the pipe")
	await create_timer(0.5).timeout
	check(main.hud_controller.maintenance_label.text.contains("BORU ARIZASI"), "Overpressure objective points to the ruptured pipe first")
	main.environment_controller.restore_power()
	check(main.is_blackout, "Power interlock blocks reset while the pipe is ruptured")
	main.environment_controller.repair_pipe()
	main.environment_controller.restore_power()
	check(not pipe.is_ruptured and not main.is_blackout, "Pipe repair allows the generator reset")
	print("ENVIRONMENT EVENTS: ", checks, " checks, ", failures, " failures")
	main.queue_free()
	await process_frame
	quit(1 if failures else 0)
