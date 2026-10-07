class_name RoomController
extends Node

signal room_layout_applied(room_id: String)
signal gravity_mode_changed(current_gravity_idx: int, mode_name: String, gravity_scale: float)
signal prompt_requested(text: String)
signal save_requested()

# Gravity Configuration & Tables (Stabilized constant 0.25 G laboratory gravity)
var balloon_gravity_scales: Array[float] = [0.25, 0.75, 1.60, 3.20, 6.00]
var balloon_linear_damps: Array[float] = [2.2, 1.4, 0.8, 0.35, 0.15]
var gravity_mode_names: Array[String] = [
	"0.25 G — Süzülme", "0.75 G — Hafif", "1.60 G — Hızlı iniş",
	"3.20 G — Ağır", "6.00 G — Yoğun üretim"
]
var current_gravity_idx: int = 0
var max_unlocked_gravity_idx: int = 4

# Vent Matrix Drop Points
var active_vent_positions: Array[Vector3] = []
var active_vent_nodes: Array[Node3D] = []
var vent_cycle_idx: int = 0

# Cached Scene & Node References
var _main: Node3D = null
var shop_manager: Node = null
var game_manager: Node = null
var sound_manager: Node = null
var balloon_container: Node3D = null

# Environment Nodes
var env_main_room: Node3D = null
var floor_body: StaticBody3D = null
var floor_mesh: MeshInstance3D = null
var floor_shape: CollisionShape3D = null

var ceiling_body: StaticBody3D = null
var ceiling_mesh: MeshInstance3D = null
var ceiling_shape: CollisionShape3D = null

var wall_north_body: StaticBody3D = null
var wall_north_mesh: MeshInstance3D = null
var wall_north_shape: CollisionShape3D = null

var wall_south_body: StaticBody3D = null
var wall_south_mesh: MeshInstance3D = null
var wall_south_shape: CollisionShape3D = null
var wall_east_right_body: StaticBody3D = null
var wall_east_right_mesh: MeshInstance3D = null
var wall_east_right_shape: CollisionShape3D = null

var wall_west_body: StaticBody3D = null
var wall_west_mesh: MeshInstance3D = null
var wall_west_shape: CollisionShape3D = null

var wall_east_body: StaticBody3D = null
var wall_east_mesh: MeshInstance3D = null
var wall_east_shape: CollisionShape3D = null

var ceiling_vents_container: Node3D = null
var main_room_light: OmniLight3D = null
var exit_door: Node3D = null
var power_room: Node3D = null
var broken_pipe: Node3D = null

var gravity_terminal: Node3D = null
var gravity_display_label: Label3D = null
var gravity_btn_mesh: MeshInstance3D = null

