extends Node

const ROOM_ORDER := ["small_room", "medium_room", "hangar"]

var main: Node
var enabled := false
var auto_purchase_enabled := true
var elapsed := 0.0
var shop_timer := 0.0
var menu_open := false
var selected_multiplier := 1
var selected_progress_multiplier := 1
var selected_coin_multiplier := 1
var menu_layer: CanvasLayer
var menu_root: Control
var god_mode_check: CheckButton
var auto_purchase_check: CheckButton
var multiplier_buttons: Dictionary = {}
var progress_multiplier_buttons: Dictionary = {}
var coin_multiplier_buttons: Dictionary = {}

func setup(owner: Node) -> void:
	main = owner
	process_mode = Node.PROCESS_MODE_PAUSABLE
	_build_menu()

func toggle_menu() -> void:
	if menu_open:
		apply_settings()
		return
	if main.shop_ui and main.shop_ui.shop_is_open:
		main.toggle_shop_modal()
	if main.modal_manager and main.modal_manager.pause_modal and main.modal_manager.pause_modal.visible:
		main.modal_manager.pause_modal.hide()
	selected_multiplier = main.game_manager.turbo_speed_multiplier
	selected_progress_multiplier = main.game_manager.turbo_pop_multiplier if main.game_manager.turbo_mode_enabled else 1
	selected_coin_multiplier = main.game_manager.turbo_coin_multiplier if main.game_manager.turbo_mode_enabled else 1
	god_mode_check.button_pressed = enabled
	auto_purchase_check.button_pressed = auto_purchase_enabled
	_update_multiplier_buttons()
	_update_progress_multiplier_buttons()
	_update_coin_multiplier_buttons()
	menu_open = true
	menu_root.show()
	get_tree().paused = true
	if main.player and main.player.has_method("set_ui_open"):
		main.player.set_ui_open(true)
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE

func apply_settings() -> void:
	if not main or not main.game_manager:
		return
	var gm = main.game_manager
	gm.turbo_mode_enabled = selected_multiplier > 1 or selected_progress_multiplier > 1 or selected_coin_multiplier > 1
	gm.turbo_speed_multiplier = selected_multiplier
	gm.turbo_production_multiplier = float(selected_multiplier)
	gm.turbo_pop_multiplier = selected_progress_multiplier
	gm.turbo_coin_multiplier = selected_coin_multiplier
	enabled = god_mode_check.button_pressed
	auto_purchase_enabled = auto_purchase_check.button_pressed
	shop_timer = 0.0
	_close_menu()
	if main.hud_controller:
		var automation := " • Üretim ×%d • İlerleme ×%d • Para ×%d" % [selected_multiplier, selected_progress_multiplier, selected_coin_multiplier]
		if not auto_purchase_enabled:
			automation += " • Otomatik market kapalı"
		else:
			automation += " • Otomatik market açık"
		if enabled:
			automation += " • God Mode açık"
		main.hud_controller.show_prompt("Test ayarları%s" % automation, 3.0)

func cancel_menu() -> void:
	_close_menu()

func _close_menu() -> void:
	menu_open = false
	menu_root.hide()
	get_tree().paused = false
	if main.player and main.player.has_method("set_ui_open"):
		main.player.set_ui_open(false)
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED

