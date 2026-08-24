extends Control

# Live Debug & Tuning Panel
# Toggleable with F1, F2 or ~ (Tilde)

var main_node: Node3D = null
var shop_manager: Node = null
var game_manager: Node = null
var player: CharacterBody3D = null

var tab_container: TabContainer = null

func _ready() -> void:
	visible = false
	process_mode = Node.PROCESS_MODE_ALWAYS
	
	main_node = get_node_or_null("/root/Main")
	if main_node:
		shop_manager = main_node.get("shop_manager")
		game_manager = main_node.get("game_manager")
		player = main_node.get("player")
		
	_build_ui()

func toggle_panel() -> void:
	visible = not visible
	if visible:
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
		_refresh_all_values()
	else:
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED

func _build_ui() -> void:
	anchor_right = 1.0
	anchor_bottom = 1.0
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	
	var bg = ColorRect.new()
	bg.color = Color(0.04, 0.06, 0.1, 0.88)
	bg.anchor_right = 1.0
	bg.anchor_bottom = 1.0
	bg.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(bg)
	
	var margin = MarginContainer.new()
	margin.anchor_right = 1.0
	margin.anchor_bottom = 1.0
	margin.add_theme_constant_override("margin_left", 30)
	margin.add_theme_constant_override("margin_right", 30)
	margin.add_theme_constant_override("margin_top", 25)
	margin.add_theme_constant_override("margin_bottom", 25)
	add_child(margin)
	
	var main_vbox = VBoxContainer.new()
	main_vbox.add_theme_constant_override("separation", 12)
	margin.add_child(main_vbox)
	
	var header = HBoxContainer.new()
	main_vbox.add_child(header)
	
	var title = Label.new()
	title.text = "CANLI DEBUG & OYUN İÇİ DEĞER AYARLAMA PANELİ  [F1 / ~]"
	title.add_theme_font_size_override("font_size", 20)
	title.add_theme_color_override("font_color", Color(0.2, 0.9, 1.0))
	header.add_child(title)
	
	var spacer = Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(spacer)
	
	var btn_close = Button.new()
	btn_close.text = "  ✕ Kapat (F1 / ESC)  "
	btn_close.pressed.connect(func(): toggle_panel())
	header.add_child(btn_close)
	
	tab_container = TabContainer.new()
	tab_container.size_flags_vertical = Control.SIZE_EXPAND_FILL
	main_vbox.add_child(tab_container)
	
	_build_magnet_tab()
	_build_balloons_tab()
	_build_player_tab()
	_build_devices_tab()
	_build_cheats_tab()

