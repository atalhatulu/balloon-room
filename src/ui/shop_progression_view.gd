extends RefCounted

const GOLD := Color("efc379")
const INK := Color("e6eff4")
const MUTED := Color("90a8b8")

static func style(background: Color, border: Color, radius: int) -> StyleBoxFlat:
	var box := StyleBoxFlat.new()
	box.bg_color = background
	box.border_color = border
	box.set_border_width_all(2)
	box.set_corner_radius_all(radius)
	return box

var shop: Node
var body: BoxContainer
var detail_panel: PanelContainer
var detail_scroll: ScrollContainer
var list_scroll: ScrollContainer
var rows: VBoxContainer
var details: VBoxContainer
var title: Label
var description: Label
var status: Label
var last_purchase: Dictionary = {}
var purchase_notice: Label
var entries: Array[Dictionary] = []
var selected: Dictionary = {}
var preview: Dictionary = {}

func setup(controller: Node, content: VBoxContainer) -> void:
	shop = controller
	body = BoxContainer.new()
	body.name = "ProgressionMarket"
	body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	body.add_theme_constant_override("separation", 14)
	content.add_child(body)
	content.move_child(body, content.get_node("Scroll").get_index())
	var scroll := ScrollContainer.new()
	list_scroll = scroll
	scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.size_flags_stretch_ratio = 1.8
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	body.add_child(scroll)
	rows = VBoxContainer.new()
	rows.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	rows.add_theme_constant_override("separation", 18)
	scroll.add_child(rows)
	detail_panel = PanelContainer.new()
	detail_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var panel_style := style(Color("162835"), Color("355363"), 12)
	panel_style.content_margin_left = 16
	panel_style.content_margin_right = 16
	panel_style.content_margin_top = 18
	panel_style.content_margin_bottom = 18
	detail_panel.add_theme_stylebox_override("panel", panel_style)
	body.add_child(detail_panel)
	detail_scroll = ScrollContainer.new()
	detail_scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	detail_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	detail_scroll.custom_minimum_size.x = 200
	detail_panel.add_child(detail_scroll)
	details = VBoxContainer.new()
	details.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	details.add_theme_constant_override("separation", 14)
	detail_scroll.add_child(details)
	title = _label(20)
	description = _label(15)
	status = _label(15)
	status.add_theme_color_override("font_color", Color.WHITE)
	purchase_notice = _label(14)
	purchase_notice.add_theme_color_override("font_color", Color("78e4bd"))
	for card in shop.upgrades_container.get_children():
		var category: String = shop.get_card_category(card)
		var id: String = str(card.get_meta("upgrade_id", card.get_meta("device_id", card.get_meta("room_id", ""))))
		var count := 1
		if category == "upgrades": count = int(shop.shop_manager.upgrades[id].max_level)
		var row := PanelContainer.new()
		var row_style := style(Color("14232f"), Color("2b4353"), 10)
		row_style.content_margin_left = 12
		row_style.content_margin_right = 12
		row_style.content_margin_top = 10
		row_style.content_margin_bottom = 12
		row.add_theme_stylebox_override("panel", row_style)
		rows.add_child(row)
		var row_content := VBoxContainer.new()
		row_content.add_theme_constant_override("separation", 9)
		row.add_child(row_content)
		var caption := Label.new()
		caption.add_theme_font_size_override("font_size", 15)
		row_content.add_child(caption)
		var chain := HBoxContainer.new()
		chain.add_theme_constant_override("separation", 5)
		row_content.add_child(chain)
		var entry := {"card": card, "row": row, "caption": caption, "id": id, "category": category, "buttons": [], "links": []}
		for index in range(count):
			if index > 0:
				var link := Label.new()
				link.text = "—"
				link.modulate = MUTED
				chain.add_child(link)
				entry.links.append(link)
			var button := Button.new()
			button.custom_minimum_size = Vector2(88, 104)
			button.alignment = HORIZONTAL_ALIGNMENT_CENTER
			button.add_theme_font_size_override("font_size", 13)
			chain.add_child(button)
			var icon := preload("res://src/ui/shop_category_icon.gd").new()
			icon.category = category
			icon.item_id = id
			icon.position = Vector2(23, 7)
			icon.size = Vector2(42, 38)
			icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
			button.add_child(icon)
			var price := Label.new()
			price.name = "Price"
			price.mouse_filter = Control.MOUSE_FILTER_IGNORE
			price.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			price.add_theme_font_size_override("font_size", 12)
			button.add_child(price)
			price.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
			price.offset_top = -25
			price.offset_bottom = -5
			var choice := {"entry": entry, "level": index + 1}
			button.mouse_entered.connect(func(): preview = choice; _show(choice))
			button.focus_entered.connect(func(): selected = choice; _show(choice))
			button.mouse_exited.connect(func(): preview = {}; _show(selected))
			button.pressed.connect(func(): _purchase(choice))
			entry.buttons.append(button)
		entries.append(entry)
	_show({})