func _build_menu() -> void:
	menu_layer = CanvasLayer.new()
	menu_layer.name = "GodModeSettingsLayer"
	menu_layer.layer = 125
	menu_layer.process_mode = Node.PROCESS_MODE_ALWAYS
	main.add_child(menu_layer)
	menu_root = Control.new()
	menu_root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	menu_root.process_mode = Node.PROCESS_MODE_ALWAYS
	menu_root.mouse_filter = Control.MOUSE_FILTER_STOP
	menu_layer.add_child(menu_root)
	var backdrop := ColorRect.new()
	backdrop.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	backdrop.color = Color(0.015, 0.035, 0.055, 0.82)
	menu_root.add_child(backdrop)
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	menu_root.add_child(center)
	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(740, 748)
	var panel_style := StyleBoxFlat.new()
	panel_style.bg_color = Color("142a38")
	panel_style.border_color = Color("55c9c2")
	panel_style.set_border_width_all(2)
	panel_style.set_corner_radius_all(14)
	panel_style.content_margin_left = 28.0
	panel_style.content_margin_right = 28.0
	panel_style.content_margin_top = 24.0
	panel_style.content_margin_bottom = 22.0
	panel.add_theme_stylebox_override("panel", panel_style)
	center.add_child(panel)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 8)
	panel.add_child(column)
	var heading := Label.new()
	heading.text = "TEST MODU"
	heading.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	heading.add_theme_font_size_override("font_size", 28)
	heading.add_theme_color_override("font_color", Color("79e4d2"))
	column.add_child(heading)
	var info := Label.new()
	info.text = "Üretim balon akışını, ilerleme hedef puanını, coin çarpanı ise toplanan para ödülünü ayrı ayrı etkiler."
	info.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	info.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	info.add_theme_font_size_override("font_size", 15)
	info.add_theme_color_override("font_color", Color("d0e0e9"))
	column.add_child(info)
	var production_title := Label.new()
	production_title.text = "Balon üretim çarpanı"
	production_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	production_title.add_theme_font_size_override("font_size", 15)
	production_title.add_theme_color_override("font_color", Color("79e4d2"))
	column.add_child(production_title)
	var speed_row := HBoxContainer.new()
	speed_row.alignment = BoxContainer.ALIGNMENT_CENTER
	speed_row.add_theme_constant_override("separation", 14)
	column.add_child(speed_row)
	for speed in [1, 2, 4]:
		_add_multiplier_button(speed, speed_row)
	var progress_title := Label.new()
	progress_title.text = "Patlatma ilerleme çarpanı"
	progress_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	progress_title.add_theme_font_size_override("font_size", 15)
	progress_title.add_theme_color_override("font_color", Color("79e4d2"))
	column.add_child(progress_title)
	var progress_row := HBoxContainer.new()
	progress_row.alignment = BoxContainer.ALIGNMENT_CENTER
	progress_row.add_theme_constant_override("separation", 14)
	column.add_child(progress_row)
	for progress_multiplier in [1, 2, 4]:
		_add_progress_multiplier_button(progress_multiplier, progress_row)
	var progress_info := Label.new()
	progress_info.text = "Balonun gerçek patlama sayısı değişmez. Örn. ×2 seçilirse her patlatma hedefe iki kat ilerleme verir."
	progress_info.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	progress_info.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	progress_info.add_theme_font_size_override("font_size", 12)
	progress_info.add_theme_color_override("font_color", Color("b6cad3"))
	column.add_child(progress_info)
	var coin_title := Label.new()
	coin_title.text = "Coin kazanç çarpanı"
	coin_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	coin_title.add_theme_font_size_override("font_size", 15)
	coin_title.add_theme_color_override("font_color", Color("79e4d2"))
	column.add_child(coin_title)
	var coin_row := HBoxContainer.new()
	coin_row.alignment = BoxContainer.ALIGNMENT_CENTER
	coin_row.add_theme_constant_override("separation", 14)
	column.add_child(coin_row)
	for coin_multiplier in [1, 2, 4]:
		_add_coin_multiplier_button(coin_multiplier, coin_row)
	var coin_info := Label.new()
	coin_info.text = "Balon başına düşen coin miktarı çarpılır; fiziksel balon ve patlama sayısı değişmez."
	coin_info.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	coin_info.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	coin_info.add_theme_font_size_override("font_size", 12)
	coin_info.add_theme_color_override("font_color", Color("b6cad3"))
	column.add_child(coin_info)
	god_mode_check = CheckButton.new()
	god_mode_check.text = "God mode otomasyonu"
	god_mode_check.add_theme_font_size_override("font_size", 14)
	column.add_child(god_mode_check)
	var god_info := Label.new()
	god_info.text = "Balonları otomatik patlatır ve düşen coinleri toplar."
	god_info.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	god_info.add_theme_font_size_override("font_size", 13)
	god_info.add_theme_color_override("font_color", Color("b6cad3"))
	column.add_child(god_info)
	auto_purchase_check = CheckButton.new()
	auto_purchase_check.text = "Market alımlarını otomatik yap"
	auto_purchase_check.button_pressed = auto_purchase_enabled
	auto_purchase_check.add_theme_font_size_override("font_size", 14)
	column.add_child(auto_purchase_check)
	var automation_info := Label.new()
	automation_info.text = "Sıradaki uygun yükseltme veya oda şartları karşılanınca alınır. Yeni cihazlar satın alınınca kargoda bekler."
	automation_info.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	automation_info.add_theme_font_size_override("font_size", 13)
	automation_info.add_theme_color_override("font_color", Color("b6cad3"))
	column.add_child(automation_info)
	var footer := Label.new()
	footer.text = "Oda kapasitesi ve basınç dengesi çarpan altında da işlemeye devam eder."
	footer.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	footer.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	footer.add_theme_font_size_override("font_size", 13)
	footer.add_theme_color_override("font_color", Color("9ab2c0"))
	column.add_child(footer)
	var actions := HBoxContainer.new()
	actions.alignment = BoxContainer.ALIGNMENT_CENTER
	actions.add_theme_constant_override("separation", 16)
	column.add_child(actions)
	var cancel := Button.new()
	cancel.text = "Vazgeç"
	cancel.custom_minimum_size = Vector2(140, 44)
	cancel.pressed.connect(cancel_menu)
	actions.add_child(cancel)
	var apply := Button.new()
	apply.text = "Uygula ve devam et"
	apply.custom_minimum_size = Vector2(220, 44)
	apply.pressed.connect(apply_settings)
	actions.add_child(apply)
	menu_root.hide()

