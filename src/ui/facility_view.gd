extends VBoxContainer

const View = preload("res://src/ui/tablet_shop_view.gd")
var main: Node
var cards: GridContainer
var production_status: Label
var production_details: Label
var production_button: Button
var production_hint: Label
var pressure: ProgressBar
var gravity_select: OptionButton
var gravity_hint: Label
var cargo_list: Label
var quest_status: Label
var quest_details: Label
var guide_panel: Control
var guide_status: Label
var guide_details: Label
var device_list: VBoxContainer
var device_rows: Dictionary = {}
var empty_devices: Label
var _refresh_timer := 0.0

func text(parent: Node, value: String, size: int = 13, color: Color = View.INK) -> Label:
	var label := Label.new()
	label.text = value
	label.add_theme_font_size_override("font_size", size)
	label.add_theme_color_override("font_color", color)
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	parent.add_child(label)
	return label

func card(title: String) -> VBoxContainer:
	var panel := PanelContainer.new()
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	panel.add_theme_stylebox_override("panel", View.style(Color("182a37"), Color("2c4352"), 10))
	cards.add_child(panel)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 8)
	panel.add_child(box)
	text(box, title, 12, View.ACCENT)
	return box

func setup(main_node: Node) -> void:
	main = main_node
	size_flags_horizontal = Control.SIZE_EXPAND_FILL
	add_theme_constant_override("separation", 10)
	text(self, "TESİS KONTROLÜ", 18)
	text(self, "Üretimi yönet • Yerçekimini seç • Teslimatları ve cihazları takip et", 12, View.MUTED)
	cards = GridContainer.new()
	cards.columns = 2
	cards.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	cards.add_theme_constant_override("h_separation", 10)
	cards.add_theme_constant_override("v_separation", 10)
	add_child(cards)
	var production := card("01 / ÜRETİM HATTI")
	production_status = text(production, "", 19)
	production_details = text(production, "", 12, View.MUTED)
	pressure = ProgressBar.new()
	pressure.custom_minimum_size.y = 16
	pressure.show_percentage = false
	production.add_child(pressure)
	production_button = Button.new()
	production_button.custom_minimum_size.y = 32
	production_button.pressed.connect(func(): main.factory.toggle_production(); refresh())
	production.add_child(production_button)
	production_hint = text(production, "", 12, View.GOLD)
	var gravity := card("02 / YERÇEKİMİ")
	gravity_select = OptionButton.new()
	gravity_select.custom_minimum_size.y = 32
	gravity_select.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	gravity_select.fit_to_longest_item = false
	gravity.add_child(gravity_select)
	for i in range(main.room_controller.balloon_gravity_scales.size()):
		gravity_select.add_item(main.room_controller.gravity_mode_names[i], i)
	gravity_select.item_selected.connect(select_gravity)
	gravity_hint = text(gravity, "", 12, View.MUTED)
	text(gravity, "0.25 G balonları uzun süre havada tutar. 6.00 G daha hızlı düşürerek zemin cihazlarını daha sık besler.", 12)
	var cargo := card("03 / KARGO TAKİBİ")
	cargo_list = text(cargo, "", 13)
	text(cargo, "Üretimi durdur → servis kapısından çık → kargoyu al → içeride E ile aç.", 12, View.MUTED)
	var quest := card("04 / AKTİF GÖREV")
	quest_status = text(quest, "", 16)
	quest_details = text(quest, "", 12, View.MUTED)
	var guide := card("05 / OTOMASYON KURULUM REHBERİ")
	guide_panel = cards.get_child(cards.get_child_count() - 1)
	guide_status = text(guide, "", 16)
	guide_details = text(guide, "", 12, View.MUTED)
	text(self, "CİHAZLAR / SON 10 SANİYE", 14, View.ACCENT)
	text(self, "Patlatma sayısı cihazın gerçek çıktısıdır. Mıknatısta çekilen farklı balonlar gösterilir; değerler birbirine eklenmez.", 12, View.MUTED)
	device_list = VBoxContainer.new()
	device_list.add_theme_constant_override("separation", 6)
	add_child(device_list)
	empty_devices = text(device_list, "Henüz kurulu cihaz yok. Otomasyon ekipmanları sonraki geliştirme paketinde açılacak.", 13)
	refresh()

func select_gravity(index: int) -> void:
	var unlocked: int = main.room_controller.balloon_gravity_scales.size() - 1
	if index < 0 or index > unlocked or index >= main.room_controller.balloon_gravity_scales.size():
		refresh()
		return
	main.room_controller.current_gravity_idx = index
	main.room_controller.apply_gravity_to_active_balloons()
	main.room_controller.gravity_mode_changed.emit(index, main.room_controller.get_current_gravity_name(), main.room_controller.get_current_gravity_scale())
	main.save_current_data()
	refresh()

func _process(delta: float) -> void:
	if not is_visible_in_tree(): return
	_refresh_timer += delta
	if _refresh_timer < 0.4: return
	_refresh_timer = 0.0
	refresh()

