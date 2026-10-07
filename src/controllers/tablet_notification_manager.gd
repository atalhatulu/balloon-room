class_name TabletNotificationManager
extends Node

# Monitors coins, total pops, and shop state.
# When a player can afford an upgrade/device/room that they couldn't afford before,
# or when an item unlocks, pushes a sleek smartphone-like popup in the bottom right corner.

signal notification_triggered(title: String, subtitle: String, icon_text: String, cost_text: String)

var _main: Node3D = null
var _shop_manager: Node = null
var _game_manager: Node = null
var _sound_manager: Node = null

# State tracking to avoid notification spam
var _notified_items: Dictionary = {} # item_key -> level_or_count
var _toast_queue: Array[Dictionary] = []
var _is_displaying_toast: bool = false
var _notification_container: Control = null
var _active_panel: PanelContainer = null
var _active_tween: Tween = null
var _check_throttle_timer: float = 0.0

func setup(main_node: Node3D) -> void:
	_main = main_node
	_shop_manager = main_node.get_node_or_null("ShopManager")
	_game_manager = main_node.get_node_or_null("GameManager")
	_sound_manager = main_node.get_node_or_null("SoundManager")
	
	_create_ui_layer()
	
	if _shop_manager:
		if _shop_manager.has_signal("coins_changed"):
			_shop_manager.coins_changed.connect(_on_coins_or_pops_changed)
	if _game_manager:
		if _game_manager.has_signal("pop_registered"):
			_game_manager.pop_registered.connect(func(_total): _on_coins_or_pops_changed())

func _create_ui_layer() -> void:
	var canvas = CanvasLayer.new()
	canvas.name = "NotificationCanvasLayer"
	canvas.layer = 105 # Higher than quest UI, below modals
	add_child(canvas)
	
	_notification_container = Control.new()
	_notification_container.name = "NotificationContainer"
	_notification_container.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_notification_container.anchor_left = 0.0
	_notification_container.anchor_top = 0.0
	_notification_container.anchor_right = 1.0
	_notification_container.anchor_bottom = 1.0
	canvas.add_child(_notification_container)

func _process(delta: float) -> void:
	if _check_throttle_timer > 0.0:
		_check_throttle_timer -= delta
		
	if not _is_displaying_toast and not _toast_queue.is_empty():
		_display_next_toast()

func _on_coins_or_pops_changed(_val: int = 0) -> void:
	if _check_throttle_timer > 0.0:
		return
	_check_throttle_timer = 0.6 # Evaluate every 600ms at most
	check_affordable_unlocks()