func _build_magnet_tab() -> void:
	var scroll = ScrollContainer.new()
	scroll.name = "Manyetik Çekim Kulesi"
	tab_container.add_child(scroll)
	
	var vbox = VBoxContainer.new()
	vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	vbox.add_theme_constant_override("separation", 10)
	scroll.add_child(vbox)
	
	var desc = Label.new()
	desc.text = "Manyetik Çekim Kulesinin her seviyedeki çekim gücü, yarıçapı ve küresel çarpanları:"
	desc.add_theme_color_override("font_color", Color(0.8, 0.85, 0.95))
	vbox.add_child(desc)
	
	var glob_box = HBoxContainer.new()
	vbox.add_child(glob_box)
	var glob_lbl = Label.new()
	glob_lbl.text = "Genel Çekim Gücü Çarpanı (Tüm Seviyeler): "
	glob_lbl.custom_minimum_size = Vector2(320, 0)
	glob_box.add_child(glob_lbl)
	
	var glob_slider = HSlider.new()
	glob_slider.min_value = 0.1
	glob_slider.max_value = 10.0
	glob_slider.step = 0.05
	glob_slider.value = 1.0
	glob_slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	glob_box.add_child(glob_slider)
	
	var glob_val_lbl = Label.new()
	glob_val_lbl.text = "1.00x"
	glob_val_lbl.custom_minimum_size = Vector2(70, 0)
	glob_box.add_child(glob_val_lbl)
	
	glob_slider.value_changed.connect(func(val):
		glob_val_lbl.text = str(snapped(val, 0.01)) + "x"
		var magnet_script = load("res://scripts/magnet_pylon.gd")
		if magnet_script:
			magnet_script.set("global_pull_multiplier", val)
	)
	
	vbox.add_child(HSeparator.new())
	
	var grid = GridContainer.new()
	grid.columns = 3
	grid.add_theme_constant_override("h_separation", 20)
	grid.add_theme_constant_override("v_separation", 8)
	vbox.add_child(grid)
	
	grid.add_child(_make_col_header("Seviye (Kademe)"))
	grid.add_child(_make_col_header("Çekim Yarıçapı (Metre)"))
	grid.add_child(_make_col_header("Çekim Kuvveti (Kuvvet Değeri)"))
	
	var ranges = [0.0, 2.5, 3.2, 4.0, 5.0, 6.2, 7.5, 9.0]
	var strengths = [0.0, 0.6, 1.0, 1.6, 2.4, 3.5, 4.8, 6.5]
	
	for lvl in range(1, 8):
		var l_lbl = Label.new()
		l_lbl.text = "Seviye " + str(lvl) + " (" + str(lvl) + "/7):"
		l_lbl.add_theme_color_override("font_color", Color(0.3, 0.9, 1.0))
		grid.add_child(l_lbl)
		
		var r_spin = SpinBox.new()
		r_spin.min_value = 0.5
		r_spin.max_value = 35.0
		r_spin.step = 0.1
		r_spin.value = ranges[lvl] if lvl < ranges.size() else 8.0
		grid.add_child(r_spin)
		r_spin.value_changed.connect(func(val):
			var magnet_script = load("res://scripts/magnet_pylon.gd")
			if magnet_script and "pull_ranges" in magnet_script:
				var arr = magnet_script.pull_ranges
				if lvl < arr.size():
					arr[lvl] = val
		)
		
		var s_spin = SpinBox.new()
		s_spin.min_value = 0.05
		s_spin.max_value = 50.0
		s_spin.step = 0.1
		s_spin.value = strengths[lvl] if lvl < strengths.size() else 5.0
		grid.add_child(s_spin)
		s_spin.value_changed.connect(func(val):
			var magnet_script = load("res://scripts/magnet_pylon.gd")
			if magnet_script and "pull_strengths" in magnet_script:
				var arr = magnet_script.pull_strengths
				if lvl < arr.size():
					arr[lvl] = val
		)

