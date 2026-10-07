extends RefCounted

const INK := Color("e6eff4")
const MUTED := Color("90a8b8")
const ACCENT := Color("5bdec2")
const GOLD := Color("efc379")
var panel: PanelContainer
var grid: GridContainer
var footer: Label
var empty: Label
var controller: Node
var _last_layout := Rect2()
var feedback_tweens: Dictionary = {}
var facility_tab: Button
var weapons_tab: Button
var facility_scroll: ScrollContainer
var progression: RefCounted
var facility: VBoxContainer

static func style(color: Color, border: Color = Color.TRANSPARENT, radius: int = 8) -> StyleBoxFlat:
	var box := StyleBoxFlat.new()
	box.bg_color = color
	box.border_color = border
	box.set_border_width_all(1)
	box.set_corner_radius_all(radius)
	box.content_margin_left = 14
	box.content_margin_right = 14
	box.content_margin_top = 9
	box.content_margin_bottom = 9
	return box

func setup(shop: Node) -> void:
	controller = shop
	panel = shop.shop_modal.get_node("Panel")
	grid = shop.upgrades_container
	panel.custom_minimum_size = Vector2.ZERO
	panel.set_anchors_preset(Control.PRESET_TOP_LEFT)
	panel.add_theme_stylebox_override("panel", style(Color("0c1722"), Color("426272"), 14))
	var theme := Theme.new()
	theme.default_font_size = 14
	theme.set_color("font_color", "Label", INK)
	for state in ["normal", "hover", "pressed", "disabled", "focus"]:
		var bg := Color("223744")
		if state == "hover": bg = Color("304f5b")
		if state == "pressed": bg = Color("1a5a55")
		if state == "disabled": bg = Color("1b2935")
		theme.set_stylebox(state, "Button", style(bg, ACCENT if state == "focus" else Color("35515e"), 6))
	theme.set_color("font_color", "Button", INK)
	theme.set_color("font_hover_color", "Button", Color.WHITE)
	theme.set_color("font_disabled_color", "Button", MUTED)
	theme.set_stylebox("scroll", "VScrollBar", style(Color("152630"), Color.TRANSPARENT, 3))
	theme.set_stylebox("grabber", "VScrollBar", style(Color("476675"), Color.TRANSPARENT, 3))
	panel.theme = theme
	var panel_style = panel.get_theme_stylebox("panel")
	for side in ["left", "right", "top", "bottom"]:
		panel_style.set("content_margin_" + side, 0.0)
	var margin: MarginContainer = panel.get_node("Margin")
	for side in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 12)
	var content: VBoxContainer = margin.get_node("VBox")
	content.add_theme_constant_override("separation", 8)
	var title: Label = content.get_node("Header/Title")
	title.text = "TESİS TABLETİ"
	title.add_theme_font_size_override("font_size", 18)
	title.add_theme_color_override("font_color", INK)
	shop.shop_coins_label.add_theme_color_override("font_color", GOLD)
	shop.shop_coins_label.add_theme_font_size_override("font_size", 16)
	shop.btn_close_shop.text = "Kapat ×"
	shop.btn_close_shop.custom_minimum_size = Vector2(72, 28)
	content.get_node("TierTabs").hide()
	for button in [shop.btn_tab_all, shop.btn_tab_upgrades, shop.btn_tab_devices, shop.btn_tab_rooms]:
		button.custom_minimum_size = Vector2(0, 34)
		button.add_theme_font_size_override("font_size", 12)
		button.toggle_mode = true
	shop.btn_tab_all.text = "Katalog"
	shop.btn_tab_upgrades.text = "Geliştirmeler"
	shop.btn_tab_upgrades.hide() # General upgrades remain in Katalog.
	shop.btn_tab_devices.text = "Otomasyon"
	shop.btn_tab_devices.visible = true
	shop.btn_tab_rooms.text = "Odalar"
	weapons_tab = Button.new()
	weapons_tab.name = "BtnWeapons"
	weapons_tab.text = "Silahlar"
	weapons_tab.toggle_mode = true
	weapons_tab.custom_minimum_size.y = 34
	weapons_tab.add_theme_font_size_override("font_size", 12)
	content.get_node("CategoryTabs").add_child(weapons_tab)
	content.get_node("CategoryTabs").move_child(weapons_tab, 2)
	weapons_tab.pressed.connect(func(): controller.set_category_filter("weapons"))
	shop.lbl_room_device_cap.hide()
	facility_tab = Button.new()
	facility_tab.name = "BtnFacility"
	facility_tab.text = "Tesis"
	facility_tab.toggle_mode = true
	facility_tab.custom_minimum_size.y = 34
	facility_tab.add_theme_font_size_override("font_size", 12)
	content.get_node("CategoryTabs").add_child(facility_tab)
	content.get_node("CategoryTabs").move_child(facility_tab, 0)
	facility_tab.pressed.connect(func(): controller.set_category_filter("facility"))
	facility_scroll = ScrollContainer.new()
	facility_scroll.name = "FacilityScroll"
	facility_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	facility_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	facility_scroll.custom_minimum_size.y = 80
	content.add_child(facility_scroll)
	content.move_child(facility_scroll, content.get_node("Scroll").get_index() + 1)
	facility = preload("res://src/ui/facility_view.gd").new()
	facility_scroll.add_child(facility)
	facility.setup(shop._main)
	facility_scroll.hide()
	var scroll: ScrollContainer = content.get_node("Scroll")
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.custom_minimum_size.y = 80
	grid.size_flags_vertical = Control.SIZE_EXPAND_FILL
	grid.add_theme_constant_override("h_separation", 8)
	grid.add_theme_constant_override("v_separation", 8)
	for card in grid.get_children():
		card.add_theme_stylebox_override("panel", style(Color("182a37"), Color("2c4352"), 12))
		var box: VBoxContainer = card.get_node("Margin/VBox")
		box.add_theme_constant_override("separation", 6)
		box.alignment = BoxContainer.ALIGNMENT_CENTER
		
		var icon = preload("res://src/ui/shop_category_icon.gd").new()
		icon.category = shop.get_card_category(card)
		icon.name = "Icon"
		icon.custom_minimum_size = Vector2(42, 42)
		icon.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		box.add_child(icon)
		box.move_child(icon, 0)
		
		var meta := Label.new()
		meta.name = "Meta"
		meta.add_theme_font_size_override("font_size", 10)
		meta.add_theme_color_override("font_color", MUTED)
		meta.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		box.add_child(meta)
		box.move_child(meta, 1)
		
		var title_label: Label = box.get_node("Title")
		title_label.add_theme_font_size_override("font_size", 13)
		title_label.add_theme_color_override("font_color", INK)
		title_label.custom_minimum_size.y = 18
		title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		title_label.max_lines_visible = 1
		title_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		if shop.is_weapon_card(card):
			title_label.max_lines_visible = 3
			title_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			title_label.text_overrun_behavior = TextServer.OVERRUN_NO_TRIMMING
		box.move_child(title_label, 2)
		
		var desc: Label = box.get_node("Desc")
		desc.show()
		desc.add_theme_font_size_override("font_size", 11)
		desc.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		desc.max_lines_visible = 2
		if shop.is_weapon_card(card):
			desc.max_lines_visible = -1
			desc.custom_minimum_size.y = 100 if str(card.get_meta("upgrade_id", "")) == "dart_gun" else 60
		box.move_child(desc, 3)
		
		var status := Label.new()
		status.name = "Status"
		status.add_theme_font_size_override("font_size", 10)
		status.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		box.add_child(status)
		box.move_child(status, 4)
		
		var cost := Label.new()
		cost.name = "Price"
		cost.add_theme_font_size_override("font_size", 15)
		cost.add_theme_color_override("font_color", GOLD)
		cost.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		box.add_child(cost)
		box.move_child(cost, 5)
		
		var buy: Button = box.get_node("BtnBuy")
		buy.custom_minimum_size.y = 26
		buy.add_theme_font_size_override("font_size", 12)
		buy.add_theme_stylebox_override("normal", style(Color("235d55"), Color("367e6d"), 6))
		buy.add_theme_stylebox_override("hover", style(Color("307767"), ACCENT, 6))
		box.move_child(buy, 6)
		var progress := ProgressBar.new()
		progress.name = "UnlockProgress"
		progress.custom_minimum_size.y = 4
		progress.show_percentage = false
		progress.mouse_filter = Control.MOUSE_FILTER_IGNORE
		progress.add_theme_stylebox_override("background", style(Color("253b47"), Color.TRANSPARENT, 2))
		progress.add_theme_stylebox_override("fill", style(ACCENT, Color.TRANSPARENT, 2))
		box.add_child(progress)
		card.mouse_entered.connect(func(): card.self_modulate = Color(1.12, 1.12, 1.12))
		card.mouse_exited.connect(func(): card.self_modulate = Color.WHITE)
	footer = Label.new()
	footer.name = "TabletStatus"
	footer.add_theme_font_size_override("font_size", 11)
	footer.add_theme_color_override("font_color", MUTED)
	footer.clip_text = true
	footer.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	content.add_child(footer)
	empty = Label.new()
	empty.text = "Bu kategoride seçili aşamaya uygun ürün yok."
	empty.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	empty.hide()
	content.add_child(empty)
	content.move_child(empty, content.get_child_count() - 2)

	progression = preload("res://src/ui/shop_progression_view.gd").new()
	progression.setup(shop, content)
	content.get_node("Scroll").hide()

