class_name InteractionController
extends Node

const DEVICE_INTERACTION_REACH := 3.0
const DEVICE_AIM_DOT := 0.975

var _main: Node3D = null

var raycast_target_type: String = "" # "gravity_terminal", "device", "exit_door", "breaker_panel", ""
var raycast_target_device: Node3D = null
var raycast_target_name: String = ""
var nearby_device: Node3D = null

var highlighted_balloon: Node = null
var highlighted_device: Node3D = null
var highlighted_device_meshes: Array[MeshInstance3D] = []
var highlighted_device_original_overlays: Array[Material] = []
var highlighted_device_pulse_materials: Array[StandardMaterial3D] = []
var device_pulse_time := 0.0

var _crosshair_ray_query: PhysicsRayQueryParameters3D = null
var _crosshair_shape_query: PhysicsShapeQueryParameters3D = null
var _crosshair_sphere: SphereShape3D = null

signal prompt_text_updated(text: String, is_visible: bool)
signal start_carry_device_requested(device: Node3D)
signal upgrade_device_requested(device: Node3D)
signal restore_power_requested()

func setup(main_node: Node3D) -> void:
	_main = main_node

func _ensure_crosshair_queries() -> void:
	if _crosshair_ray_query == null:
		_crosshair_ray_query = PhysicsRayQueryParameters3D.new()
		_crosshair_ray_query.collide_with_areas = true
		_crosshair_ray_query.collide_with_bodies = true
	if _crosshair_sphere == null:
		_crosshair_sphere = SphereShape3D.new()
		_crosshair_sphere.radius = 0.45
	if _crosshair_shape_query == null:
		_crosshair_shape_query = PhysicsShapeQueryParameters3D.new()
		_crosshair_shape_query.shape = _crosshair_sphere
		_crosshair_shape_query.collision_mask = 2 # Balloons layer
		_crosshair_shape_query.collide_with_bodies = true
		_crosshair_shape_query.collide_with_areas = false

func clear_targets() -> void:
	if _main and _main.room_controller and is_instance_valid(_main.room_controller.broken_pipe):
		_main.room_controller.broken_pipe.advance_repair(0.0, false)
	raycast_target_type = ""
	raycast_target_device = null
	raycast_target_name = ""
	nearby_device = null
	_set_device_target_highlight(null)