func _build_balloons_tab() -> void:
	var scroll = ScrollContainer.new()
	scroll.name = "Balonlar & Kademeler"
	tab_container.add_child(scroll)
	
	var vbox = VBoxContainer.new()
	vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	vbox.add_theme_constant_override("separation", 10)
	scroll.add_child(vbox)
	
	var header = Label.new()
	header.text = "Balon Boyutları (1x, 5x, 10x, 50x Ölçekleri):"
	header.add_theme_font_size_override("font_size", 16)
	header.add_theme_color_override("font_color", Color(1.0, 0.8, 0.2))
	vbox.add_child(header)
	
	var grid = GridContainer.new()
	grid.columns = 4
	grid.add_theme_constant_override("h_separation", 20)
	grid.add_theme_constant_override("v_separation", 8)
	vbox.add_child(grid)
	
	var tiers = [1, 5, 10, 50]
	var default_scales = {1: 0.95, 5: 1.50, 10: 2.05, 50: 2.80}
	var default_weights = {1: 35.0, 5: 40.0, 10: 20.0, 50: 5.0}
	
	for t in tiers:
		var t_lbl = Label.new()
		t_lbl.text = "Tier " + str(t) + "x Balon:"
		grid.add_child(t_lbl)
		
		var sc_box = HBoxContainer.new()
		var sc_lbl = Label.new()
		sc_lbl.text = "Ölçek: "
		sc_box.add_child(sc_lbl)
		var sc_spin = SpinBox.new()
		sc_spin.min_value = 0.3
		sc_spin.max_value = 8.0
		sc_spin.step = 0.05
		sc_spin.value = default_scales[t]
		sc_box.add_child(sc_spin)
		grid.add_child(sc_box)
		
		sc_spin.value_changed.connect(func(val):
			var b_script = load("res://scripts/balloon.gd")
			if b_script and "tier_scales" in b_script:
				b_script.tier_scales[t] = Vector3(val, val, val)
		)
		
		var wt_box = HBoxContainer.new()
		var wt_lbl = Label.new()
		wt_lbl.text = "Doğuş %: "
		wt_box.add_child(wt_lbl)
		var wt_spin = SpinBox.new()
		wt_spin.min_value = 0.0
		wt_spin.max_value = 100.0
		wt_spin.step = 1.0
		wt_spin.value = default_weights[t]
		wt_box.add_child(wt_spin)
		grid.add_child(wt_box)
		
		wt_spin.value_changed.connect(func(val):
			if main_node and "debug_tier_weights" in main_node:
				main_node.debug_tier_weights[t] = val / 100.0
		)
		
		grid.add_child(Control.new())
		
	vbox.add_child(HSeparator.new())
	
	var phys_header = Label.new()
	phys_header.text = "Oda Balon Fiziği (Yerçekimi & Sürtünme):"
	phys_header.add_theme_font_size_override("font_size", 16)
	phys_header.add_theme_color_override("font_color", Color(0.3, 0.9, 1.0))
	vbox.add_child(phys_header)
	
	var phys_grid = GridContainer.new()
	phys_grid.columns = 2
	phys_grid.add_theme_constant_override("h_separation", 25)
	phys_grid.add_theme_constant_override("v_separation", 10)
	vbox.add_child(phys_grid)
	
	_add_spinbox_row(phys_grid, "Balon Yerçekimi Ölçeği (Gravity Scale):", 0.0, 10.0, 0.05, 0.25, func(val):
		if main_node and "balloon_gravity_scales" in main_node:
			main_node.balloon_gravity_scales[0] = val
	)
	_add_spinbox_row(phys_grid, "Hava Sürtünmesi (Linear Damp):", 0.0, 10.0, 0.05, 0.35, func(val):
		if main_node and "balloon_linear_damps" in main_node:
			main_node.balloon_linear_damps[0] = val
	)
	_add_spinbox_row(phys_grid, "Tavandan Akış Hızı (Balon/Saniye):", 1.0, 1000.0, 1.0, 50.0, func(val):
		if game_manager:
			game_manager.balloons_per_second = val
	)
	_add_spinbox_row(phys_grid, "Oda Balon Kapasitesi (Limit):", 50.0, 100000.0, 50.0, 500.0, func(val):
		if game_manager:
			game_manager.max_room_balloons = int(val)
			game_manager.active_count_changed.emit(game_manager.active_balloons, game_manager.max_room_balloons)
	)

func _build_player_tab() -> void:
	var scroll = ScrollContainer.new()
	scroll.name = "Oyuncu & İğne"
	tab_container.add_child(scroll)
	
	var vbox = VBoxContainer.new()
	vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	vbox.add_theme_constant_override("separation", 12)
	scroll.add_child(vbox)
	
	var grid = GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", 25)
	grid.add_theme_constant_override("v_separation", 10)
	vbox.add_child(grid)
	
	_add_spinbox_row(grid, "Yürüme Hızı (m/s):", 2.0, 30.0, 0.2, 5.2, func(val):
		if player: player.walk_speed = val
	)
	_add_spinbox_row(grid, "Koşma Hızı (m/s):", 4.0, 50.0, 0.5, 8.4, func(val):
		if player: player.sprint_speed = val
	)
	_add_spinbox_row(grid, "İğne Vuruş Menzili (Metre):", 2.0, 60.0, 0.5, 5.5, func(val):
		if player and player.interaction_ray:
			player.interaction_ray.target_position = Vector3(0, 0, -val)
	)
	_add_spinbox_row(grid, "Sol Tık Basılı Tutma Enerji Tüketimi:", 0.0, 50.0, 0.5, 6.0, func(val):
		if player: player.pop_hold_energy_cost = val
	)
	_add_spinbox_row(grid, "Enerji Dolum Hızı (Birim/sn):", 1.0, 200.0, 1.0, 24.0, func(val):
		if player: player.energy_regen_rate = val
	)
	_add_spinbox_row(grid, "Enerji Dolum Başlama Gecikmesi (sn):", 0.0, 5.0, 0.05, 0.60, func(val):
		if player: player.energy_regen_delay = val
	)
	_add_spinbox_row(grid, "Splash Pop / Şok Dalgası Yarıçapı (m):", 0.0, 50.0, 0.5, 3.5, func(val):
		if player: player.splash_radius = val
	)
	_add_spinbox_row(grid, "Splash Pop Maksimum Hedef Sayısı:", 1.0, 500.0, 5.0, 30.0, func(val):
		if player: player.splash_max_targets = int(val)
	)