func check_affordable_unlocks() -> void:
	if not is_instance_valid(_shop_manager) or not is_instance_valid(_game_manager):
		return
		
	var coins: int = _shop_manager.get_spendable_coin_balance()
	var total_pops: int = _game_manager.total_pops

	# Room progression is the main long-term goal, so surface it before routine
	# purchase notices once the milestone is reached.
	for room_id in _shop_manager.rooms:
		if _shop_manager.is_room_unlocked(room_id): continue
		var room: Dictionary = _shop_manager.rooms[room_id]
		if total_pops < int(room.get("unlock_pops", 0)): break
		var room_key: String = "room_" + str(room_id) + "_threshold"
		if not _notified_items.has(room_key):
			_notified_items[room_key] = true
			var room_name: String = str(room.get("name", room_id)).split(" (")[0]
			_queue_toast("ODA HEDEFİ TAMAM", "%s • Üretim durdu, odayı temizleyip portala gir" % room_name, "🏢", "PORTAL AÇILACAK")
			return
		break
	
	# 1. Check Standard Upgrades
	for up_id in _shop_manager.upgrades:
		var up: Dictionary = _shop_manager.upgrades[up_id]
		var cur_level: int = int(up.get("level", 0))
		var max_lvl: int = int(up.get("max_level", 8))
		if cur_level >= max_lvl or (up_id == "pipe_count" and cur_level + 1 >= _shop_manager.get_pipe_limit()):
			continue
			
		var req_pops: int = _shop_manager.get_upgrade_req_pops(up_id, cur_level)
		if total_pops < req_pops:
			continue
			
		var cost: int = _shop_manager.get_upgrade_cost(up_id, cur_level)
		if coins >= cost:
			var key = "up_" + up_id + "_lvl_" + str(cur_level + 1)
			if not _notified_items.has(key):
				_notified_items[key] = true
				var item_name: String = up.get("title", up_id)
				_queue_toast("TABLET BİLDİRİMİ", "%s (Sv. %d) Alınabilir!" % [item_name, cur_level + 1], "📲", "%d 🪙" % cost)
				return # Queue one notification per check to avoid flooding

	# 2. Check Devices
	for dev_id in _shop_manager.devices:
		if dev_id == "gravity_regulator" or not _shop_manager.automation_available(): continue
		if _main.shop_ui and not _main.shop_ui.DEVICE_MARKET_ENABLED: continue
		var dev: Dictionary = _shop_manager.devices[dev_id]
		var cur_count: int = int(dev.get("count", 0))
		var max_count: int = mini(int(dev.get("max_count", 6)), _shop_manager.device_count_limit())
		if _shop_manager.get_total_placed_devices() >= _shop_manager.get_current_room_max_devices(): continue
		
		# Device Unit Purchase
		if cur_count < max_count:
			var req_pops: int = _shop_manager.get_device_unit_req_pops(dev_id, cur_count)
			if total_pops >= req_pops:
				var cost: int = _shop_manager.get_device_unit_cost(dev_id, cur_count)
				if coins >= cost:
					var key = "dev_unit_" + dev_id + "_count_" + str(cur_count + 1)
					if not _notified_items.has(key):
						_notified_items[key] = true
						var dev_name: String = dev.get("name", dev_id)
						_queue_toast("YENİ CİHAZ HAZIR", "%s (%d. Adet) Kurulabilir!" % [dev_name, cur_count + 1], "⚡", "%d 🪙" % cost)
						return

func _queue_toast(title: String, subtitle: String, icon_text: String, cost_text: String) -> void:
	_toast_queue.append({
		"title": title,
		"subtitle": subtitle,
		"icon": icon_text,
		"cost": cost_text
	})