func update_interaction() -> void:
	raycast_target_type = ""
	raycast_target_device = null
	raycast_target_name = ""
	nearby_device = null
	
	if not _main or not _main.player or not is_instance_valid(_main.player):
		_clear_balloon_highlight()
		_set_device_target_highlight(null)
		_reset_crosshair_style()
		prompt_text_updated.emit("", false)
		return
		
	var cam: Camera3D = _main.player.get_node_or_null("Head/Camera3D")
	if not cam:
		_clear_balloon_highlight()
		_set_device_target_highlight(null)
		_reset_crosshair_style()
		prompt_text_updated.emit("", false)
		return
		
	var cam_pos = cam.global_position
	var look_dir = -cam.global_transform.basis.z.normalized()
	
	# 1. Device & Interactable Scan
	var best_target_type = ""
	var best_target_dev: Node3D = null
	var best_target_name = ""
	var best_dot = 0.88
	
	# Gravity Terminal
	if _main.gravity_terminal and is_instance_valid(_main.gravity_terminal):
		var to_gt = (_main.gravity_terminal.global_position + Vector3(0, 1.2, 0)) - cam_pos
		var g_dist = to_gt.length()
		if g_dist <= 3.5 and g_dist > 0.2:
			var dot = look_dir.dot(to_gt / g_dist)
			if dot > 0.70 and dot > best_dot:
				best_target_type = "gravity_terminal"
				best_target_name = "Yerçekimi Terminali"
				best_dot = dot
				
	# Aim at the visible device body, including the edges of wide machines.
	var nearest_device_distance := DEVICE_INTERACTION_REACH + 1.0
	for d_node in _main.active_placed_devices:
		if not is_instance_valid(d_node) or not d_node.visible or d_node == _main.carried_device: continue
		var hit_point: Variant = _device_aim_hit(d_node, cam_pos, look_dir)
		if hit_point == null: continue
		var distance: float = cam_pos.distance_to(hit_point)
		if distance < nearest_device_distance and _has_clear_device_sight(cam_pos, hit_point):
			nearest_device_distance = distance
			best_target_type = "device"
			best_target_dev = d_node
			best_target_name = _get_device_display_name(str(d_node.get_meta("device_type", "")))
			best_dot = 1.0

	# Exit Door
	var door_node = _main.room_controller.exit_door if (_main.room_controller and "exit_door" in _main.room_controller) else null
	if door_node and is_instance_valid(door_node):
		var to_door = (door_node.global_position + Vector3(0, 1.4, 0)) - cam_pos
		var door_dist = to_door.length()
		if door_dist <= 5.0 and door_dist > 0.2:
			var dot = look_dir.dot(to_door / door_dist)
			if dot > 0.75 and dot > best_dot:
				best_target_type = "exit_door"
				best_target_dev = door_node
				best_target_name = "Jeneratör Odası Kapısı"
				best_dot = dot

	# Breaker Panel
	var pr_node = _main.room_controller.power_room if (_main.room_controller and "power_room" in _main.room_controller) else null
	if pr_node and is_instance_valid(pr_node):
		var breaker_body = pr_node.get_node_or_null("BreakerPanelBody")
		if breaker_body and is_instance_valid(breaker_body):
			var to_bp = breaker_body.global_position - cam_pos
			var bp_dist = to_bp.length()
			if bp_dist <= 5.0 and bp_dist > 0.2:
				var dot = look_dir.dot(to_bp / bp_dist)
				if dot > 0.75 and dot > best_dot:
					best_target_type = "breaker_panel"
					best_target_dev = pr_node
					best_target_name = "Elektrik Panosu"
					best_dot = dot

	# Broken Pipe Hazard
	var pipe_hazard = _main.room_controller.broken_pipe if (_main.room_controller and "broken_pipe" in _main.room_controller) else null
	if pipe_hazard and is_instance_valid(pipe_hazard) and ("is_ruptured" in pipe_hazard) and pipe_hazard.is_ruptured:
		var to_pipe = pipe_hazard.global_position - cam_pos
		var p_dist = to_pipe.length()
		if p_dist <= 3.0 and p_dist > 0.2:
			var dot = look_dir.dot(to_pipe / p_dist)
			if dot > 0.70 and dot > best_dot:
				best_target_type = "broken_pipe"
				best_target_dev = pipe_hazard
				best_target_name = "Patlak Basınç Borusu"
				best_dot = dot

	if best_target_type != "":
		raycast_target_type = best_target_type
		raycast_target_device = best_target_dev
		raycast_target_name = best_target_name
		nearby_device = best_target_dev
		_set_device_target_highlight(best_target_dev if raycast_target_type == "device" else null)
		
		var prompt_text = ""
		if raycast_target_type == "gravity_terminal":
			var g_mode = _main.gravity_mode_names[clamp(_main.current_gravity_idx, 0, _main.gravity_mode_names.size() - 1)]
			prompt_text = "[E] Yerçekimi modunu değiştir • Şu an: %s" % g_mode
		elif raycast_target_type == "device" and best_target_dev:
			prompt_text = _get_device_interaction_prompt(best_target_dev, best_target_name)
		elif raycast_target_type == "exit_door":
			if best_target_dev and "is_open" in best_target_dev and best_target_dev.is_open:
				prompt_text = "[E] Jeneratör Odası Kapısını Kapat"
			else:
				prompt_text = "[E] Jeneratör Odası Kapısını Aç"
		elif raycast_target_type == "breaker_panel":
			if _main.is_blackout:
				var pipe = _main.room_controller.broken_pipe if (_main.room_controller and "broken_pipe" in _main.room_controller) else null
				if pipe and ("is_ruptured" in pipe) and pipe.is_ruptured:
					prompt_text = "[!] Önce Patlak Boruyu Onar [Vana Açık!]"
				else:
					prompt_text = "[E] Şalteri Kaldır & Şebekeyi Başlat (+500 Coin)"
			else:
				prompt_text = "Elektrik Panosu [Şebeke Normal]"
		elif raycast_target_type == "broken_pipe":
			prompt_text = "[E BASILI TUT] Vanayı kapat • %d%% (+250 Coin)" % int(pipe_hazard.repair_progress * 100.0)
		prompt_text_updated.emit(prompt_text, true)
	else:
		_set_device_target_highlight(null)
		prompt_text_updated.emit("", false)
	_update_device_pulse(get_process_delta_time())

	if pipe_hazard and is_instance_valid(pipe_hazard) and pipe_hazard.is_ruptured:
		var holding: bool = raycast_target_type == "broken_pipe" and Input.is_physical_key_pressed(KEY_E) and not _main.player.is_ui_open and _main.carried_device == null
		if pipe_hazard.advance_repair(get_process_delta_time(), holding):
			_main.environment_controller.repair_pipe()

	# 2. Balloon Target Check
	var world = _main.get_world_3d()
	if not world: return
	var space_state = world.direct_space_state
	if not space_state: return
	
	var from = cam.global_position
	var needle_reach: float = _main.game_manager.get_needle_reach() if _main.game_manager and _main.game_manager.has_method("get_needle_reach") else 5.2
	var to = from + (look_dir * needle_reach)
	var exclude_rids = [_main.player.get_rid()]
	var nudge_cone = _main.player.get_node_or_null("Head/Camera3D/WindCone")
	if nudge_cone:
		exclude_rids.append(nudge_cone.get_rid())
		
	_ensure_crosshair_queries()
	_crosshair_ray_query.from = from
	_crosshair_ray_query.to = to
	_crosshair_ray_query.exclude = exclude_rids
	
	var result = space_state.intersect_ray(_crosshair_ray_query)
	var col = result.collider if result else null
	var hit_balloon = null
	
	if col and is_instance_valid(col) and col.is_in_group("balloons"):
		hit_balloon = col
	else:
		_crosshair_shape_query.transform = Transform3D(Basis(), from + (look_dir * 2.6))
		_crosshair_shape_query.exclude = exclude_rids
		var hits = space_state.intersect_shape(_crosshair_shape_query, 1)
		if not hits.is_empty():
			var h_col = hits[0].collider
			if h_col is RigidBody3D and is_instance_valid(h_col) and not h_col.get("is_popped"):
				hit_balloon = h_col
						
	if hit_balloon and is_instance_valid(hit_balloon):
		if highlighted_balloon != hit_balloon:
			_clear_balloon_highlight()
			highlighted_balloon = hit_balloon
			if highlighted_balloon.has_method("set_highlight"):
				highlighted_balloon.set_highlight(true)
		if _main.hud_controller: _main.hud_controller.set_reticle_highlight(true, false)
	else:
		_clear_balloon_highlight()
		if raycast_target_type != "":
			if _main.hud_controller: _main.hud_controller.set_reticle_highlight(false, true)
		else:
			_reset_crosshair_style()

