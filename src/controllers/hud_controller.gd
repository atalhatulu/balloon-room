class_name HUDController
extends Node

var _main: Node3D = null

# Minimal HUD Elements
var pop_count_label: Label = null
var pressure_bar: ProgressBar = null
var pressure_label: Label = null
var grand_goal_bar: ProgressBar = null
var grand_goal_label: Label = null
var playtime_label: Label = null
var desk_prompt: Label = null
var auto_fire_badge: Label = null
var fps_label: Label = null
var maintenance_panel: PanelContainer = null
var maintenance_label: Label = null
var maintenance_hint: Label = null

# Crosshair UI & Context Reticle
var crosshair_stamina_bar: ProgressBar = null
var crosshair_container: Control = null
var crosshair_dot: ColorRect = null
var reticle_ring: Panel = null

var current_pressure_ratio: float = 0.0
var was_overpressure_critical: bool = false

var room_identity: Label
var arrival: Label
var _arrival_tween: Tween
var _reticle_tween: Tween
var _stamina_tween: Tween
var _room_refresh := 0.0

signal overpressure_relieved()

func setup(main_node: Node3D) -> void:
	_main = main_node
	pop_count_label = main_node.get_node_or_null("UI/HUD/TopLeft/Margin/VBox/PopCountLabel")
	pressure_bar = main_node.get_node_or_null("UI/HUD/TopLeft/Margin/VBox/PressureBar")
	pressure_label = main_node.get_node_or_null("UI/HUD/TopLeft/Margin/VBox/PressureLabel")
	grand_goal_bar = main_node.get_node_or_null("UI/HUD/TopLeft/Margin/VBox/GrandGoalBar")
	grand_goal_label = main_node.get_node_or_null("UI/HUD/TopLeft/Margin/VBox/GrandGoalLabel")
	playtime_label = main_node.get_node_or_null("UI/HUD/TopLeft/Margin/VBox/PlaytimeLabel")
	desk_prompt = main_node.get_node_or_null("UI/HUD/DeskPrompt")
	auto_fire_badge = main_node.get_node_or_null("UI/HUD/AutoFireBadge")
	fps_label = main_node.get_node_or_null("UI/HUD/FPSPanel/Margin/FPSLabel")
	
	crosshair_stamina_bar = main_node.get_node_or_null("UI/HUD/CrosshairContainer/VBox/StaminaBar")
	crosshair_container = main_node.get_node_or_null("UI/HUD/CrosshairContainer")
	crosshair_dot = main_node.get_node_or_null("UI/HUD/CrosshairContainer/VBox/DotContainer/Dot")
	reticle_ring = main_node.get_node_or_null("UI/HUD/CrosshairContainer/VBox/DotContainer/ReticleRing")
	setup_room_ui()

func setup_room_ui() -> void:
	var View = preload("res://src/ui/tablet_shop_view.gd")
	var panel = _main.get_node("UI/HUD/TopLeft")
	panel.add_theme_stylebox_override("panel", View.style(Color("101f2bef"), Color("31525c"), 10))
	var box = pop_count_label.get_parent()
	box.add_theme_constant_override("separation", 5)
	pop_count_label.add_theme_font_size_override("font_size", 16)
	room_identity = Label.new()
	room_identity.add_theme_font_size_override("font_size", 11)
	room_identity.add_theme_color_override("font_color", Color("73ddca"))
	box.add_child(room_identity)
	box.move_child(room_identity, 0)
	arrival = Label.new()
	arrival.name = "RoomArrival"
	arrival.mouse_filter = Control.MOUSE_FILTER_IGNORE
	arrival.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	arrival.add_theme_font_size_override("font_size", 24)
	arrival.add_theme_color_override("font_color", Color("b1f2e4"))
	arrival.add_theme_color_override("font_outline_color", Color("101f2b"))
	arrival.add_theme_constant_override("outline_size", 6)
	_main.get_node("UI/HUD").add_child(arrival)
	arrival.set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP)
	arrival.offset_left = -300
	arrival.offset_right = 300
	arrival.offset_top = 100
	arrival.offset_bottom = 160
	arrival.hide()
	_main.shop_manager.room_switched.connect(show_room_arrival)
	_setup_maintenance_objective(View)