func _add_multiplier_button(multiplier: int, row: HBoxContainer) -> void:
	var button := Button.new()
	button.text = "×%d" % multiplier
	button.custom_minimum_size = Vector2(130, 56)
	button.add_theme_font_size_override("font_size", 24)
	button.pressed.connect(func():
		selected_multiplier = multiplier
		_update_multiplier_buttons()
	)
	row.add_child(button)
	multiplier_buttons[multiplier] = button

func _add_progress_multiplier_button(multiplier: int, row: HBoxContainer) -> void:
	var button := Button.new()
	button.text = "×%d" % multiplier
	button.custom_minimum_size = Vector2(130, 48)
	button.add_theme_font_size_override("font_size", 20)
	button.pressed.connect(func():
		selected_progress_multiplier = multiplier
		_update_progress_multiplier_buttons()
	)
	row.add_child(button)
	progress_multiplier_buttons[multiplier] = button

func _add_coin_multiplier_button(multiplier: int, row: HBoxContainer) -> void:
	var button := Button.new()
	button.text = "×%d" % multiplier
	button.custom_minimum_size = Vector2(130, 48)
	button.add_theme_font_size_override("font_size", 20)
	button.pressed.connect(func():
		selected_coin_multiplier = multiplier
		_update_coin_multiplier_buttons()
	)
	row.add_child(button)
	coin_multiplier_buttons[multiplier] = button

func _update_coin_multiplier_buttons() -> void:
	for multiplier in coin_multiplier_buttons:
		var button: Button = coin_multiplier_buttons[multiplier]
		var selected := int(multiplier) == selected_coin_multiplier
		var style := StyleBoxFlat.new()
		style.bg_color = Color("1c594f") if selected else Color("203746")
		style.border_color = Color("74ead3") if selected else Color("3a5664")
		style.set_border_width_all(2)
		style.set_corner_radius_all(9)
		button.add_theme_stylebox_override("normal", style)
		button.add_theme_stylebox_override("hover", style)

func _update_multiplier_buttons() -> void:
	for multiplier in multiplier_buttons:
		var button: Button = multiplier_buttons[multiplier]
		var selected := int(multiplier) == selected_multiplier
		var style := StyleBoxFlat.new()
		style.bg_color = Color("1c594f") if selected else Color("203746")
		style.border_color = Color("74ead3") if selected else Color("3a5664")
		style.set_border_width_all(2)
		style.set_corner_radius_all(9)
		button.add_theme_stylebox_override("normal", style)
		button.add_theme_stylebox_override("hover", style)

func _update_progress_multiplier_buttons() -> void:
	for multiplier in progress_multiplier_buttons:
		var button: Button = progress_multiplier_buttons[multiplier]
		var selected := int(multiplier) == selected_progress_multiplier
		var style := StyleBoxFlat.new()
		style.bg_color = Color("1c594f") if selected else Color("203746")
		style.border_color = Color("74ead3") if selected else Color("3a5664")
		style.set_border_width_all(2)
		style.set_corner_radius_all(9)
		button.add_theme_stylebox_override("normal", style)
		button.add_theme_stylebox_override("hover", style)

func _process(delta: float) -> void:
	if (not enabled and not auto_purchase_enabled) or not main or get_tree().paused or main.is_loading_save:
		return
	if main.startup_modal and main.startup_modal.visible:
		return
	if enabled:
		elapsed += delta
		_pop_mature_balloons()
		_pull_coins()
		_advance_room_transition()
	shop_timer += delta
	if shop_timer >= 0.35:
		shop_timer = 0.0
		if enabled:
			_restore_power_if_needed()
			_start_room_production()
		if auto_purchase_enabled:
			_auto_purchase()