func handle_key_action(action: String) -> bool:
	update_interaction() # Validate aim and distance again on the input frame.
	if action == "interact": # Key E
		if raycast_target_type == "broken_pipe" and raycast_target_device != null and is_instance_valid(raycast_target_device):
			# Completion is driven by holding E while aiming at the valve.
			pass
			return true
		elif raycast_target_type == "device" and raycast_target_device != null and is_instance_valid(raycast_target_device):
			_set_device_target_highlight(null)
			start_carry_device_requested.emit(raycast_target_device)
			return true
		elif raycast_target_type == "exit_door" and raycast_target_device != null and is_instance_valid(raycast_target_device):
			if raycast_target_device.has_method("toggle_door"):
				raycast_target_device.toggle_door()
			return true
		elif raycast_target_type == "breaker_panel" and raycast_target_device != null and is_instance_valid(raycast_target_device):
			if _main.is_blackout:
				var pipe = _main.room_controller.broken_pipe if (_main.room_controller and "broken_pipe" in _main.room_controller) else null
				if pipe and ("is_ruptured" in pipe) and pipe.is_ruptured:
					if _main.sound_manager: _main.sound_manager.play_interaction("denied", raycast_target_device.global_position)
					if _main.hud_controller:
						_main.hud_controller.show_prompt("Şebeke Kilitli! Önce Duvardaki Patlak Boruyu Onar!", 3.0)
					return true
				restore_power_requested.emit()
			return true
		elif _main.room_controller and _main.room_controller.exit_door and "player_near_door" in _main.room_controller.exit_door and _main.room_controller.exit_door.player_near_door:
			_main.room_controller.exit_door.toggle_door()
			return true
		elif _main.room_controller and _main.room_controller.power_room and "player_near_panel" in _main.room_controller.power_room and _main.room_controller.power_room.player_near_panel:
			if _main.is_blackout:
				restore_power_requested.emit()
			return true
		elif nearby_device != null and is_instance_valid(nearby_device):
			start_carry_device_requested.emit(nearby_device)
			return true
	elif action == "upgrade": # Key F
		if raycast_target_type == "device" and raycast_target_device != null and is_instance_valid(raycast_target_device):
			upgrade_device_requested.emit(raycast_target_device)
			return true
		elif nearby_device != null and is_instance_valid(nearby_device):
			upgrade_device_requested.emit(nearby_device)
			return true
	return false