func _setup_maintenance_objective(view_script: Script) -> void:
	var hud: Control = _main.get_node("UI/HUD")
	maintenance_panel = PanelContainer.new()
	maintenance_panel.name = "MaintenanceObjective"
	maintenance_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	maintenance_panel.anchor_left = 0.5
	maintenance_panel.anchor_right = 0.5
	maintenance_panel.offset_left = -200.0
	maintenance_panel.offset_right = 200.0
	maintenance_panel.offset_top = 18.0
	maintenance_panel.offset_bottom = 78.0
	maintenance_panel.add_theme_stylebox_override("panel", view_script.style(Color("321f1beF"), Color("ef8a3b"), 9))
	hud.add_child(maintenance_panel)
	var margin := MarginContainer.new()
	for side in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 8)
	maintenance_panel.add_child(margin)
	var stack := VBoxContainer.new()
	stack.add_theme_constant_override("separation", 2)
	margin.add_child(stack)
	maintenance_label = Label.new()
	maintenance_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	maintenance_label.add_theme_font_size_override("font_size", 14)
	maintenance_label.add_theme_color_override("font_color", Color("ffd39a"))
	stack.add_child(maintenance_label)
	maintenance_hint = Label.new()
	maintenance_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	maintenance_hint.add_theme_font_size_override("font_size", 11)
	maintenance_hint.add_theme_color_override("font_color", Color("e9edf3"))
	stack.add_child(maintenance_hint)
	maintenance_panel.hide()

func show_room_arrival(room_id: String) -> void:
	if _arrival_tween: _arrival_tween.kill()
	arrival.text = str(_main.shop_manager.rooms[room_id].name).split(" (")[0].to_upper()
	arrival.modulate.a = 0.0
	arrival.show()
	_arrival_tween = create_tween()
	_arrival_tween.tween_property(arrival, "modulate:a", 1.0, 0.35)
	_arrival_tween.tween_interval(2.2)
	_arrival_tween.tween_property(arrival, "modulate:a", 0.0, 0.6)
	_arrival_tween.tween_callback(arrival.hide)

func _process(delta: float) -> void:
	# Hundreds of pops/coins in one frame need one text rebuild, not hundreds.
	if counter_dirty:
		counter_dirty = false
		_apply_pop_counter(counter_pops, counter_pps, counter_prestige, counter_coins, counter_progress_multiplier, counter_coin_multiplier)
	_update_maintenance_objective()
	if not room_identity or not _main.shop_manager: return
	_room_refresh += delta
	if _room_refresh < 0.25: return
	_room_refresh = 0.0
	var shop = _main.shop_manager
	room_identity.text = str(shop.rooms[shop.current_room].name).split(" (")[0]

func _update_maintenance_objective() -> void:
	if not maintenance_panel or not is_instance_valid(_main):
		return
	if not _main.is_blackout:
		maintenance_panel.hide()
		return
	var pipe = _main.room_controller.broken_pipe if _main.room_controller else null
	var target: Node3D
	var headline := ""
	var hint := ""
	if pipe and is_instance_valid(pipe) and pipe.is_ruptured:
		target = pipe
		headline = "BORU ARIZASI • %s" % _maintenance_direction(target)
		hint = "Boruyu onar • %s" % _maintenance_distance(target)
	else:
		var power = _main.room_controller.power_room if _main.room_controller else null
		if power and is_instance_valid(power):
			target = power.breaker_switch if power.get("breaker_switch") is Node3D else power
			headline = "ELEKTRİK KESİK • %s" % _maintenance_direction(target)
			hint = "Jeneratör panosuna git ve [E] ile şalteri kaldır • %s" % _maintenance_distance(target)
	if not target:
		maintenance_panel.hide()
		return
	maintenance_label.text = headline
	maintenance_hint.text = hint
	maintenance_panel.show()

