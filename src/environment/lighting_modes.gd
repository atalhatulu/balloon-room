extends Node3D

const WHITE_MODE := {"name": "Beyaz", "ambient": 0.16, "energy": 2.1, "a": Color("ffffff"), "b": Color("ffffff")}
var main: Node
var event_phase := 0.0
var event_elapsed := 0.0
var lights: Array[Light3D] = []
var fixtures: Node3D
var label: Label
var last_blackout := false

func setup(owner_node: Node) -> void:
	main = owner_node
	process_mode = Node.PROCESS_MODE_PAUSABLE
	# Legacy light references remain valid for machine scripts but cannot illuminate.
	for node in main.find_children("*", "Light3D", true, false):
		_suppress_legacy(node)
	get_tree().node_added.connect(_on_node_added)
	main.room_controller.room_layout_applied.connect(func(_id: String): rebuild.call_deferred())
	label = Label.new()
	main.get_node("UI").add_child(label)
	label.set_anchors_and_offsets_preset(Control.PRESET_CENTER_BOTTOM)
	label.offset_left = -380
	label.offset_right = 380
	label.offset_top = -65
	label.offset_bottom = -35
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.add_theme_font_size_override("font_size", 18)
	label.add_theme_color_override("font_color", Color("ffe1a5"))
	label.add_theme_color_override("font_outline_color", Color("09131e"))
	label.add_theme_constant_override("outline_size", 6)
	rebuild()

func _on_node_added(node: Node) -> void:
	if node is Light3D: _suppress_legacy.call_deferred(node)

func _suppress_legacy(node: Node) -> void:
	if not is_instance_valid(node) or not node is Light3D: return
	if node == main.player.flashlight or is_ancestor_of(node): return
	node.hide()
	node.shadow_enabled = false

func rebuild() -> void:
	if not main or not main.shop_manager: return
	if is_instance_valid(fixtures):
		remove_child(fixtures)
		fixtures.queue_free()
	lights.clear()
	event_phase = 0.0
	event_elapsed = 0.0
	fixtures = Node3D.new()
	add_child(fixtures)
	var mode: Dictionary = WHITE_MODE
	var room: Dictionary = main.shop_manager.get_current_room_data()
	var size: Vector2 = room.floor_size
	if mode.get("sun", false):
		var light := DirectionalLight3D.new()
		fixtures.add_child(light)
		light.rotation_degrees = Vector3(-65, -25, 0)
		light.light_color = mode.a
		light.light_energy = mode.energy
		light.shadow_enabled = false
		lights.append(light)
	else:
		for x in [-1.0, 1.0]:
			for z in [-1.0, 1.0]:
				var light := OmniLight3D.new()
				fixtures.add_child(light)
				light.position = Vector3(x * size.x * 0.25, minf(4.0, float(room.ceiling_height) - 1.0), z * size.y * 0.25)
				light.omni_range = maxf(8.0, maxf(size.x, size.y) * 0.43)
				light.omni_attenuation = 0.65
				light.light_color = mode.a if x < 0 else mode.b
				light.light_energy = mode.energy
				light.shadow_enabled = false
				lights.append(light)
	apply_state()

func apply_state() -> void:
	if not main: return
	last_blackout = main.is_blackout
	var mode: Dictionary = WHITE_MODE
	var world = main.get_node_or_null("WorldEnvironment")
	if world and world.environment:
		var env: Environment = world.environment
		env.volumetric_fog_enabled = false
		env.fog_enabled = false
		env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
		env.ambient_light_color = Color("e8edf3")
		env.ambient_light_energy = 0.012 if last_blackout else float(mode.ambient)
		env.background_energy_multiplier = 0.01 if last_blackout else 0.12
	for light in lights: light.visible = not last_blackout
	label.text = "AYDINLATMA · BEYAZ"
	_update_event_lighting()
	if last_blackout: label.text += " · ELEKTRİK KESİK"

func _process(delta: float) -> void:
	if not main: return
	if main.is_blackout != last_blackout: apply_state()
	if not last_blackout and not main.player.is_ui_open:
		event_elapsed += delta
		if event_elapsed >= 0.15:
			event_phase += event_elapsed
			event_elapsed = 0.0
			_update_event_lighting()
	if label:
		label.visible = not main.player.is_ui_open and not main.startup_modal.visible

func _active_event() -> String:
	var room = main.room_controller
	var pipe = room.broken_pipe if room else null
	if is_instance_valid(pipe) and pipe.is_ruptured: return "alarm"
	var bonuses = main.bonus_controller
	if bonuses and (bonuses.coin_seconds > 0.0 or bonuses.magnet_seconds > 0.0 or bonuses.minigun_seconds > 0.0): return "bonus"
	if main.shop_manager.pending_room != "":
		return "complete" if main.game_manager.active_balloons <= 0 else "transfer"
	if main.game_manager.total_pops >= 1000000: return "complete"
	var count: float = main.game_manager.get_pressure_ratio()
	if count >= 0.85: return "transfer"
	return ""

func _update_event_lighting() -> void:
	var event := _active_event()
	var event_names := {"alarm": "KIRMIZI ALARM", "bonus": "SARI BONUS", "complete": "YEŞİL TAMAMLANDI", "transfer": "TURUNCU GEÇİŞ"}
	label.text = "AYDINLATMA · BEYAZ   |   %s" % event_names.get(event, "NORMAL")
	var mode: Dictionary = WHITE_MODE
	if event == "":
		for i in range(lights.size()):
			lights[i].light_color = mode.a if i < 2 else mode.b
			lights[i].light_energy = mode.energy
		return
	var phase := 0.5 + 0.5 * sin(event_phase * TAU * (1.2 if event == "alarm" else 0.72))
	var tint: Color
	var pulse_weight := 0.7
	var energy := float(mode.energy)
	match event:
		"alarm":
			tint = Color("ff291d")
			pulse_weight = 0.68 + phase * 0.32
			energy = 0.6 + phase * 1.9
		"bonus":
			tint = Color("ffdc45")
			pulse_weight = 0.35 + phase * 0.55
			energy = 1.6 + phase * 0.8
		"complete":
			tint = Color("4ce5a2")
			pulse_weight = 0.72 + phase * 0.18
			energy = 1.7 + phase * 0.45
		"transfer":
			tint = Color("ff9639")
			pulse_weight = 0.52 + phase * 0.32
			energy = 1.55 + phase * 0.65
	for i in range(lights.size()):
		var base: Color = mode.a if i < 2 else mode.b
		var local_weight := pulse_weight
		if event == "alarm": local_weight = clampf(pulse_weight - float(i % 2) * 0.22, 0.3, 1.0)
		lights[i].light_color = base.lerp(tint, local_weight)
		lights[i].light_energy = energy