func setup(main_node: Node3D) -> void:
	_main = main_node
	max_unlocked_gravity_idx = balloon_gravity_scales.size() - 1
	shop_manager = main_node.get_node_or_null("ShopManager")
	game_manager = main_node.get_node_or_null("GameManager")
	sound_manager = main_node.get_node_or_null("SoundManager")
	balloon_container = main_node.get_node_or_null("BalloonContainer")
	
	env_main_room = main_node.get_node_or_null("Environment/MainRoom")
	if env_main_room:
		floor_body = env_main_room.get_node_or_null("Floor")
		if floor_body:
			floor_mesh = floor_body.get_node_or_null("MeshInstance3D")
			floor_shape = floor_body.get_node_or_null("CollisionShape3D")
			
		ceiling_body = env_main_room.get_node_or_null("Ceiling")
		if ceiling_body:
			ceiling_mesh = ceiling_body.get_node_or_null("MeshInstance3D")
			ceiling_shape = ceiling_body.get_node_or_null("CollisionShape3D")
			
		wall_north_body = env_main_room.get_node_or_null("WallNorth")
		if wall_north_body:
			wall_north_mesh = wall_north_body.get_node_or_null("MeshInstance3D")
			wall_north_shape = wall_north_body.get_node_or_null("CollisionShape3D")
			
		wall_south_body = env_main_room.get_node_or_null("WallSouth")
		if wall_south_body:
			wall_south_mesh = wall_south_body.get_node_or_null("MeshInstance3D")
			wall_south_shape = wall_south_body.get_node_or_null("CollisionShape3D")
		wall_west_body = env_main_room.get_node_or_null("WallWest")
		if wall_west_body:
			wall_west_mesh = wall_west_body.get_node_or_null("MeshInstance3D")
			wall_west_shape = wall_west_body.get_node_or_null("CollisionShape3D")
			
		wall_east_body = env_main_room.get_node_or_null("WallEast")
		if wall_east_body:
			wall_east_mesh = wall_east_body.get_node_or_null("MeshInstance3D")
			wall_east_shape = wall_east_body.get_node_or_null("CollisionShape3D")
			# The original scene shares these resources with the west wall.
			wall_east_mesh.mesh = wall_east_mesh.mesh.duplicate()
			wall_east_shape.shape = wall_east_shape.shape.duplicate()
			wall_east_right_body = env_main_room.get_node_or_null("WallEastRight")
			if not wall_east_right_body:
				wall_east_right_body = StaticBody3D.new()
				wall_east_right_body.name = "WallEastRight"
				wall_east_right_shape = CollisionShape3D.new()
				wall_east_right_shape.shape = BoxShape3D.new()
				wall_east_right_body.add_child(wall_east_right_shape)
				wall_east_right_mesh = MeshInstance3D.new()
				wall_east_right_mesh.mesh = BoxMesh.new()
				wall_east_right_mesh.material_override = wall_east_mesh.material_override
				wall_east_right_body.add_child(wall_east_right_mesh)
				env_main_room.add_child(wall_east_right_body)
			
		ceiling_vents_container = env_main_room.get_node_or_null("CeilingVents")
		
		# Add authentic material testing laboratory equipment matching reference photo
		var existing_props = env_main_room.get_node_or_null("LabProps")
		if not existing_props:
			var lab_props_script = load("res://src/environment/lab_props.gd")
			if lab_props_script:
				var props_instance = lab_props_script.new()
				props_instance.name = "LabProps"
				env_main_room.add_child(props_instance)

		# Add Emergency Rupture Pipe Hazard
		var existing_pipe = env_main_room.get_node_or_null("BrokenPipeHazard")
		if not existing_pipe:
			var pipe_script = load("res://src/environment/broken_pipe_hazard.gd")
			if pipe_script:
				broken_pipe = pipe_script.new()
				env_main_room.add_child(broken_pipe)
		else:
			broken_pipe = existing_pipe

		var existing_power = env_main_room.get_node_or_null("PowerRoom")
		if existing_power:
			power_room = existing_power
		else:
			power_room = load("res://src/environment/power_room.gd").new()
			power_room.name = "PowerRoom"
			env_main_room.add_child(power_room)
		var existing_exit = env_main_room.get_node_or_null("ExitDoor")
		if existing_exit:
			exit_door = existing_exit
		else:
			exit_door = load("res://src/environment/exit_door.gd").new()
			exit_door.name = "ExitDoor"
			env_main_room.add_child(exit_door)


	main_room_light = main_node.get_node_or_null("MainRoomLight")

	gravity_terminal = main_node.get_node_or_null("Environment/GravityTerminal")
	if gravity_terminal:
		gravity_display_label = gravity_terminal.get_node_or_null("DisplayLabel")
		gravity_btn_mesh = gravity_terminal.get_node_or_null("ButtonMesh")

	# Match the initial scene shell to its procedural decoration even at startup.
	if shop_manager:
		apply_room_layout(shop_manager.current_room)