func _maintenance_direction(target: Node3D) -> String:
	var camera: Camera3D = _main.player.camera if _main.player else null
	if not camera or not is_instance_valid(target):
		return ""
	var local_dir: Vector3 = camera.global_basis.inverse() * (target.global_position - camera.global_position)
	var angle := rad_to_deg(atan2(local_dir.x, -local_dir.z))
	var arrows := ["↑", "↗", "→", "↘", "↓", "↙", "←", "↖"]
	var arrow_index := posmod(int(round(angle / 45.0)), arrows.size())
	return str(arrows[arrow_index])

func _maintenance_distance(target: Node3D) -> String:
	var distance: float = _main.player.global_position.distance_to(target.global_position) if _main.player else 0.0
	return "%.0f m" % distance

func update_playtime(time_str: String) -> void:
	if playtime_label:
		playtime_label.text = time_str

var counter_dirty := false
var counter_pops := 0
var counter_pps := 0
var counter_prestige := 0
var counter_coins := 0
var counter_progress_multiplier := 1
var counter_coin_multiplier := 1

func update_pop_counter(pops: int, pps: int, prestige_level: int, coins: int, progress_multiplier: int = 1, coin_multiplier: int = 1) -> void:
	counter_pops = pops
	counter_pps = pps
	counter_prestige = prestige_level
	counter_coins = coins
	counter_progress_multiplier = progress_multiplier
	counter_coin_multiplier = coin_multiplier
	counter_dirty = true

func _apply_pop_counter(pops: int, pps: int, prestige_level: int, coins: int, progress_multiplier: int, coin_multiplier: int) -> void:
	if pop_count_label:
		var prefix = "★%d " % prestige_level if prestige_level > 0 else ""
		var pps_str = " (+%d/s)" % pps if pps > 0 else ""
		var progress_tag := " ×%d test" % progress_multiplier if progress_multiplier > 1 else ""
		var shown_coins := coins * maxi(1, coin_multiplier)
		pop_count_label.text = "%s%s 🎈%s%s    %s 🪙" % [prefix, format_number(pops), progress_tag, pps_str, format_number(shown_coins)]
		
	if grand_goal_bar:
		grand_goal_bar.value = min(float(pops), 1000000.0)
		
	if grand_goal_label:
		var target = 1000000
		var pct = (float(pops) / float(target)) * 100.0
		if pops >= target:
			grand_goal_label.text = "Hedef: Tamamlandı! (%100)"
			grand_goal_label.add_theme_color_override("font_color", Color("#2ecc71"))
		else:
			grand_goal_label.text = "Hedef: %%%0.1f (1.000.000)" % pct

func update_pressure(active_effective: int, max_cap: int, physical_count: int = -1) -> void:
	var cap = max(1, max_cap)
	current_pressure_ratio = clamp(float(active_effective) / float(cap), 0.0, 1.5)
	var pct = int(round(current_pressure_ratio * 100.0))
	
	if pressure_bar:
		pressure_bar.value = pct
	if pressure_label:
		var count_info = " (%d/%d Balon)" % [active_effective, cap]
		if current_pressure_ratio >= 0.85:
			pressure_label.text = "Basınç: %%%d (Kritik!)%s" % [pct, count_info]
			pressure_label.add_theme_color_override("font_color", Color(1.0, 0.3, 0.3))
			was_overpressure_critical = true
		elif current_pressure_ratio >= 0.65:
			pressure_label.text = "Basınç: %%%d%s" % [pct, count_info]
			pressure_label.add_theme_color_override("font_color", Color(1.0, 0.75, 0.2))
		else:
			pressure_label.text = "Basınç: %%%d%s" % [pct, count_info]
			pressure_label.add_theme_color_override("font_color", Color(0.3, 0.85, 1.0))
			
			if was_overpressure_critical and current_pressure_ratio < 0.60:
				was_overpressure_critical = false
				overpressure_relieved.emit()

func show_prompt(msg: String, auto_hide_seconds: float = 0.0) -> void:
	if desk_prompt:
		desk_prompt.text = msg
		desk_prompt.visible = true
		if auto_hide_seconds > 0.0:
			var t = create_tween()
			t.tween_interval(auto_hide_seconds)
			t.tween_callback(func():
				if desk_prompt and desk_prompt.text == msg:
					desk_prompt.visible = false
			)