func _get_device_interaction_prompt(d_node: Node3D, d_name: String) -> String:
	if not d_node or not is_instance_valid(d_node): return ""
	var d_type = d_node.get_meta("device_type") if d_node.has_meta("device_type") else ""
	var cur_lvl = d_node.get("level") if ("level" in d_node) else 1
	if cur_lvl <= 0: cur_lvl = 1
	var max_lvl = 6
	if _main.shop_manager and _main.shop_manager.devices.has(d_type):
		max_lvl = mini(int(_main.shop_manager.devices[d_type].get("max_level", 6)), _main.shop_manager.device_level_limit())
		
	var prompt = "[E] " + d_name + " Taşı (Sv. " + str(cur_lvl) + ")"
	var active_status := "Çalışıyor" if ("is_active" in d_node and bool(d_node.get("is_active"))) else "Beklemede"
	if _main.is_blackout: active_status = "Elektrik yok"
	prompt += "  •  " + active_status
	if cur_lvl >= max_lvl:
		prompt += "  |  [MAX SEVİYE " + str(max_lvl) + "]"
	else:
		var cost: int = _main.shop_manager.get_device_tech_cost(d_type, cur_lvl) if _main.shop_manager and _main.shop_manager.has_method("get_device_tech_cost") else 500
		var needed_pops = _main.shop_manager.get_device_tech_req_pops(d_type, cur_lvl) if _main.shop_manager else 0
		var total_pops = _main.game_manager.total_pops if _main.game_manager else 0
		if total_pops < needed_pops:
			prompt += "  |  [Kilitli: Sv.%d için %s pop gerekli]" % [cur_lvl + 1, _format_number(needed_pops)]
		elif _main.shop_manager and not _main.shop_manager.can_afford(cost):
			prompt += "  |  [Sv.%d: %s Coin gerekli; kasada %s]" % [cur_lvl + 1, _format_number(cost), _format_number(_main.shop_manager.get_spendable_coin_balance())]
		else:
			prompt += "  |  [F] Yükselt Sv.%d → %d • %s Coin" % [cur_lvl, cur_lvl + 1, _format_number(cost)]
	if _main.device_placement:
		prompt += "\n" + _main.device_placement.device_stats(d_node, cur_lvl)
		if cur_lvl < max_lvl: prompt += " → " + _main.device_placement.device_stats(d_node, cur_lvl + 1)
	return prompt

func _has_clear_device_sight(origin: Vector3, target: Vector3) -> bool:
	if not _main or not _main.get_world_3d(): return false
	var exclusions: Array[RID] = []
	if _main.player and is_instance_valid(_main.player): exclusions.append(_main.player.get_rid())
	var query := PhysicsRayQueryParameters3D.create(origin, target, 1, exclusions)
	query.collide_with_areas = false
	return _main.get_world_3d().direct_space_state.intersect_ray(query).is_empty()