func apply_room_layout(room_id: String) -> void:
	if not shop_manager or not shop_manager.rooms.has(room_id):
		return
		
	var r_data = shop_manager.rooms[room_id]
	var W: float = r_data["floor_size"].x
	var L: float = r_data["floor_size"].y
	var H: float = r_data["ceiling_height"]
	var half_w = W / 2.0
	var half_l = L / 2.0
	
	var lab_props = env_main_room.get_node_or_null("LabProps") if env_main_room else null
	if lab_props and lab_props.has_method("configure_room"):
		lab_props.configure_room(Vector2(W, L), H)

	var status_rig = env_main_room.get_node_or_null("RoomStatusRig")
	if status_rig:
		env_main_room.remove_child(status_rig)
		status_rig.queue_free()
	status_rig = preload("res://src/environment/room_status_rig.gd").new()
	status_rig.name = "RoomStatusRig"
	env_main_room.add_child(status_rig)
	status_rig.setup(_main, Vector2(W, L), H, ["small_room", "medium_room", "hangar"].find(room_id))

	# Rebuild room-specific moving details independently of batched furnishings.
	var atmosphere = env_main_room.get_node_or_null("FacilityAtmosphere") if env_main_room else null
	if atmosphere:
		env_main_room.remove_child(atmosphere)
		atmosphere.queue_free()
	if room_id == "medium_room" and env_main_room:
		atmosphere = preload("res://src/environment/facility_atmosphere.gd").new()
		atmosphere.name = "FacilityAtmosphere"
		env_main_room.add_child(atmosphere)
		atmosphere.setup(get_parent(), Vector2(W, L), H)

	# 1. Floor & Ceiling
	if floor_mesh and floor_mesh.mesh is BoxMesh:
		floor_mesh.mesh.size = Vector3(W, 0.5, L)
	if floor_shape and floor_shape.shape is BoxShape3D:
		floor_shape.shape.size = Vector3(W + 2.0, 4.0, L + 2.0)
		floor_shape.position = Vector3(0, -1.75, 0)
		
	if ceiling_body:
		ceiling_body.position.y = H + 0.25
	if ceiling_mesh and ceiling_mesh.mesh is BoxMesh:
		ceiling_mesh.mesh.size = Vector3(W, 0.5, L)
	if ceiling_shape and ceiling_shape.shape is BoxShape3D:
		ceiling_shape.shape.size = Vector3(W, 0.5, L)
		ceiling_shape.position = Vector3.ZERO
		
	# 2. North, South, West Walls
	if wall_north_body:
		wall_north_body.position = Vector3(0, H / 2.0, -half_l)
	if wall_north_mesh and wall_north_mesh.mesh is BoxMesh:
		wall_north_mesh.mesh.size = Vector3(W, H, 0.5)
	if wall_north_shape and wall_north_shape.shape is BoxShape3D:
		wall_north_shape.shape.size = Vector3(W, H, 0.5)
		
	if wall_south_body:
		wall_south_body.position = Vector3(0, H / 2.0, half_l)
	if wall_south_mesh and wall_south_mesh.mesh is BoxMesh:
		wall_south_mesh.mesh.size = Vector3(W, H, 0.5)
	if wall_south_shape and wall_south_shape.shape is BoxShape3D:
		wall_south_shape.shape.size = Vector3(W, H, 0.5)
		
	if wall_west_body:
		wall_west_body.position = Vector3(-half_w, H / 2.0, 0)
	if wall_west_mesh and wall_west_mesh.mesh is BoxMesh:
		wall_west_mesh.mesh.size = Vector3(0.5, H, L)
	if wall_west_shape and wall_west_shape.shape is BoxShape3D:
		wall_west_shape.shape.size = Vector3(0.5, H, L)
		
	# 3. East Wall with an access opening to the generator room.
	var east_doorway_width := 3.2
	var east_segment_length := (L - east_doorway_width) * 0.5
	if wall_east_body:
		wall_east_body.position = Vector3(half_w, H / 2.0, -(east_doorway_width * 0.5 + east_segment_length * 0.5))
	if wall_east_mesh and wall_east_mesh.mesh is BoxMesh:
		wall_east_mesh.mesh.size = Vector3(0.5, H, east_segment_length)
	if wall_east_shape and wall_east_shape.shape is BoxShape3D:
		wall_east_shape.shape.size = Vector3(0.5, H, east_segment_length)
	if wall_east_right_body and wall_east_right_mesh and wall_east_right_shape:
		wall_east_right_body.position = Vector3(half_w, H / 2.0, east_doorway_width * 0.5 + east_segment_length * 0.5)
		wall_east_right_mesh.mesh.size = Vector3(0.5, H, east_segment_length)
		wall_east_right_shape.shape.size = Vector3(0.5, H, east_segment_length)
		
	# 4. Exit Door Positioning (east wall, facing into the production room)
	if exit_door and is_instance_valid(exit_door):
		exit_door.position = Vector3(half_w - 0.14, 0.0, 0.0)
		exit_door.rotation = Vector3(0.0, -PI / 2.0, 0.0)

	# 5. PowerRoom (Maintenance Generator Room) positioned beyond the east doorway.
	if power_room and is_instance_valid(power_room):
		power_room.position = Vector3(half_w + 0.14, 0.0, 0.0)
		power_room.rotation = Vector3(0.0, PI / 2.0, 0.0)

	# 6. Pressure line (mounted just inside the west wall, facing into the room)
	if broken_pipe and is_instance_valid(broken_pipe):
		broken_pipe.position = Vector3(-half_w + 0.65, 1.85, 2.0)
		broken_pipe.rotation_degrees = Vector3(0, 90, 0)

	# 5. Room Lighting & Atmosphere (Balanced soft laboratory lighting)
	if main_room_light:
		main_room_light.position = Vector3(0, H - 0.7, 0)
		main_room_light.omni_range = max(18.0, W * 0.9)
		
		match room_id:
			"small_room":
				main_room_light.light_color = Color.WHITE
				main_room_light.light_energy = 1.3
			"medium_room":
				main_room_light.light_color = Color.WHITE
				main_room_light.light_energy = 1.5
			"hangar":
				main_room_light.light_color = Color.WHITE
				main_room_light.light_energy = 1.8
			_:
				main_room_light.light_color = Color(1.0, 1.0, 1.0)
				main_room_light.light_energy = 1.4
				
	# 6. Configure Progressive Ceiling Vents (Pipes Unlocked: 1 to 9)
	update_ceiling_vents()
		
	if gravity_terminal:
		gravity_terminal.position = Vector3(W * 0.5 - 0.65, 0.0, -2.4)
	update_gravity_terminal_display()
	
	# Clean up any balloons trapped outside new room bounds or under floor
	if balloon_container:
		for b in balloon_container.get_children():
			if b is RigidBody3D and is_instance_valid(b) and not b.is_queued_for_deletion():
				if abs(b.global_position.x) > (half_w + 1.0) or abs(b.global_position.z) > (half_l + 1.0) or b.global_position.y < -0.4:
					b.pop("room_resize")

	room_layout_applied.emit(room_id)

