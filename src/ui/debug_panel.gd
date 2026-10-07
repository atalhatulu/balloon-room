extends Control

const BalanceDiagnostics = preload("res://src/core/balance_diagnostics.gd")

# Live Debug & Oda Hızlı Test Paneli
# Toggle: F1, F2 veya ~ (Tilde)

var main_node: Node3D = null
var shop_manager: Node = null
var game_manager: Node = null
var player: CharacterBody3D = null

var tab_container: TabContainer = null
var analytics_summary_lbl: Label = null
var analytics_balance_lbl: Label = null
var analytics_minute_box: VBoxContainer = null

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
		_refresh_analytics_view()
	else:
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
		
	if not main_node: main_node = get_node_or_null("/root/Main")
	if main_node and main_node.get("player"):
		var p = main_node.get("player")
		if p and p.has_method("set_ui_open"):
			p.set_ui_open(visible)

func _build_ui() -> void:
	anchor_right = 1.0
	anchor_bottom = 1.0
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	
	var bg = ColorRect.new()
	bg.color = Color(0.03, 0.05, 0.08, 0.92)
	bg.anchor_right = 1.0
	bg.anchor_bottom = 1.0
	bg.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(bg)
	
	var margin = MarginContainer.new()
	margin.anchor_right = 1.0
	margin.anchor_bottom = 1.0
	margin.add_theme_constant_override("margin_left", 30)
	margin.add_theme_constant_override("margin_right", 30)
	margin.add_theme_constant_override("margin_top", 20)
	margin.add_theme_constant_override("margin_bottom", 20)
	add_child(margin)
	
	var main_vbox = VBoxContainer.new()
	main_vbox.add_theme_constant_override("separation", 10)
	margin.add_child(main_vbox)
	
	var header = HBoxContainer.new()
	main_vbox.add_child(header)
	
	var title = Label.new()
	title.text = "DEBUG & ODA TEST PANELİ [F1]"
	title.add_theme_font_size_override("font_size", 18)
	title.add_theme_color_override("font_color", Color(0.2, 0.9, 1.0))
	header.add_child(title)
	
	var spacer = Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(spacer)
	
	var btn_close = Button.new()
	btn_close.text = " ✕ Kapat (F1 / ESC) "
	btn_close.pressed.connect(func(): toggle_panel())
	header.add_child(btn_close)
	
	tab_container = TabContainer.new()
	tab_container.size_flags_vertical = Control.SIZE_EXPAND_FILL
	main_vbox.add_child(tab_container)
	
	_build_room_teleport_tab()
	_build_analytics_tab()
	_build_quick_tools_tab()

func _build_room_teleport_tab() -> void:
	var scroll = ScrollContainer.new()
	scroll.name = "🚪 Odalar & Test Başlangıçları"
	tab_container.add_child(scroll)
	
	var vbox = VBoxContainer.new()
	vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	vbox.add_theme_constant_override("separation", 14)
	scroll.add_child(vbox)
	
	var desc = Label.new()
	desc.text = "Her odayı sıfırdan oynamadan test edin. Seçtiğiniz odaya tıklandığında önceki odaların tüm yükseltmeleri ve cihazları otomatik kurulur, balon hedefi ve seviyesi ayarlanır, coin 0'lanır."
	desc.add_theme_color_override("font_color", Color(0.8, 0.88, 0.95))
	desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	vbox.add_child(desc)
	
	var grid = GridContainer.new()
	grid.columns = 3
	grid.add_theme_constant_override("h_separation", 14)
	grid.add_theme_constant_override("v_separation", 14)
	vbox.add_child(grid)
	
	_add_room_card(grid, "Oda 1: Başlangıç Atölyesi", "small_room", "0 Pop | 0 Coin | Temel İğne Başlangıcı\n(Hedef: 5.000)", Color(0.3, 0.8, 0.5))
	_add_room_card(grid, "Oda 2: Üretim Tesisi", "medium_room", "15.000 Pop | 0 Coin | 1. Oda yükseltmeleri tam\n(Hedef: 250.000)", Color(0.2, 0.8, 1.0))
	_add_room_card(grid, "Oda 3: Mega Hangar", "hangar", "250.000 Pop | 0 Coin | 2. Oda otomasyon ağı kurulu\n(Hedef: 350.000)", Color(1.0, 0.75, 0.2))