func _label(font_size: int) -> Label:
	var label := Label.new()
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.add_theme_font_size_override("font_size", font_size)
	details.add_child(label)
	return label

func _level(entry: Dictionary) -> int:
	if entry.category == "upgrades": return int(shop.shop_manager.upgrades[entry.id].level)
	if entry.category == "rooms": return 1 if shop.shop_manager.is_room_unlocked(entry.id) else 0
	return 0 # Repeatable device purchases are not consumed level nodes.

func _state(entry: Dictionary, level: int) -> String:
	var owned := _level(entry)
	if entry.category == "rooms": return "owned" if owned > 0 else "revealed"
	if entry.category != "devices" and level <= owned: return "owned"
	if entry.category == "upgrades" and level != owned + 1: return "hidden"
	var state: Dictionary = entry.card.get_meta("progression_state", {})
	if state.is_empty(): return "hidden"
	if bool(state.get("locked", true)):
		# Owning the preceding tier reveals the next tier without bypassing its gate.
		if entry.category == "upgrades" and owned > 0 and level == owned + 1: return "revealed"
		return "hidden"
	if bool(state.get("terminal", false)): return "full"
	return "ready" if bool(state.get("affordable", false)) else "poor"

func _name(entry: Dictionary) -> String:
	if entry.category == "upgrades": return str(shop.shop_manager.upgrades[entry.id].title).split(" (")[0]
	return entry.card.get_node("Margin/VBox/Title").text

func refresh() -> void:
	body.visible = shop.current_filter != "facility"
	for entry in entries:
		entry.row.visible = entry.card.visible
		if not entry.row.visible: continue
		var owned_lvl := _level(entry)
		# Tamamen son seviyeye ulaşmış geliştirmelerin karmaşık görüntü yaratmaması için gizle
		if entry.category == "upgrades":
			var max_lvl := int(shop.shop_manager.upgrades[entry.id].max_level)
			var room_cap := int(shop.shop_manager.get_upgrade_room_cap(entry.id))
			if owned_lvl >= max_lvl or (room_cap > 0 and owned_lvl >= room_cap):
				entry.row.hide()
				continue

		var first_state := _state(entry, 1)
		if first_state == "hidden" and owned_lvl == 0:
			entry.row.hide()
			continue
		entry.caption.text = "Keşfedilmemiş geliştirme" if first_state == "hidden" else _name(entry)
		if entry.category == "devices" and first_state != "hidden":
			entry.caption.text += " • %d adet" % int(shop.shop_manager.devices[entry.id].count)
		var total_buttons: int = entry.buttons.size()
		# Dinamik pencereleme: En fazla 5 seviye kutusu gösterilir.
		# Hedef: 1 kilitli (owned_lvl + 2), 1 mevcut/alınabilir (owned_lvl + 1), ve en son alınan 3 seviye.
		var current_target_idx := owned_lvl # 0-indexed: bir sonraki seviyenin indeksi
		var start_idx := maxi(0, current_target_idx - 3)
		var end_idx := mini(total_buttons - 1, current_target_idx + 1)
		# Eğer sonlardaysak geriye doğru 5 kutuyu doldur
		if (end_idx - start_idx + 1) < 5:
			start_idx = maxi(0, end_idx - 4)

		for i in range(total_buttons):
			var button: Button = entry.buttons[i]
			var state := _state(entry, i + 1)
			var in_window := (i >= start_idx and i <= end_idx)
			button.visible = in_window and (state != "hidden")
			if i > 0:
				var prev_btn: Button = entry.buttons[i - 1]
				entry.links[i - 1].visible = button.visible and prev_btn.visible
			if not button.visible: continue
			var latest: bool = not last_purchase.is_empty() and last_purchase.id == entry.id and int(last_purchase.level) == i + 1
			var border: Color = {"ready": Color("50dc9b"), "poor": Color("f2a24b"), "owned": Color("4b8296"), "hidden": Color("344351"), "full": MUTED, "revealed": MUTED}[state]
			var background: Color = {"ready": Color("16392e"), "poor": Color("3a2a1b"), "owned": Color("253e51"), "hidden": Color("121c27"), "full": Color("202d37"), "revealed": Color("202d37")}[state]
			var style_key := "%s:%s" % [state, latest]
			if button.get_meta("style_key", "") != style_key:
				button.set_meta("style_key", style_key)
				button.add_theme_stylebox_override("normal", style(background, border, 7))
				button.add_theme_stylebox_override("hover", style(background.lightened(0.12), border, 7))
				button.add_theme_stylebox_override("pressed", style(background.darkened(0.15), border, 7))
				button.add_theme_stylebox_override("focus", style(Color.TRANSPARENT, Color.WHITE, 7))
				button.add_theme_color_override("font_color", border)
				button.add_theme_color_override("font_hover_color", border.lightened(0.15))
				button.add_theme_font_size_override("font_size", 30 if state == "hidden" else 13)
				button.get_child(0).visible = state != "hidden"
			button.modulate = Color.WHITE
			var marker := "SON ✓" if latest else "ALINDI ✓"
			button.text = "?" if state == "hidden" else "\n\n" + (marker if state == "owned" else ("+1 ADET" if entry.category == "devices" else ("SV. %d · KİLİT" % (i + 1) if state == "revealed" else "SV. %d" % (i + 1))))
			var price: Label = button.get_node("Price")
			var card_state: Dictionary = entry.card.get_meta("progression_state", {})
			price.text = shop.format_number(int(card_state.get("cost", 0))) + " COIN" if state in ["ready", "poor"] else ("HEDEF " + shop.format_number(int(card_state.get("required", 0))) if state == "revealed" else "")
			price.modulate = border
			if entry.category == "rooms":
				button.text = "\n\n" + ("BURADASIN" if shop.shop_manager.current_room == entry.id else ("AÇILDI ✓" if state == "owned" else "SONRAKİ"))
				price.text = shop.format_number(int(shop.shop_manager.rooms[entry.id].unlock_pops)) + " PATLATMA"
			button.tooltip_text = "Henüz keşfedilmedi" if state == "hidden" else _name(entry)
			button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND if state == "ready" else Control.CURSOR_ARROW
	if not selected.is_empty() and not selected.entry.row.visible: selected = {}
	if not preview.is_empty() and not preview.entry.row.visible: preview = {}
	_show(preview if not preview.is_empty() else selected)