func _build_devices_tab() -> void:
	var scroll = ScrollContainer.new()
	scroll.name = "Cihazlar & Makineler"
	tab_container.add_child(scroll)
	
	var vbox = VBoxContainer.new()
	vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	vbox.add_theme_constant_override("separation", 12)
	scroll.add_child(vbox)
	
	var grid = GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", 25)
	grid.add_theme_constant_override("v_separation", 10)
	vbox.add_child(grid)
	
	_add_spinbox_row(grid, "Dikenli Zemin Patlatma Aralığı (Cooldown s):", 0.01, 1.0, 0.01, 0.06, func(val):
		var sw = load("res://scripts/spike_wall.gd")
		if sw and "pop_interval" in sw: sw.pop_interval = val
	)
	_add_spinbox_row(grid, "Elektrik Duvarı Şarj Süresi (Saniye):", 0.1, 10.0, 0.1, 1.6, func(val):
		var ew = load("res://scripts/electric_wall.gd")
		if ew and "charge_duration" in ew: ew.charge_duration = val
	)
	_add_spinbox_row(grid, "Lazer Dronu Atış Aralığı (Saniye):", 0.02, 2.0, 0.02, 0.18, func(val):
		var sd = load("res://scripts/sentry_drone.gd")
		if sd and "shoot_interval" in sd: sd.shoot_interval = val
	)
	_add_spinbox_row(grid, "Makaralı Öğütücü Taşıma Hızı (m/s):", 0.5, 20.0, 0.2, 4.2, func(val):
		var cc = load("res://scripts/conveyor_crusher.gd")
		if cc and "conveyor_speed" in cc: cc.conveyor_speed = val
	)
	# Wall Fan
	_add_spinbox_row(grid, "Vantilatör Rüzgar İtme Gücü:", 0.5, 40.0, 0.5, 3.2, func(val):
		var fan_script = load("res://scripts/fan.gd")
		if fan_script:
			fan_script.set("global_fan_multiplier", val / 3.2)
		var fans = get_tree().get_nodes_in_group("fans")
		for f in fans:
			if f and is_instance_valid(f): f.wind_strength = val
	)
	_add_spinbox_row(grid, "Vantilatör Üfleme Menzili (Metre):", 2.0, 40.0, 0.5, 7.5, func(val):
		var fans = get_tree().get_nodes_in_group("fans")
		for f in fans:
			if f and is_instance_valid(f): f.wind_range = val
	)
	# Wall Spikes
	_add_spinbox_row(grid, "Dikenli Duvar Bekleme Süresi (s):", 0.02, 1.0, 0.02, 0.55, func(val):
		var ws = load("res://scripts/wall_spikes.gd")
		if ws and "cooldown_intervals" in ws:
			ws.cooldown_intervals[1] = val
	)