func _add_room_card(parent: Control, card_title: String, room_id: String, details: String, accent_color: Color) -> void:
	var panel = PanelContainer.new()
	var sb = StyleBoxFlat.new()
	sb.bg_color = Color(0.08, 0.11, 0.16, 0.95)
	sb.border_width_left = 2
	sb.border_color = accent_color
	sb.set_corner_radius_all(6)
	panel.add_theme_stylebox_override("panel", sb)
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	parent.add_child(panel)
	
	var m = MarginContainer.new()
	for s in ["left", "right", "top", "bottom"]: m.add_theme_constant_override("margin_" + s, 12)
	panel.add_child(m)
	
	var v = VBoxContainer.new()
	v.add_theme_constant_override("separation", 6)
	m.add_child(v)
	
	var lbl_t = Label.new()
	lbl_t.text = card_title
	lbl_t.add_theme_font_size_override("font_size", 15)
	lbl_t.add_theme_color_override("font_color", accent_color)
	v.add_child(lbl_t)
	
	var lbl_d = Label.new()
	lbl_d.text = details
	lbl_d.add_theme_font_size_override("font_size", 12)
	lbl_d.add_theme_color_override("font_color", Color(0.8, 0.85, 0.9))
	v.add_child(lbl_d)
	
	var btn = Button.new()
	btn.text = "🚀 Bu Odayı Yükle ve Başlat"
	btn.pressed.connect(func():
		_load_room_preset(room_id)
		toggle_panel()
	)
	v.add_child(btn)

func _load_room_preset(room_id: String) -> void:
	if not main_node: main_node = get_node_or_null("/root/Main")
	if main_node and main_node.get("game_state_controller"):
		var gsc = main_node.get("game_state_controller")
		if gsc and gsc.has_method("load_room_preset"):
			gsc.load_room_preset(room_id)

func _build_analytics_tab() -> void:
	var scroll = ScrollContainer.new()
	scroll.name = "📊 Canlı Analitik & Teşhis"
	tab_container.add_child(scroll)
	
	var main_box = VBoxContainer.new()
	main_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	main_box.add_theme_constant_override("separation", 12)
	scroll.add_child(main_box)
	
	var card = PanelContainer.new()
	var card_sb = StyleBoxFlat.new()
	card_sb.bg_color = Color(0.07, 0.10, 0.15, 0.95)
	card_sb.set_corner_radius_all(6)
	card.add_theme_stylebox_override("panel", card_sb)
	main_box.add_child(card)
	
	var card_margin = MarginContainer.new()
	for s in ["left", "right", "top", "bottom"]: card_margin.add_theme_constant_override("margin_" + s, 12)
	card.add_child(card_margin)
	
	var card_vbox = VBoxContainer.new()
	card_margin.add_child(card_vbox)
	
	analytics_summary_lbl = Label.new()
	analytics_summary_lbl.text = "İstatistikler yükleniyor..."
	analytics_summary_lbl.add_theme_font_size_override("font_size", 13)
	card_vbox.add_child(analytics_summary_lbl)

	var balance_card := PanelContainer.new()
	var balance_style := StyleBoxFlat.new()
	balance_style.bg_color = Color(0.05, 0.14, 0.16, 0.96)
	balance_style.set_corner_radius_all(6)
	balance_card.add_theme_stylebox_override("panel", balance_style)
	main_box.add_child(balance_card)
	
	var balance_margin := MarginContainer.new()
	for side in ["left", "right", "top", "bottom"]: balance_margin.add_theme_constant_override("margin_" + side, 10)
	balance_card.add_child(balance_margin)
	
	var balance_box := VBoxContainer.new()
	balance_margin.add_child(balance_box)
	
	var balance_title := Label.new()
	balance_title.text = "🎯 Denge ve Darboğaz Teşhisi"
	balance_title.add_theme_font_size_override("font_size", 15)
	balance_title.add_theme_color_override("font_color", Color(0.3, 0.9, 0.8))
	balance_box.add_child(balance_title)
	
	analytics_balance_lbl = Label.new()
	analytics_balance_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	analytics_balance_lbl.text = "En az 1 dakika normal oynanış verisi gerekli."
	analytics_balance_lbl.add_theme_font_size_override("font_size", 13)
	balance_box.add_child(analytics_balance_lbl)
	
	var btn_bar = HBoxContainer.new()
	btn_bar.add_theme_constant_override("separation", 10)
	card_vbox.add_child(btn_bar)
	
	var btn_copy_json = Button.new()
	btn_copy_json.text = "📋 Tüm Analitik Veriyi Kopyala (JSON)"
	btn_copy_json.pressed.connect(func():
		var data = _generate_analytics_dict()
		DisplayServer.clipboard_set(JSON.stringify(data, "  "))
		btn_copy_json.text = "✔ Kopyalandı!"
		get_tree().create_timer(2.0).timeout.connect(func(): if is_instance_valid(btn_copy_json): btn_copy_json.text = "📋 Tüm Analitik Veriyi Kopyala (JSON)")
	)
	btn_bar.add_child(btn_copy_json)
	
	var btn_refresh = Button.new()
	btn_refresh.text = "🔄 Yenile"
	btn_refresh.pressed.connect(func(): _refresh_analytics_view())
	btn_bar.add_child(btn_refresh)
	
	var left_title = Label.new()
	left_title.text = "⏱ Dakika Bazlı İlerleme Çizelgesi"
	left_title.add_theme_font_size_override("font_size", 14)
	left_title.add_theme_color_override("font_color", Color(0.3, 0.9, 1.0))
	main_box.add_child(left_title)
	
	var left_scroll = ScrollContainer.new()
	left_scroll.custom_minimum_size = Vector2(0, 220)
	left_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	main_box.add_child(left_scroll)
	
	analytics_minute_box = VBoxContainer.new()
	analytics_minute_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	analytics_minute_box.add_theme_constant_override("separation", 4)
	left_scroll.add_child(analytics_minute_box)