func hide_prompt() -> void:
	if desk_prompt:
		desk_prompt.visible = false

func pulse_crosshair(is_hit: bool) -> void:
	if not crosshair_dot: return
	if _reticle_tween: _reticle_tween.kill()
	var tween = create_tween()
	_reticle_tween = tween
	tween.set_parallel(true)
	if is_hit:
		crosshair_dot.scale = Vector2(2.6, 2.6)
		crosshair_dot.color = Color(0.2, 1.0, 0.7, 1.0)
		tween.tween_property(crosshair_dot, "scale", Vector2.ONE, 0.09).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		tween.tween_property(crosshair_dot, "color", Color(1, 1, 1, 0.85), 0.09)
	else:
		crosshair_dot.scale = Vector2(1.5, 1.5)
		crosshair_dot.color = Color(1.0, 0.8, 0.3, 0.9)
		tween.tween_property(crosshair_dot, "scale", Vector2.ONE, 0.06).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		tween.tween_property(crosshair_dot, "color", Color(1, 1, 1, 0.85), 0.06)

func pulse_crosshair_nudge() -> void:
	if not crosshair_dot: return
	var tween = create_tween()
	tween.set_parallel(true)
	crosshair_dot.scale = Vector2(1.9, 1.9)
	crosshair_dot.color = Color(0.3, 0.75, 1.0, 0.95)
	tween.tween_property(crosshair_dot, "scale", Vector2.ONE, 0.12).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween.tween_property(crosshair_dot, "color", Color(1, 1, 1, 0.85), 0.12)

func update_stamina(current: float, max_energy: float, is_exhausted: bool) -> void:
	if crosshair_stamina_bar:
		crosshair_stamina_bar.max_value = max_energy
		crosshair_stamina_bar.value = current
		
		var is_full = is_equal_approx(current, max_energy)
		var target_alpha = 0.0 if is_full else 1.0
		
		if _stamina_tween: _stamina_tween.kill()
		var tween = create_tween()
		_stamina_tween = tween
		tween.tween_property(crosshair_stamina_bar, "modulate:a", target_alpha, 0.15)
		
		var style = crosshair_stamina_bar.get_theme_stylebox("fill")
		if style is StyleBoxFlat:
			if is_exhausted:
				style.bg_color = Color("#ff4757")
			elif current < (max_energy * 0.35):
				style.bg_color = Color("#ffa502")
			else:
				style.bg_color = Color("#2ed573")

func set_reticle_highlight(is_balloon: bool, is_interactive: bool) -> void:
	if is_balloon:
		if reticle_ring: reticle_ring.modulate = Color(1.0, 0.3, 0.5, 0.9)
		if crosshair_dot: crosshair_dot.color = Color(1.0, 0.4, 0.6, 1.0)
	elif is_interactive:
		if reticle_ring: reticle_ring.modulate = Color(0.3, 0.8, 1.0, 0.95)
		if crosshair_dot: crosshair_dot.color = Color(0.3, 0.8, 1.0, 1.0)
	else:
		if reticle_ring: reticle_ring.modulate = Color(1, 1, 1, 0)
		if crosshair_dot: crosshair_dot.color = Color(1, 1, 1, 0.85)

func update_macro_badge(is_active: bool) -> void:
	if auto_fire_badge:
		auto_fire_badge.visible = is_active

func format_number(val: int) -> String:
	var s = str(val)
	var res = ""
	var count = 0
	for i in range(s.length() - 1, -1, -1):
		if count > 0 and count % 3 == 0:
			res = "." + res
		res = s[i] + res
		count += 1
	return res

