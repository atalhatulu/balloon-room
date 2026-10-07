extends SceneTree

var failures := 0
var checks := 0
var contact_count := 0
var contact_error := 100.0
var main: Node3D

func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		push_error(message)
	else:
		print("PASS: ", message)

func _init() -> void:
	if not OS.get_environment("XDG_DATA_HOME").begins_with("/tmp/balloon-room-"):
		push_error("Use XDG_DATA_HOME=/tmp/balloon-room-contact-tests to protect saves")
		quit(2)
		return
	run.call_deferred()

func balloon(pos: Vector3, kind: String = "normal") -> Node3D:
	var node = load("res://src/entities/balloon.tscn").instantiate()
	main.balloon_container.add_child(node)
	node.global_position = pos
	node.freeze = true
	node.setup_special_type(kind)
	return node

func capture(path: String) -> void:
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(path)

func run() -> void:
	main = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	await process_frame
	paused = false
	main.is_loading_save = true
	main.set_process(false)
	main.game_manager.is_game_started = false
	main.get_node("UI").hide()
	main.player.set_ui_open(false)
	main.player.set_process(false)
	main.player.set_physics_process(false)
	main.player.position = Vector3(0, 0, 5)
	main.player.rotation = Vector3.ZERO
	main.player.head.rotation = Vector3.ZERO
	main.player.camera.current = true
	for child in main.balloon_container.get_children():
		child.queue_free()
	await process_frame
	var hands = main.player.hands
	hands.needle_contact.connect(func(_target):
		contact_count += 1
		contact_error = hands.needle_mesh.to_global(Vector3(0, 0.16, 0)).distance_to(hands.last_contact_point)
	)
	var target = balloon(Vector3(0, 1.5, 2.8))
	await physics_frame
	await physics_frame
	main.player.execute_pop_hit(false)
	check(hands.contact_pending, "Raycast starts a surface-targeted strike")
	check(not target.is_popped, "Balloon remains intact before needle contact")
	main.player.execute_pop_hit(false)
	target.position.x += 0.10
	await create_timer(0.13).timeout
	check(contact_count == 1, "Repeated input does not replace or duplicate pending contact")
	check(contact_error < 0.005, "Needle tip follows moving balloon surface within 5 mm")
	check(not is_instance_valid(target) or target.is_popped, "Contact actually pops the balloon")

	target = balloon(Vector3(0, 1.5, 2.8))
	await physics_frame
	await physics_frame
	main.player.execute_pop_hit(false)
	main.player.set_ui_open(true, true)
	await create_timer(0.7).timeout
	check(not target.is_popped and not hands.contact_pending, "Opening UI cancels pending contact safely")
	var tablet_pos: Vector3 = hands.left_hand.position
	await create_timer(0.15).timeout
	check(tablet_pos.distance_to(hands.left_hand.position) < 0.005, "Tablet pose is not overwritten by idle animation")
	main.player.set_ui_open(false)
	await create_timer(0.4).timeout
	target.queue_free()
	await process_frame

	# An obstacle inserted during a strike must stop the pop.
	target = balloon(Vector3(0, 1.5, 2.8))
	await physics_frame
	await physics_frame
	main.player.execute_pop_hit(false)
	var wall := StaticBody3D.new()
	var collision := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = Vector3(2, 2, 0.1)
	collision.shape = shape
	wall.add_child(collision)
	main.add_child(wall)
	wall.position = Vector3(0, 1.5, 4)
	await create_timer(0.13).timeout
	check(not target.is_popped, "Needle cannot pop through intervening furniture/walls")
	wall.queue_free()
	target.queue_free()
	await process_frame

	var front = balloon(Vector3(0, 1.5, 2.3))
	var behind = balloon(Vector3(0, 1.5, 7.3))
	for b in [front, behind]:
		b.freeze = false
		b.gravity_scale = 0.0
		b.linear_damp = 0.0
	await physics_frame
	await physics_frame
	var energy: float = main.player.current_energy
	main.player.perform_nudge_slap()
	main.player.perform_nudge_slap()
	check(is_equal_approx(main.player.current_energy, energy), "Retired left-hand action does not consume energy")
	await create_timer(0.16).timeout
	check(front.linear_velocity.length() < 0.01, "Retired left-hand action applies no force")
	check(behind.linear_velocity.length() < 0.01, "Air pulse does not push balloons behind player")
	check(not hands.air_pending, "Air animation releases its action lock")
	front.queue_free()
	behind.queue_free()
	await process_frame

	check(not hands.left_hand.visible, "Left hand remains hidden after tablet closes")
	hands.arm_rig._process(0)
	check(hands.arm_rig.wrist_world.distance_to(hands.right_hand.to_global(Vector3(0, 0, 0.05))) < 0.001, "Arm reaches actual hand wrist")
	check(hands.arm_rig.shoulder_world.distance_to(main.player.global_position + main.player.global_basis * Vector3(0.24, 1.29, 0.05)) < 0.001, "Arm attaches to body shoulder")
	var normal = balloon(Vector3(-2, 1.5, 1.8))
	var gold = balloon(Vector3(-0.8, 1.5, 1.8), "gold")
	var air = balloon(Vector3(0.5, 1.5, 1.8), "electric")
	var bomb = balloon(Vector3(1.8, 1.5, 1.8), "bomb")
	check(normal.mesh_instance.mesh == gold.mesh_instance.mesh, "Balloon bodies share cached geometry")
	check(gold.mesh_instance.has_node("GasSignature") and air.mesh_instance.has_node("GasSignature") and bomb.mesh_instance.has_node("GasSignature"), "Special balloons have visible identifying details")
	var coins: Array = []
	for i in range(4):
		var coin = load("res://src/entities/coin.tscn").instantiate()
		main.coin_container.add_child(coin)
		coin.init(Vector3(-1.8 + i * 1.2, 1.0, 2.2), [1, 5, 10, 50][i], [1, 5, 10, 50][i])
		coin.set_process(false)
		coin.mesh_instance.rotation.x = PI / 3.0
		coins.append(coin)
	check(coins[0].mesh_instance.mesh == coins[3].mesh_instance.mesh, "Minted coins share cached relief geometry")
	var props = main.get_node("Environment/MainRoom/LabProps")
	check(props.get_node("RoomFurnishings").get_child_count() >= 4, "All walls have furnished modules")

	if "--capture" in OS.get_cmdline_user_args():
		root.size = Vector2i(1280, 720)
		await create_timer(0.25).timeout
		await capture("/tmp/balloon-room-design-first-person.png")
		var overview := Camera3D.new()
		main.add_child(overview)
		overview.position = Vector3(7.0, 4.0, 7.0)
		overview.look_at(Vector3(0, 2.0, -2))
		overview.current = true
		await capture("/tmp/balloon-room-design-room.png")
		overview.current = false
		main.player.camera.current = true
		for b in [normal, gold, air, bomb]:
			b.hide()
		for c in coins:
			c.hide()
		var contact_balloon = balloon(Vector3(0, 1.5, 3.25), "normal")
		var surface: Dictionary = contact_balloon.get_surface_hit(main.player.camera.global_position, -main.player.camera.global_basis.z)
		hands.play_target_stab(contact_balloon, surface.position, surface.normal, 0.075)
		hands._right_tween.pause()
		hands.set_process(false)
		hands._advance_strike(1.0)
		await capture("/tmp/balloon-room-design-contact.png")
		hands.cancel_actions()
		hands.set_process(true)
		contact_balloon.queue_free()
		main.player._next_air_time = 0
		main.player.perform_nudge_slap()
		await create_timer(0.15).timeout
		await capture("/tmp/balloon-room-design-air.png")
	print("CONTACT & DESIGN: %d checks, %d failures" % [checks, failures])
	main.queue_free()
	await process_frame
	quit(1 if failures else 0)