func open_exit_door() -> void:
	if _main and _main.sound_manager and _main.sound_manager.has_method("play_door_slide"):
		_main.sound_manager.play_door_slide()
	if exit_door and is_instance_valid(exit_door) and exit_door.has_method("open_door"):
		exit_door.open_door()

func close_exit_door() -> void:
	if _main and _main.sound_manager and _main.sound_manager.has_method("play_door_slide"):
		_main.sound_manager.play_door_slide()
	if exit_door and is_instance_valid(exit_door) and exit_door.has_method("close_door"):
		exit_door.close_door()

func toggle_exit_door() -> void:
	if _main and _main.sound_manager:
		if _main.sound_manager.has_method("play_button_click"):
			_main.sound_manager.play_button_click()
		if _main.sound_manager.has_method("play_door_slide"):
			_main.sound_manager.play_door_slide()
	if exit_door and is_instance_valid(exit_door) and exit_door.has_method("toggle_door"):
		exit_door.toggle_door()

func lock_exit_door() -> void:
	if exit_door and is_instance_valid(exit_door) and exit_door.has_method("lock_door"):
		exit_door.lock_door()

func update_ceiling_vents() -> void:
	active_vent_positions.clear()
	active_vent_nodes.clear()
	if not shop_manager: return
	
	var r_data = shop_manager.get_current_room_data()
	var W: float = r_data["floor_size"].x
	var L: float = r_data["floor_size"].y
	var H: float = r_data["ceiling_height"]
	var vent_y = H - 0.85
	
	var xs = [-W * 0.28, 0.0, W * 0.28]
	var zs = [-L * 0.28, 0.0, L * 0.28]
	
	# All 9 theoretical grid positions
	var all_positions: Array[Vector3] = []
	for z_pos in zs:
		for x_pos in xs:
			all_positions.append(Vector3(x_pos, vent_y, z_pos))
			
	# Update physical node positions in 3D scene & configure wall-facing chutes
	# Grid indices:
	# 0: NW corner (x < 0, z < 0) -> Wall is West (-X) and South (-Z) -> Allowed: North (+Z), East (+X) [0, 1]
	# 1: N center (x = 0, z < 0)  -> Wall is South (-Z)               -> Allowed: North (+Z), East (+X), West (-X) [0, 1, 3]
	# 2: NE corner (x > 0, z < 0) -> Wall is East (+X) and South (-Z) -> Allowed: North (+Z), West (-X) [0, 3]
	# 3: W center (x < 0, z = 0)  -> Wall is West (-X)                -> Allowed: North (+Z), East (+X), South (-Z) [0, 1, 2]
	# 4: Center   (x = 0, z = 0)  -> Open inside                      -> Allowed: All [0, 1, 2, 3]
	# 5: E center (x > 0, z = 0)  -> Wall is East (+X)                -> Allowed: North (+Z), South (-Z), West (-X) [0, 2, 3]
	# 6: SW corner (x < 0, z > 0) -> Wall is West (-X) and North (+Z) -> Allowed: East (+X), South (-Z) [1, 2]
	# 7: S center (x = 0, z > 0)  -> Wall is North (+Z)               -> Allowed: East (+X), South (-Z), West (-X) [1, 2, 3]
	# 8: SE corner (x > 0, z > 0) -> Wall is East (+X) and North (+Z) -> Allowed: South (-Z), West (-X) [2, 3]
	var grid_allowed_chutes: Dictionary = {
		0: [0, 1],
		1: [0, 1, 3],
		2: [0, 3],
		3: [0, 1, 2],
		4: [0, 1, 2, 3],
		5: [0, 2, 3],
		6: [1, 2],
		7: [1, 2, 3],
		8: [2, 3]
	}

	if ceiling_vents_container:
		for i in range(min(all_positions.size(), ceiling_vents_container.get_child_count())):
			var vent_node = ceiling_vents_container.get_child(i)
			if vent_node:
				var v_pos = Vector3(all_positions[i].x, H - 0.35, all_positions[i].z)
				vent_node.position = v_pos
				vent_node.rotation = Vector3.ZERO
				if vent_node.has_method("configure_allowed_chutes"):
					var allowed: Array[int] = []
					allowed.assign(grid_allowed_chutes.get(i, [0, 1, 2, 3]))
					vent_node.configure_allowed_chutes(allowed)
				
	# Calculate which pipes are actively unlocked (Level 0: 1 pipe -> Level 8: 9 pipes)
	var pipe_lvl = 0
	if shop_manager.upgrades.has("pipe_count"):
		pipe_lvl = shop_manager.get_active_pipe_count() - 1
		
	var pipe_patterns = [
		[4],                         # 1 Pipe: Center
		[1, 7],                      # 2 Pipes: North + South
		[4, 1, 7],                   # 3 Pipes: Center + North + South
		[0, 2, 6, 8],                # 4 Pipes: 4 Corners
		[4, 0, 2, 6, 8],             # 5 Pipes: Center + 4 Corners (Plus)
		[0, 1, 2, 6, 7, 8],          # 6 Pipes: North 3 + South 3
		[4, 0, 1, 2, 6, 7, 8],       # 7 Pipes: North 3 + South 3 + Center
		[0, 1, 2, 3, 5, 6, 7, 8],    # 8 Pipes: Outer Ring of 8
		[0, 1, 2, 3, 4, 5, 6, 7, 8]  # 9 Pipes: Complete 3x3 Matrix
	]
	
	var active_indices = pipe_patterns[pipe_lvl]
	
	# Apply visibility to 3D meshes in ceiling
	if ceiling_vents_container:
		for i in range(ceiling_vents_container.get_child_count()):
			var vent_node = ceiling_vents_container.get_child(i)
			if vent_node:
				var is_active = (i in active_indices)
				vent_node.visible = is_active
				
	# Populate active drop points for balloon spawning
	for idx in active_indices:
		if idx < all_positions.size():
			active_vent_positions.append(all_positions[idx])
			if ceiling_vents_container and idx < ceiling_vents_container.get_child_count():
				active_vent_nodes.append(ceiling_vents_container.get_child(idx))