func layout(rect: Rect2) -> void:
	if rect.is_equal_approx(_last_layout):
		return
	_last_layout = rect
	panel.position = rect.position
	panel.size = rect.size
	grid.columns = 4 if rect.size.x >= 940 else (3 if rect.size.x >= 640 else 2)
	var width := maxf(120.0, (rect.size.x - 60.0 - (grid.columns - 1) * 8.0) / grid.columns)
	for card in grid.get_children():
		card.custom_minimum_size = Vector2(width, maxf(width, 300.0) if controller.is_weapon_card(card) else width)
	controller.lbl_room_device_cap.visible = rect.size.x > 780
	var compact := rect.size.x < 760
	if progression: progression.set_compact(compact)
	panel.get_node("Margin/VBox/Header/Title").add_theme_font_size_override("font_size", 16 if compact else 18)
	controller.shop_coins_label.add_theme_font_size_override("font_size", 14 if compact else 16)

func refresh_tabs(category: String) -> void:
	facility_scroll.visible = category == "facility"
	panel.get_node("Margin/VBox/Scroll").hide()
	if progression: progression.body.visible = category != "facility"
	if category == "facility": facility.refresh()
	var tabs := {"facility": facility_tab, "weapons": weapons_tab, "all": controller.btn_tab_all, "upgrades": controller.btn_tab_upgrades, "devices": controller.btn_tab_devices, "rooms": controller.btn_tab_rooms}
	for key in tabs:
		tabs[key].set_pressed_no_signal(category == key)
		tabs[key].modulate = Color.WHITE
	var room_ready := false
	var pops: int = controller.game_manager.total_pops if controller.game_manager else 0
	for room_id in controller.shop_manager.rooms:
		if controller.shop_manager.is_room_unlocked(room_id): continue
		room_ready = pops >= int(controller.shop_manager.rooms[room_id].get("unlock_pops", 0))
		break
	if room_ready:
		controller.btn_tab_rooms.text = "Odalar • YENİ"
		controller.btn_tab_rooms.modulate = GOLD
		controller.btn_tab_rooms.tooltip_text = "Patlatma eşiği tamamlandı. Üretim durur ve oda temizlenince portal açılır."
	else:
		controller.btn_tab_rooms.text = "Odalar"
		controller.btn_tab_rooms.tooltip_text = "Oda ilerlemesini görüntüle"

func purchase_feedback(upgrade_id: String) -> void:
	for card in grid.get_children():
		if str(card.get_meta("upgrade_id", "")) != upgrade_id: continue
		if feedback_tweens.has(upgrade_id):
			var previous: Tween = feedback_tweens[upgrade_id]
			if previous and previous.is_valid(): previous.kill()
		card.modulate = Color(0.62, 1.0, 0.85)
		var tween := card.create_tween()
		feedback_tweens[upgrade_id] = tween
		tween.tween_property(card, "modulate", Color.WHITE, 0.45).set_trans(Tween.TRANS_SINE)
		return