func _set_device_target_highlight(target: Node3D) -> void:
	if target == highlighted_device and not highlighted_device_meshes.is_empty(): return
	_clear_device_target_highlight()
	if target == null or not is_instance_valid(target):
		return
	highlighted_device = target
	if "feedback" in target and is_instance_valid(target.feedback): target.feedback.focused = true
	var meshes: Array[MeshInstance3D] = []
	_collect_device_meshes(highlighted_device, meshes)
	for mesh_instance in meshes:
		var pulse_material := StandardMaterial3D.new()
		pulse_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		pulse_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		pulse_material.albedo_color = Color(0.12, 0.82, 1.0, 0.0)
		pulse_material.emission_enabled = true
		pulse_material.emission = Color(0.08, 0.72, 1.0)
		pulse_material.emission_energy_multiplier = 0.5
		highlighted_device_meshes.append(mesh_instance)
		highlighted_device_original_overlays.append(mesh_instance.material_overlay)
		highlighted_device_pulse_materials.append(pulse_material)
		mesh_instance.material_overlay = pulse_material
	device_pulse_time = 0.0
	_update_device_pulse(0.0)

func _collect_device_meshes(node: Node, result: Array[MeshInstance3D]) -> void:
	if node.get_script() == preload("res://src/devices/device_feedback.gd"): return
	if node is MeshInstance3D:
		result.append(node)
	for child in node.get_children():
		_collect_device_meshes(child, result)

func _update_device_pulse(delta: float) -> void:
	if not is_instance_valid(highlighted_device): return
	device_pulse_time += delta
	var pulse := 0.5 + 0.5 * sin(device_pulse_time * TAU * 1.25)
	for material in highlighted_device_pulse_materials:
		if not is_instance_valid(material): continue
		material.albedo_color.a = lerpf(0.05, 0.28, pulse)
		material.emission_energy_multiplier = lerpf(0.5, 1.35, pulse)

func _clear_device_target_highlight() -> void:
	if is_instance_valid(highlighted_device) and "feedback" in highlighted_device and is_instance_valid(highlighted_device.feedback):
		highlighted_device.feedback.focused = false
	for i in range(highlighted_device_meshes.size()):
		var mesh_instance := highlighted_device_meshes[i]
		if is_instance_valid(mesh_instance):
			mesh_instance.material_overlay = highlighted_device_original_overlays[i]
	highlighted_device_meshes.clear()
	highlighted_device_original_overlays.clear()
	highlighted_device_pulse_materials.clear()
	highlighted_device = null
	device_pulse_time = 0.0

func _format_number(value: int) -> String:
	return _main.format_number(value) if _main and _main.has_method("format_number") else str(value)

func _clear_balloon_highlight() -> void:
	if highlighted_balloon and is_instance_valid(highlighted_balloon):
		if highlighted_balloon.has_method("set_highlight"):
			highlighted_balloon.set_highlight(false)
	highlighted_balloon = null

func _reset_crosshair_style() -> void:
	if _main and _main.hud_controller:
		_main.hud_controller.set_reticle_highlight(false, false)

func _get_device_display_name(d_type: String) -> String:
	match d_type:
		"spike_wall": return "Dikenli Zemin"
		"electric_wall": return "Elektrikli Zemin Izgarası"
		"magnet_pylon": return "Manyetik Çekim Kulesi"
		"conveyor_crusher": return "Makaralı Balon Öğütücü"
		"sentry_drone": return "Otomatik Lazer Dronu"
		"fan": return "Köşe Fanı"
		_: return "Cihaz"

func _device_aim_hit(device: Node3D, origin: Vector3, direction: Vector3) -> Variant:
	var level: int = int(device.get("level"))
	if int(device.get_meta("aim_bounds_level", -1)) != level:
		var meshes: Array[MeshInstance3D] = []
		_collect_device_meshes(device, meshes)
		var bounds := AABB()
		var found := false
		for mesh in meshes:
			if not mesh.mesh or not mesh.visible: continue
			var local_bounds: AABB = (device.global_transform.affine_inverse() * mesh.global_transform) * mesh.get_aabb()
			bounds = bounds.merge(local_bounds) if found else local_bounds
			found = true
		device.set_meta("aim_bounds", bounds.grow(0.06))
		device.set_meta("aim_bounds_level", level)
	var bounds: AABB = device.get_meta("aim_bounds", AABB())
	var local_hit: Variant = bounds.intersects_segment(device.to_local(origin), device.to_local(origin + direction * DEVICE_INTERACTION_REACH))
	return device.to_global(local_hit) if local_hit != null else null