func trigger_jackpot_rain(coin_amount: int = 50, tier_name: String = "GOLD") -> void:
	if not _main or not is_instance_valid(_main): return
	var hud_node = _main.get_node_or_null("UI/HUD")
	if not hud_node: return
	
	# 1. Floating Jackpot Banner
	var banner = Label.new()
	banner.text = "★ %s JACKPOT! +%s COIN ★" % [tier_name.to_upper(), format_number(coin_amount)]
	banner.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	banner.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	banner.add_theme_font_size_override("font_size", 28)
	banner.add_theme_color_override("font_color", Color(1.0, 0.90, 0.25))
	banner.add_theme_color_override("font_outline_color", Color(0.12, 0.08, 0.02, 0.9))
	banner.add_theme_constant_override("outline_size", 8)
	banner.mouse_filter = Control.MOUSE_FILTER_IGNORE
	banner.set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP)
	banner.offset_left = -350
	banner.offset_right = 350
	banner.offset_top = 135
	banner.offset_bottom = 195
	banner.modulate.a = 0.0
	banner.scale = Vector2(0.6, 0.6)
	banner.pivot_offset = Vector2(350, 30)
	hud_node.add_child(banner)
	
	var banner_tween = banner.create_tween()
	banner_tween.set_parallel(true)
	banner_tween.tween_property(banner, "modulate:a", 1.0, 0.18)
	banner_tween.tween_property(banner, "scale", Vector2.ONE, 0.22).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	banner_tween.chain().tween_interval(1.1)
	banner_tween.chain().tween_property(banner, "modulate:a", 0.0, 0.45)
	banner_tween.chain().tween_callback(banner.queue_free)
	
	# 2. 2D Screen-space Golden Coin Rain (Fast, smooth, zero-clutter)
	var viewport_size = hud_node.get_viewport_rect().size
	var coin_count = mini(32, maxi(16, int(coin_amount * 0.4)))
	
	for i in range(coin_count):
		var coin = Panel.new()
		coin.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var coin_size = randf_range(16.0, 24.0)
		coin.custom_minimum_size = Vector2(coin_size, coin_size)
		coin.size = Vector2(coin_size, coin_size)
		
		# Round golden coin style
		var sb = StyleBoxFlat.new()
		sb.bg_color = Color(1.0, 0.82, 0.15, 0.95)
		sb.border_color = Color(1.0, 0.96, 0.7, 1.0)
		sb.set_border_width_all(2)
		sb.set_corner_radius_all(int(coin_size * 0.5))
		coin.add_theme_stylebox_override("panel", sb)
		
		# Inner coin symbol ($)
		var sym = Label.new()
		sym.text = "✦"
		sym.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		sym.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		sym.add_theme_font_size_override("font_size", int(coin_size * 0.6))
		sym.add_theme_color_override("font_color", Color(0.7, 0.45, 0.05, 0.9))
		sym.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		coin.add_child(sym)
		
		var start_x = randf_range(40.0, viewport_size.x - 40.0)
		var start_y = randf_range(-80.0, -20.0)
		coin.position = Vector2(start_x, start_y)
		coin.pivot_offset = Vector2(coin_size * 0.5, coin_size * 0.5)
		hud_node.add_child(coin)
		
		# Cascade down with physics-like gravity and horizontal sway
		var fall_duration = randf_range(1.1, 1.7)
		var end_y = viewport_size.y + 40.0
		var drift_x = start_x + randf_range(-120.0, 120.0)
		var rot_amount = randf_range(-360.0, 360.0)
		
		var c_tween = coin.create_tween()
		c_tween.set_parallel(true)
		c_tween.tween_property(coin, "position:y", end_y, fall_duration).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
		c_tween.tween_property(coin, "position:x", drift_x, fall_duration).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
		c_tween.tween_property(coin, "rotation_degrees", rot_amount, fall_duration)
		# Scale squeeze simulating 3D coin spin
		c_tween.tween_property(coin, "scale:x", 0.2, fall_duration * 0.25).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
		c_tween.chain().tween_property(coin, "scale:x", 1.0, fall_duration * 0.25)
		c_tween.chain().tween_property(coin, "scale:x", 0.2, fall_duration * 0.25)
		c_tween.chain().tween_property(coin, "scale:x", 1.0, fall_duration * 0.25)
		c_tween.chain().tween_callback(coin.queue_free)