func _build_cheats_tab() -> void:
	var scroll = ScrollContainer.new()
	scroll.name = "Hileler & Hızlı Test"
	tab_container.add_child(scroll)
	
	var vbox = VBoxContainer.new()
	vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	vbox.add_theme_constant_override("separation", 14)
	scroll.add_child(vbox)
	
	var c_box = HBoxContainer.new()
	c_box.add_theme_constant_override("separation", 10)
	vbox.add_child(c_box)
	
	_add_cheat_btn(c_box, "+10.000 Coin", func():
		if shop_manager:
			shop_manager.coins += 10000
			shop_manager.coins_changed.emit(shop_manager.coins)
	)
	_add_cheat_btn(c_box, "+100.000 Coin", func():
		if shop_manager:
			shop_manager.coins += 100000
			shop_manager.coins_changed.emit(shop_manager.coins)
	)
	_add_cheat_btn(c_box, "+1.000.000 Coin", func():
		if shop_manager:
			shop_manager.coins += 1000000
			shop_manager.coins_changed.emit(shop_manager.coins)
	)
	
	var p_box = HBoxContainer.new()
	p_box.add_theme_constant_override("separation", 10)
	vbox.add_child(p_box)
	
	_add_cheat_btn(p_box, "+10.000 Pop", func():
		if game_manager:
			game_manager.total_pops += 10000
			game_manager.pop_registered.emit(game_manager.total_pops)
	)
	_add_cheat_btn(p_box, "+100.000 Pop", func():
		if game_manager:
			game_manager.total_pops += 100000
			game_manager.pop_registered.emit(game_manager.total_pops)
	)
	_add_cheat_btn(p_box, "1.000.000 Pop (Hedefe Ulaş!)", func():
		if game_manager:
			game_manager.total_pops = 1000000
			game_manager.pop_registered.emit(game_manager.total_pops)
			if main_node and main_node.has_method("show_victory_screen"):
				main_node.show_victory_screen()
	)
	
	vbox.add_child(HSeparator.new())
	
	var act_box = HBoxContainer.new()
	act_box.add_theme_constant_override("separation", 10)
	vbox.add_child(act_box)
	
	_add_cheat_btn(act_box, "Odadaki Tüm Balonları Patlat", func():
		var balloons = get_tree().get_nodes_in_group("balloons")
		for b in balloons:
			if b and is_instance_valid(b) and b.has_method("pop"):
				b.pop("debug_cheat")
	)
	_add_cheat_btn(act_box, "Odayı Balonla Doldur (+200 Balon)", func():
		if main_node and main_node.has_method("drop_balloons_from_vent"):
			main_node.drop_balloons_from_vent(200)
	)
	_add_cheat_btn(act_box, "Yerdeki Coinleri Topla", func():
		var coins = get_tree().get_nodes_in_group("coins")
		for c in coins:
			if c and is_instance_valid(c) and c.has_method("collect_coin"):
				c.collect_coin()
	)
	
	vbox.add_child(HSeparator.new())
	
	var spd_box = HBoxContainer.new()
	spd_box.add_theme_constant_override("separation", 10)
	vbox.add_child(spd_box)
	
	var spd_lbl = Label.new()
	spd_lbl.text = "Oyun Simülasyon Hızı (Time Scale): "
	spd_box.add_child(spd_lbl)
	
	_add_cheat_btn(spd_box, "1.0x (Normal)", func(): Engine.time_scale = 1.0)
	_add_cheat_btn(spd_box, "2.0x (Hızlı)", func(): Engine.time_scale = 2.0)
	_add_cheat_btn(spd_box, "5.0x (Turbo)", func(): Engine.time_scale = 5.0)
	_add_cheat_btn(spd_box, "0.5x (Ağır Çekim)", func(): Engine.time_scale = 0.5)

func _make_col_header(txt: String) -> Label:
	var lbl = Label.new()
	lbl.text = txt
	lbl.add_theme_font_size_override("font_size", 14)
	lbl.add_theme_color_override("font_color", Color(1.0, 0.8, 0.2))
	return lbl

func _add_spinbox_row(parent: GridContainer, label_text: String, min_v: float, max_v: float, step_v: float, default_v: float, callback: Callable) -> void:
	var lbl = Label.new()
	lbl.text = label_text
	parent.add_child(lbl)
	
	var spin = SpinBox.new()
	spin.min_value = min_v
	spin.max_value = max_v
	spin.step = step_v
	spin.value = default_v
	parent.add_child(spin)
	spin.value_changed.connect(callback)

func _add_cheat_btn(parent: Container, text: String, callback: Callable) -> void:
	var btn = Button.new()
	btn.text = text
	btn.pressed.connect(callback)
	parent.add_child(btn)

func _refresh_all_values() -> void:
	if not main_node:
		main_node = get_node_or_null("/root/Main")
	if main_node:
		shop_manager = main_node.get("shop_manager")
		game_manager = main_node.get("game_manager")
		player = main_node.get("player")