func get_vent_ejection(offset_idx: int = 0) -> Dictionary:
	if active_vent_nodes.is_empty():
		update_ceiling_vents()
	if not active_vent_nodes.is_empty():
		var node_idx = (vent_cycle_idx + offset_idx) % active_vent_nodes.size()
		var v_node = active_vent_nodes[node_idx]
		if v_node and v_node.has_method("get_next_chute_ejection"):
			return v_node.get_next_chute_ejection()
			
	var default_pos = get_next_vent_spawn_position(offset_idx)
	return {
		"position": default_pos,
		"direction": Vector3(0, 0, 1),
		"chute_index": 0
	}

func trigger_vent_recoil(vent_idx: int, chute_idx: int) -> void:
	if not active_vent_nodes.is_empty():
		var node_idx = (vent_cycle_idx + vent_idx) % active_vent_nodes.size()
		var v_node = active_vent_nodes[node_idx]
		if v_node and v_node.has_method("trigger_chute_recoil"):
			v_node.trigger_chute_recoil(chute_idx)

func get_current_gravity_scale() -> float:
	var idx = clamp(current_gravity_idx, 0, balloon_gravity_scales.size() - 1)
	return balloon_gravity_scales[idx]

func get_current_linear_damp() -> float:
	var idx = clamp(current_gravity_idx, 0, balloon_linear_damps.size() - 1)
	return balloon_linear_damps[idx]