func _show(choice: Dictionary) -> void:
	if choice.is_empty():
		title.text = "GELİŞTİRMELER"
		description.text = "Yeşil ikona tıklayarak satın al.\n\nYeşil • Satın alınabilir\nTuruncu • Coin yetersiz\nMavi / ✓ • Satın alındı"
		status.text = "Yeni geliştirmeler ilerledikçe görünür."
		status.modulate = MUTED
		return
	var entry: Dictionary = choice.entry
	var level: int = choice.level
	var state := _state(entry, level)
	var box: VBoxContainer = entry.card.get_node("Margin/VBox")
	if entry.category == "rooms":
		title.text = _name(entry)
		description.text = box.get_node("Desc").text + "\n\nEşiğe ulaşınca üretim durur. Balonları temizle, portaldan geç ve yeni odada üretimi başlat."
		status.text = "Şu an bu odadasın" if shop.shop_manager.current_room == entry.id else ("Oda açıldı" if state == "owned" else "Hedef: %s patlatma" % shop.format_number(int(shop.shop_manager.rooms[entry.id].unlock_pops)))
		status.modulate = MUTED
		return
	if state == "hidden":
		title.text = "?  KEŞFEDİLMEDİ"
		description.text = "İlerle, yeni geliştirmeleri keşfet."
		status.text = "Önce bir önceki seviyeyi satın al." if entry.category == "upgrades" and level > _level(entry) + 1 else "Patlatma hedefini ve önceki geliştirmeleri tamamla."
		status.modulate = MUTED
		return
	title.text = _name(entry) + ("\nSEVİYE %d" % level if entry.category == "upgrades" else "")
	description.text = entry.card.tooltip_text
	if state == "owned":
		status.text = "✓ Satın alındı"
		status.modulate = Color("8bb9d1")
		return
	description.text += "\n\n" + box.get_node("Desc").text
	status.text = box.get_node("Status").text + "\n" + box.get_node("Price").text
	status.modulate = MUTED if state == "revealed" else (Color("50dc9b") if state == "ready" else Color("f2a24b"))
	if state == "ready": status.text += "\nSatın almak için ikona tıkla."

func _purchase(choice: Dictionary) -> void:
	selected = choice
	preview = {}
	# Re-evaluate live coins and prerequisites before every click.
	shop.update_all_shop_cards()
	var entry: Dictionary = choice.entry
	var level: int = choice.level
	if _state(entry, level) != "ready":
		_show(choice)
		return
	var before := _level(entry)
	if entry.category == "devices": before = int(shop.shop_manager.devices[entry.id].count)
	var actual: Button = entry.card.get_node("Margin/VBox/BtnBuy")
	if actual.disabled: return
	actual.pressed.emit()
	var after := _level(entry)
	if entry.category == "devices": after = int(shop.shop_manager.devices[entry.id].count)
	if after > before:
		last_purchase = {"id": entry.id, "level": level}
		purchase_notice.text = "SON ALINAN\n" + _name(entry) + (" • Sv. %d" % level if entry.category == "upgrades" else "")
	shop.update_all_shop_cards()
	refresh()

func set_compact(compact: bool) -> void:
	body.vertical = compact
	detail_scroll.custom_minimum_size = Vector2(0, 130) if compact else Vector2(220, 0)