func _display_next_toast() -> void:
	if _toast_queue.is_empty():
		_is_displaying_toast = false
		return
		
	_is_displaying_toast = true
	var item = _toast_queue.pop_front()
	
	if is_instance_valid(_active_panel):
		_active_panel.queue_free()
		_active_panel = null
		
	# Play acoustic modern tablet chime
	if is_instance_valid(_sound_manager) and _sound_manager.has_method("play_notification"):
		_sound_manager.play_notification()
	notification_triggered.emit(item.get("title", ""), item.get("subtitle", ""), item.get("icon", ""), item.get("cost", ""))
		
	# Build phone/tablet notification toast UI
	var panel = PanelContainer.new()
	_active_panel = panel
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.custom_minimum_size = Vector2(340, 78)
	
	# Glassmorphism dark acrylic style
	var style = StyleBoxFlat.new()
	style.bg_color = Color(0.06, 0.09, 0.14, 0.94)
	style.border_color = Color(0.2, 0.75, 1.0, 0.85)
	style.set_border_width_all(2)
	style.set_corner_radius_all(10)
	style.shadow_color = Color(0.0, 0.0, 0.0, 0.45)
	style.shadow_size = 10
	style.shadow_offset = Vector2(0, 4)
	panel.add_theme_stylebox_override("panel", style)
	
	var margin = MarginContainer.new()
	margin.mouse_filter = Control.MOUSE_FILTER_IGNORE
	margin.add_theme_constant_override("margin_left", 14)
	margin.add_theme_constant_override("margin_right", 14)
	margin.add_theme_constant_override("margin_top", 10)
	margin.add_theme_constant_override("margin_bottom", 10)
	panel.add_child(margin)
	
	var hbox = HBoxContainer.new()
	hbox.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hbox.add_theme_constant_override("separation", 12)
	margin.add_child(hbox)
	
	# App / Notification Icon Box
	var icon_box = PanelContainer.new()
	icon_box.custom_minimum_size = Vector2(44, 44)
	icon_box.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	var icon_style = StyleBoxFlat.new()
	icon_style.bg_color = Color(0.12, 0.22, 0.35, 0.9)
	icon_style.border_color = Color(0.3, 0.85, 1.0, 0.9)
	icon_style.set_border_width_all(1)
	icon_style.set_corner_radius_all(8)
	icon_box.add_theme_stylebox_override("panel", icon_style)
	
	var icon_lbl = Label.new()
	icon_lbl.text = item["icon"]
	icon_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	icon_lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	icon_lbl.add_theme_font_size_override("font_size", 22)
	icon_box.add_child(icon_lbl)
	hbox.add_child(icon_box)
	
	# Content VBox
	var vbox = VBoxContainer.new()
	vbox.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	vbox.add_theme_constant_override("separation", 3)
	
	var top_row = HBoxContainer.new()
	top_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	
	var title_lbl = Label.new()
	title_lbl.text = item["title"]
	title_lbl.add_theme_font_size_override("font_size", 11)
	title_lbl.add_theme_color_override("font_color", Color(0.3, 0.85, 1.0, 0.95))
	top_row.add_child(title_lbl)
	
	var spacer = Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top_row.add_child(spacer)
	
	var cost_lbl = Label.new()
	cost_lbl.text = item["cost"]
	cost_lbl.add_theme_font_size_override("font_size", 12)
	cost_lbl.add_theme_color_override("font_color", Color(1.0, 0.85, 0.2, 1.0))
	top_row.add_child(cost_lbl)
	vbox.add_child(top_row)
	
	var sub_lbl = Label.new()
	sub_lbl.text = item["subtitle"]
	sub_lbl.add_theme_font_size_override("font_size", 12)
	sub_lbl.add_theme_color_override("font_color", Color(0.92, 0.95, 0.98, 1.0))
	sub_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	vbox.add_child(sub_lbl)
	
	var hint_lbl = Label.new()
	hint_lbl.text = "[TAB] Marketten İncele"
	hint_lbl.add_theme_font_size_override("font_size", 10)
	hint_lbl.add_theme_color_override("font_color", Color(0.6, 0.7, 0.8, 0.8))
	vbox.add_child(hint_lbl)
	
	hbox.add_child(vbox)
	
	_notification_container.add_child(panel)
	
	# Layout Placement: Bottom-Right Anchor
	panel.anchor_left = 1.0
	panel.anchor_top = 1.0
	panel.anchor_right = 1.0
	panel.anchor_bottom = 1.0
	
	var target_x = -365.0
	var hidden_x = 20.0
	var target_y = -95.0
	
	panel.offset_left = hidden_x
	panel.offset_right = hidden_x + 345.0
	panel.offset_top = target_y
	panel.offset_bottom = target_y + 80.0
	panel.modulate.a = 0.0
	
	# Smooth phone notification pop slide animation
	if _active_tween: _active_tween.kill()
	var tw = create_tween().set_parallel(true)
	_active_tween = tw
	
	# 1. Slide In & Fade In
	tw.tween_property(panel, "offset_left", target_x, 0.35).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_property(panel, "offset_right", target_x + 345.0, 0.35).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_property(panel, "modulate:a", 1.0, 0.25)
	
	# 2. Stay visible for 4.2 seconds then Slide Out & Fade Out
	tw.chain().tween_interval(4.2)
	tw.chain().tween_property(panel, "offset_left", hidden_x, 0.35).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)
	tw.chain().tween_property(panel, "offset_right", hidden_x + 345.0, 0.35).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)
	tw.tween_property(panel, "modulate:a", 0.0, 0.30)
	
	tw.chain().tween_callback(func():
		if is_instance_valid(panel):
			panel.queue_free()
		_active_panel = null
		_is_displaying_toast = false
	)