func refresh() -> void:
	if not main or not cards: return
	cards.columns = 1 if size.x > 0 and size.x < 560 else 2
	var gm = main.game_manager
	var factory = main.factory
	var running: bool = gm.production_enabled
	production_status.text = "ÜRETİM AÇIK" if running else "ÜRETİM DURDU"
	production_status.modulate = View.ACCENT if running else View.GOLD
	var capacity: int = maxi(1, gm.max_room_balloons)
	var physical_count: int = gm.get_physical_balloon_count()
	var physics_budget: int = gm.get_physics_budget()
	pressure.value = float(physical_count) / float(maxi(1, physics_budget)) * 100.0
	production_details.text = "Üretim kapasitesi: %.2f balon/sn • Gerçek (10 sn): %.2f\nSon 60 sn: %d balon patlatıldı\nBalon yükü: %d / %d birim\nBasınç: %d / %d gerçek balon" % [gm.get_effective_balloons_per_second(), gm.get_actual_spawn_rate(), gm.last_minute_pops, gm.active_balloons, capacity, physical_count, physics_budget]
	production_button.text = "Üretimi durdur" if running else "Üretimi başlat"
	var blocked: bool = factory.door_open or factory.door_moving or main.player.position.z > factory.half_length - 0.6
	production_button.disabled = (not running and blocked) or factory.requires_wall_start or main.shop_manager.pending_room != ""
	production_hint.text = "Başlatmak için içeri gir ve servis kapısını kapat." if not running and blocked else ("Servis kapısı üretim açıkken kilitlidir." if running else "Borular kapalı. Görev süresi bekliyor.")
	if main.shop_manager.pending_room != "":
		production_hint.text = "Portal için kalan %d balonu temizle." % gm.get_physical_balloon_count() if factory.waiting_for_clear else "Üretim geçiş için durduruldu. Odanın ortasındaki portala gir."
	elif factory.requires_wall_start:
		production_hint.text = "Üretimi kapı yanındaki BAŞLAT düğmesinden çalıştır."
	if running and float(physical_count) / float(maxi(1, physics_budget)) >= 0.75:
		production_hint.text = "Oda kalabalık (%d/%d). Balonları temizledikçe üretim yeniden hızlanır." % [physical_count, physics_budget]
		if physical_count >= physics_budget:
			production_hint.text = "Oda dolu (%d/%d). Yeni balonlar için yer aç." % [physical_count, physics_budget]
	for i in range(gravity_select.item_count):
		gravity_select.set_item_disabled(i, false)
		gravity_select.set_item_text(i, main.room_controller.gravity_mode_names[i])
	gravity_select.select(main.room_controller.current_gravity_idx)
	gravity_hint.text = "Bütün modlar açık. Düşük yerçekimi balonları uzun süre havada tutar; yüksek yerçekimi zemin cihazlarını daha sık besler."
	var cargo_lines: Array[String] = []
	var grouped := {}
	for order in factory.orders:
		var id: String = order.id
		grouped[id] = int(grouped.get(id, 0)) + 1
	for id in grouped:
		cargo_lines.append("%s ×%d • Teslimat alanında" % [device_name(id), grouped[id]])
	if not factory.held.is_empty(): cargo_lines.append(device_name(factory.held.id) + " • Elindeki pakette")
	var carried = main.device_placement.carried_device
	if is_instance_valid(carried) and carried.has_meta("cargo_order"):
		cargo_lines.append(device_name(str(carried.get_meta("device_type"))) + " • Yerleştirilmeyi bekliyor")
	cargo_list.text = "\n".join(cargo_lines) if not cargo_lines.is_empty() else "Bekleyen teslimat yok."
	var qm = main.quest_manager
	if qm.is_active:
		quest_status.text = qm.quest_title
		quest_details.text = "%s\n%d / %d • %d sn • %d coin\n%s" % [qm.quest_desc, qm.current_progress, qm.current_target, ceili(qm.time_left), qm.current_reward, "Üretim durdu: süre bekliyor" if qm.is_suspended() else "Görev devam ediyor"]
	else:
		quest_status.text = "YENİ GÖREV BEKLENİYOR"
		quest_details.text = "Sıradaki göreve %d sn. Görevler odana ve açtığın yeteneklere göre seçilir." % maxi(0, ceili(qm.cooldown_timer))
	var guide_data: Dictionary = qm.get_automation_guide_data()
	guide_panel.visible = bool(guide_data.get("visible", false))
	guide_status.text = str(guide_data.get("status", ""))
	guide_details.text = str(guide_data.get("details", ""))
	var ids: Array[int] = []
	for dev in main.active_placed_devices:
		if not is_instance_valid(dev) or dev.is_queued_for_deletion(): continue
		var id: int = dev.get_instance_id()
		ids.append(id)
		if not device_rows.has(id):
			device_rows[id] = text(device_list, "", 13)
		var kind: String = dev.get_meta("device_type", "")
		var status := "Taşınıyor" if dev == carried else "Çalışıyor"
		var result := "Veri bekleniyor"
		if "feedback" in dev and is_instance_valid(dev.feedback):
			result = "%d farklı balon yönlendirildi" % dev.feedback.recent_contacts.size() if kind in ["magnet_pylon", "fan"] else "%d patlatma" % dev.feedback.last_output()
			if dev != carried and result.begins_with("0 "): status = "Balon bekliyor"
		device_rows[id].text = "%s • Sv.%d • %s\n%s" % [device_name(kind), dev.level, status, result]
	for id in device_rows.keys():
		if not ids.has(id):
			device_rows[id].queue_free()
			device_rows.erase(id)
	empty_devices.visible = ids.is_empty()
	empty_devices.text = "Henüz kurulu cihaz yok. Otomasyon sekmesinden sipariş ver." if main.shop_manager.automation_available() else "Otomasyon Üretim Tesisi’nde açılır."

func device_name(id: String) -> String:
	return str(main.shop_manager.devices.get(id, {}).get("name", id)).split(" (")[0]