func _restore_power_if_needed() -> void:
	if not main.is_blackout:
		return
	var pipe = main.room_controller.get("broken_pipe") if main.room_controller else null
	if is_instance_valid(pipe) and pipe.get("is_ruptured") and pipe.has_method("repair"):
		pipe.repair()
	main.restore_power()

func _pop_mature_balloons() -> void:
	if not main.balloon_container:
		return
	for balloon in main.balloon_container.get_children():
		if not is_instance_valid(balloon) or balloon.is_queued_for_deletion() or balloon.get("is_popped"):
			continue
		if not balloon.has_meta("god_mode_spawn_time"):
			balloon.set_meta("god_mode_spawn_time", elapsed)
		elif elapsed - float(balloon.get_meta("god_mode_spawn_time")) >= 1.0:
			balloon.pop("god_mode")

func _pull_coins() -> void:
	if not main.coin_container:
		return
	for coin in main.coin_container.get_children():
		if is_instance_valid(coin) and not coin.is_queued_for_deletion() and not coin.get("collected"):
			coin.set("is_collecting", true)

func _advance_room_transition() -> void:
	if not main.factory or not main.shop_manager:
		return
	var portal: Node3D = main.factory.portal
	if is_instance_valid(portal) and not portal.get("transitioning") and float(portal.get("opening")) >= 0.8:
		# God mode performs the portal step so the run can continue without input.
		portal.set("armed", true)
		portal.enter()

func _start_room_production() -> void:
	if main.factory and main.factory.requires_wall_start and main.shop_manager.pending_room == "" and not main.is_blackout:
		main.factory.toggle_production(true)

func _auto_purchase() -> void:
	var shop = main.shop_manager
	var pops := int(main.game_manager.total_pops)
	if shop.pending_room != "":
		return
	# Let a player finish moving or placing a delivered device before the next
	# automatic order is made. Device unit purchases always enter factory cargo.
	if main.device_placement and main.device_placement.is_carrying():
		return

	# Keep each purchase subject to the same pop gates, room caps, prerequisites,
	# and coin checks as an ordinary market purchase.
	for upgrade_id in shop.upgrades.keys():
		var data: Dictionary = shop.upgrades[upgrade_id]
		var level := int(data.get("level", 0))
		if level >= int(data.get("max_level", 0)) or level >= shop.get_upgrade_room_cap(upgrade_id):
			continue
		if shop.get_upgrade_prerequisite_message(upgrade_id) != "":
			continue
		if pops < shop.get_upgrade_req_pops(upgrade_id, level) or not shop.can_afford(shop.get_upgrade_cost(upgrade_id, level)):
			continue
		if shop.buy_upgrade(upgrade_id, pops):
			return

	# Buy devices and their next technology levels through their normal market APIs.
	for device_id in shop.devices.keys():
		var device: Dictionary = shop.devices[device_id]
		var count := int(device.get("count", 0))
		if count == 0 or device_id == "gravity_regulator":
			if count < mini(int(device.get("max_count", 0)), shop.device_count_limit()) and shop.get_total_placed_devices() < shop.get_current_room_max_devices() and shop.get_device_prerequisite_message(device_id) == "" and pops >= shop.get_device_unit_req_pops(device_id, count) and shop.can_afford(shop.get_device_unit_cost(device_id, count)):
				if shop.buy_device_unit(device_id, pops):
					return
		if device_id == "gravity_regulator":
			if count > 0 and int(device.level) < int(device.max_level) and pops >= shop.get_device_tech_req_pops(device_id, int(device.level)) and shop.can_afford(shop.get_device_tech_cost(device_id, int(device.level))):
				if shop.buy_device_upgrade(device_id, pops): return
		else:
			for placed in main.active_placed_devices:
				if not is_instance_valid(placed) or str(placed.get_meta("device_type", "")) != device_id: continue
				var level: int = int(placed.level)
				if level >= mini(int(device.max_level), shop.device_level_limit()): continue
				if pops < shop.get_device_tech_req_pops(device_id, level) or not shop.can_afford(shop.get_device_tech_cost(device_id, level)): continue
				if main.device_placement.validate_position(placed, placed.position, placed.rotation.y, level + 1) != "": continue
				if main.device_placement.upgrade_specific_device(placed): return

		if count > 0 and device_id != "gravity_regulator" and count < mini(int(device.get("max_count", 0)), shop.device_count_limit()) and shop.get_total_placed_devices() < shop.get_current_room_max_devices() and pops >= shop.get_device_unit_req_pops(device_id, count) and shop.can_afford(shop.get_device_unit_cost(device_id, count)):
			if shop.buy_device_unit(device_id, pops):
				return