func get_current_gravity_name() -> String:
	var idx = clamp(current_gravity_idx, 0, gravity_mode_names.size() - 1)
	return gravity_mode_names[idx]

func get_next_vent_spawn_position(offset_idx: int = 0) -> Vector3:
	if active_vent_positions.is_empty():
		update_ceiling_vents()
	if active_vent_positions.is_empty():
		var default_y = 4.0
		if shop_manager and shop_manager.has_method("get_current_room_data"):
			default_y = shop_manager.get_current_room_data().get("ceiling_height", 4.8) - 0.85
		return Vector3(0, default_y, 0)
	var v_idx = (vent_cycle_idx + offset_idx) % active_vent_positions.size()
	return active_vent_positions[v_idx]

func advance_vent_cycle(count: int) -> void:
	if not active_vent_positions.is_empty():
		vent_cycle_idx = (vent_cycle_idx + count) % active_vent_positions.size()

func apply_gravity_to_active_balloons() -> void:
	if not balloon_container: return
	var grav = get_current_gravity_scale()
	var damp = get_current_linear_damp()
	for child in balloon_container.get_children():
		if is_instance_valid(child) and child is RigidBody3D and not child.is_queued_for_deletion():
			if child.has_method("apply_room_physics"):
				child.apply_room_physics(grav, damp)
			else:
				child.gravity_scale = grav
				child.linear_damp = damp
	update_gravity_terminal_display()

func update_gravity_terminal_display() -> void:
	if gravity_display_label:
		var g_val = get_current_gravity_scale()
		var g_name = get_current_gravity_name()
		gravity_display_label.text = "YERÇEKİMİ KONTROLÜ\n[ " + str(g_val) + " G ]\n" + g_name.to_upper()

func cycle_gravity_mode() -> void:
	max_unlocked_gravity_idx = balloon_gravity_scales.size() - 1
	current_gravity_idx = (current_gravity_idx + 1) % balloon_gravity_scales.size()
	apply_gravity_to_active_balloons()
	if gravity_btn_mesh:
		preload("res://src/environment/interaction_feedback.gd").press(gravity_btn_mesh, Vector3(0.05, 0, 0))
		preload("res://src/environment/interaction_feedback.gd").sound(gravity_btn_mesh, "confirm")
	var g_name = get_current_gravity_name()
	prompt_requested.emit("Yerçekimi: [" + g_name + "]")
	gravity_mode_changed.emit(current_gravity_idx, g_name, get_current_gravity_scale())
	save_requested.emit()

func upgrade_gravity_terminal() -> void:
	prompt_requested.emit("Yerçekimi modları Tesis tabletinden ücretsiz seçilir.")