func _build_quick_tools_tab() -> void:
	var scroll = ScrollContainer.new()
	scroll.name = "⚡ Hızlı Araçlar & Hileler"
	tab_container.add_child(scroll)
	
	var vbox = VBoxContainer.new()
	vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	vbox.add_theme_constant_override("separation", 12)
	scroll.add_child(vbox)
	
	var c_box = HBoxContainer.new()
	c_box.add_theme_constant_override("separation", 10)
	vbox.add_child(c_box)
	
	_add_cheat_btn(c_box, "+10.000 Coin", func(): if shop_manager: shop_manager.add_coins(10000))
	_add_cheat_btn(c_box, "+100.000 Coin", func(): if shop_manager: shop_manager.add_coins(100000))
	_add_cheat_btn(c_box, "+1.000.000 Coin", func(): if shop_manager: shop_manager.add_coins(1000000))

	var dev_box = HBoxContainer.new()
	dev_box.add_theme_constant_override("separation", 10)
	vbox.add_child(dev_box)
	
	_add_cheat_btn(dev_box, "🎁 Kargoya Tüm Cihazları Ekle", func():
		if main_node and main_node.factory:
			main_node.factory.orders.append({"id": "fan", "level": 3})
			main_node.factory.orders.append({"id": "electric_wall", "level": 3})
			main_node.factory.orders.append({"id": "spike_wall", "level": 3})
			main_node.factory.orders.append({"id": "magnet_pylon", "level": 3})
			main_node.factory.refresh()
	)
	_add_cheat_btn(dev_box, "🤖 Dronu Aç / Seviye Atlat", func():
		if shop_manager:
			var cur_lvl = int(shop_manager.upgrades.get("companion_drone", {}).get("level", 0))
			var next_lvl = mini(6, cur_lvl + 1 if cur_lvl > 0 else 1)
			shop_manager.upgrades["companion_drone"]["level"] = next_lvl
			if main_node and main_node.has_method("_on_upgrade_purchased"):
				main_node._on_upgrade_purchased("companion_drone", next_lvl)
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
	
	vbox.add_child(HSeparator.new())
	
	var act_box = HBoxContainer.new()
	act_box.add_theme_constant_override("separation", 10)
	vbox.add_child(act_box)
	
	_add_cheat_btn(act_box, "💥 Odadaki Tüm Balonları Patlat", func():
		var balloons = get_tree().get_nodes_in_group("balloons")
		for b in balloons:
			if b and is_instance_valid(b) and b.has_method("pop"):
				b.pop("debug_cheat")
	)
	_add_cheat_btn(act_box, "🎈 Odaya 150 Balon Dök", func():
		if main_node and main_node.has_method("drop_balloons_from_vent"):
			main_node.drop_balloons_from_vent(150)
	)
	_add_cheat_btn(act_box, "💰 Yerdeki Coinleri Topla", func():
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
	spd_lbl.text = "Simülasyon Hızı: "
	spd_box.add_child(spd_lbl)
	
	_add_cheat_btn(spd_box, "1.0x", func(): Engine.time_scale = 1.0)
	_add_cheat_btn(spd_box, "2.0x", func(): Engine.time_scale = 2.0)
	_add_cheat_btn(spd_box, "5.0x", func(): Engine.time_scale = 5.0)
	
	vbox.add_child(HSeparator.new())
	
	var test_box = HBoxContainer.new()
	test_box.add_theme_constant_override("separation", 10)
	vbox.add_child(test_box)
	
	_add_cheat_btn(test_box, "⚡ 2.000 Balon Stres Testi (Node)", func():
		Engine.time_scale = 1.0
		get_tree().change_scene_to_file("res://scenes/stress_test.tscn")
	)
	_add_cheat_btn(test_box, "🚀 5.000 MultiMesh+Server Prototip", func():
		Engine.time_scale = 1.0
		get_tree().change_scene_to_file("res://scenes/test_multimesh.tscn")
	)
	_add_cheat_btn(test_box, "🚨 Odaya +500 Balon Dök", func():
		if main_node and main_node.has_method("drop_balloons_from_vent"):
			main_node.drop_balloons_from_vent(500)
	)

func _add_cheat_btn(parent: Container, text: String, callback: Callable) -> void:
	var btn = Button.new()
	btn.text = text
	btn.pressed.connect(callback)
	parent.add_child(btn)

func _refresh_all_values() -> void:
	if not main_node: main_node = get_node_or_null("/root/Main")
	if main_node:
		shop_manager = main_node.get("shop_manager")
		game_manager = main_node.get("game_manager")
		player = main_node.get("player")
	_refresh_analytics_view()

func _refresh_analytics_view() -> void:
	if not game_manager:
		if not main_node: main_node = get_node_or_null("/root/Main")
		if main_node: game_manager = main_node.get("game_manager")
	if not game_manager: return
	
	var total_time = game_manager.get("session_elapsed_time") if ("session_elapsed_time" in game_manager) else 0.0
	var total_p = game_manager.get("total_pops") if ("total_pops" in game_manager) else 0
	var cur_coins = shop_manager.coins if shop_manager else 0
	var cur_pps = game_manager.get("smooth_pps") if ("smooth_pps" in game_manager) else 0.0
	var peak = game_manager.get("peak_pps") if ("peak_pps" in game_manager) else 0.0
	var cur_r = shop_manager.current_room if shop_manager else "small_room"
	
	var mins = int(total_time / 60.0)
	var secs = int(fmod(total_time, 60.0))
	var time_str = "%02d dk %02d sn" % [mins, secs]
	
	var cur_active = game_manager.get("active_balloons") if ("active_balloons" in game_manager) else 0
	var physical_balloons: int = game_manager.get_physical_balloon_count() if game_manager.has_method("get_physical_balloon_count") else 0
	var physics_budget: int = game_manager.get_physics_budget() if game_manager.has_method("get_physics_budget") else 0
	var cur_cap = max(1, game_manager.get("max_room_balloons") if ("max_room_balloons" in game_manager) else 100)
	var cur_pressure: int = game_manager.get_room_pressure_percent() if game_manager.has_method("get_room_pressure_percent") else clampi(int((float(cur_active) / float(cur_cap)) * 100.0), 0, 100)
	
	if analytics_summary_lbl:
		analytics_summary_lbl.text = "⏱ Süre: %s  |  🎈 Patlatma: %s  |  💰 Kasa: %s Coin\n⚡ Anlık Hız: %.1f balon/sn  |  🔥 Zirve: %.1f balon/sn  |  🏠 Mevcut Oda: %s\n📊 Basınç: %d%%  |  Fiziksel Balon: %d/%d bütçe" % [
			time_str, _format_number(total_p), _format_number(cur_coins), cur_pps, peak, cur_r, cur_pressure, physical_balloons, physics_budget
		]
	if analytics_balance_lbl and shop_manager:
		var diagnostics := BalanceDiagnostics.analyze({
			"room": cur_r, "pops": total_p, "seconds": total_time, "coins": cur_coins,
			"minute_snapshots": game_manager.minute_snapshots, "timeline_events": game_manager.timeline_events,
			"pop_sources": game_manager.pop_sources, "actual_spawn_rate": game_manager.get_actual_spawn_rate(),
			"weapon_active_seconds": game_manager.weapon_active_seconds, "dart_shots": game_manager.dart_shots, "dart_hit_shots": game_manager.dart_hit_shots,
			"nominal_spawn_rate": game_manager.get_effective_balloons_per_second(), "physical_balloons": physical_balloons,
			"physics_budget": physics_budget, "physics_limited_seconds": game_manager.get("physics_limited_seconds") if ("physics_limited_seconds" in game_manager) else 0.0,
			"production_enabled": game_manager.production_enabled
		})
		analytics_balance_lbl.text = "Hedef: %s / %s  •  Kalan: %s\nTeşhis: %s" % [
			_format_number(total_p), _format_number(diagnostics.target), _format_number(diagnostics.remaining), diagnostics.diagnosis
		]
		
	if analytics_minute_box:
		for c in analytics_minute_box.get_children(): c.queue_free()
		var snaps = game_manager.get("minute_snapshots") if ("minute_snapshots" in game_manager) else []
		if snaps.is_empty():
			var empty_lbl = Label.new()
			empty_lbl.text = "Henüz 1 dakika dolmadı. Her 60 saniyede bir otomatik snapshot kaydedilir."
			empty_lbl.add_theme_color_override("font_color", Color(0.6, 0.6, 0.7))
			analytics_minute_box.add_child(empty_lbl)
		else:
			for s in snaps:
				var row = Label.new()
				row.text = "[%s] Dk %d ➔ %s pop  |  %s Coin  |  %.1f pop/sn  |  %s  |  Fizik: %d/%d" % [
					s.get("time", "00:00"), s.get("minute", 0), _format_number(s.get("pops", 0)), _format_number(s.get("coins", 0)), s.get("pps", 0.0), s.get("room", ""), s.get("physical_balloons", 0), s.get("physics_budget", 0)
				]
				row.add_theme_font_size_override("font_size", 12)
				analytics_minute_box.add_child(row)

func _generate_analytics_dict() -> Dictionary:
	if not game_manager: return {}
	return {
		"session_playtime_seconds": game_manager.get("session_elapsed_time"),
		"total_pops": game_manager.get("total_pops"),
		"actual_spawn_rate": game_manager.get_actual_spawn_rate(),
		"physical_balloons": game_manager.get_physical_balloon_count() if game_manager.has_method("get_physical_balloon_count") else 0,
		"physics_budget": game_manager.get_physics_budget() if game_manager.has_method("get_physics_budget") else 0,
		"current_coins": shop_manager.coins if shop_manager else 0,
		"current_room": shop_manager.current_room if shop_manager else "",
		"peak_pps": game_manager.get("peak_pps"),
		"minute_snapshots": game_manager.get("minute_snapshots")
	}

func _format_number(val: int) -> String:
	var s = str(val)
	var res = ""
	var cnt = 0
	for i in range(s.length() - 1, -1, -1):
		res = s[i] + res
		cnt += 1
		if cnt % 3 == 0 and i > 0:
			res = "." + res
	return res
