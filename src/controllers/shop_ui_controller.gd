class_name ShopUIController
extends Node

signal save_requested()

const TabletView = preload("res://src/ui/tablet_shop_view.gd")
const DEVICE_MARKET_ENABLED := true
var tablet_view: RefCounted
var shop_is_open := false
var _ui_tween: Tween
var _hud_was_visible := true
var _quest_was_visible := true

var _main: Node3D = null
var shop_modal: Control = null
var shop_coins_label: Label = null
var btn_close_shop: Button = null
var upgrades_container: GridContainer = null

var btn_tier_1: Button = null
var btn_tier_2: Button = null
var btn_tier_3: Button = null
var btn_tier_all: Button = null

var btn_tab_all: Button = null
var btn_tab_upgrades: Button = null
var btn_tab_devices: Button = null
var btn_tab_rooms: Button = null
var lbl_room_device_cap: Label = null

var current_tier: int = 0
var current_filter: String = "all"
var tier_user_selected: bool = false

var shop_manager: Node = null
var game_manager: Node = null
var sound_manager: Node = null
var player: CharacterBody3D = null

func setup(main_node: Node3D) -> void:
	_main = main_node
	shop_modal = main_node.get_node_or_null("UI/ShopModal")
	shop_coins_label = main_node.get_node_or_null("UI/ShopModal/Panel/Margin/VBox/Header/CoinsLabel")
	btn_close_shop = main_node.get_node_or_null("UI/ShopModal/Panel/Margin/VBox/Header/BtnClose")
	upgrades_container = main_node.get_node_or_null("UI/ShopModal/Panel/Margin/VBox/Scroll/UpgradesGrid")
	
	btn_tier_1 = main_node.get_node_or_null("UI/ShopModal/Panel/Margin/VBox/TierTabs/BtnTier1")
	btn_tier_2 = main_node.get_node_or_null("UI/ShopModal/Panel/Margin/VBox/TierTabs/BtnTier2")
	btn_tier_3 = main_node.get_node_or_null("UI/ShopModal/Panel/Margin/VBox/TierTabs/BtnTier3")
	btn_tier_all = main_node.get_node_or_null("UI/ShopModal/Panel/Margin/VBox/TierTabs/BtnTierAll")
	
	btn_tab_all = main_node.get_node_or_null("UI/ShopModal/Panel/Margin/VBox/CategoryTabs/BtnTabAll")
	btn_tab_upgrades = main_node.get_node_or_null("UI/ShopModal/Panel/Margin/VBox/CategoryTabs/BtnTabUpgrades")
	btn_tab_devices = main_node.get_node_or_null("UI/ShopModal/Panel/Margin/VBox/CategoryTabs/BtnTabDevices")
	btn_tab_rooms = main_node.get_node_or_null("UI/ShopModal/Panel/Margin/VBox/CategoryTabs/BtnTabRooms")
	lbl_room_device_cap = main_node.get_node_or_null("UI/ShopModal/Panel/Margin/VBox/CategoryTabs/DeviceCapLabel")
	
	shop_manager = main_node.get_node_or_null("ShopManager")
	game_manager = main_node.get_node_or_null("GameManager")
	sound_manager = main_node.get_node_or_null("SoundManager")
	player = main_node.get_node_or_null("Player")
	
	# Reuse the existing card structure before the tablet styles and binds it.
	for card in upgrades_container.get_children():
		if card.has_meta("upgrade_id"):
			for extra_id in ["dart_gun", "shotgun_dart", "minigun_weapon", "companion_drone"]:
				var extra_card = card.duplicate(0)
				extra_card.name = "Card_" + extra_id
				extra_card.set_meta("upgrade_id", extra_id)
				upgrades_container.add_child(extra_card)
			break
	for card in upgrades_container.get_children():
		if card.has_meta("device_id") and str(card.get_meta("device_id")) == "spike_wall":
			for dev_id in ["fan", "magnet_pylon", "electric_wall"]:
				var dev_card = card.duplicate(0)
				dev_card.name = "Card_" + dev_id
				dev_card.set_meta("device_id", dev_id)
				upgrades_container.add_child(dev_card)
			break
	tablet_view = TabletView.new()
	tablet_view.setup(self)
	setup_shop_ui_events()
	if player and player.hands and player.hands.tablet_rig:
		player.hands.tablet_rig.presented.connect(_on_tablet_presented)
		player.hands.tablet_rig.stowed.connect(_on_tablet_stowed)
	update_all_shop_cards(true)

func setup_shop_ui_events() -> void:
	if btn_close_shop:
		btn_close_shop.pressed.connect(func(): toggle_shop_modal())
		
	if btn_tier_1:
		btn_tier_1.pressed.connect(func(): set_tier_filter(1))
	if btn_tier_2:
		btn_tier_2.pressed.connect(func(): set_tier_filter(2))
	if btn_tier_3:
		btn_tier_3.pressed.connect(func(): set_tier_filter(3))
	if btn_tier_all:
		btn_tier_all.pressed.connect(func(): set_tier_filter(0))
		
	if btn_tab_all:
		btn_tab_all.pressed.connect(func(): set_category_filter("all"))
	if btn_tab_upgrades:
		btn_tab_upgrades.pressed.connect(func(): set_category_filter("upgrades"))
	if btn_tab_devices:
		btn_tab_devices.pressed.connect(func(): set_category_filter("devices"))
	if btn_tab_rooms:
		btn_tab_rooms.pressed.connect(func(): set_category_filter("rooms"))
		
	if upgrades_container:
		for card in upgrades_container.get_children():
			var btn: Button = card.get_node_or_null("Margin/VBox/BtnBuy")
			if not btn: continue
			if card.has_meta("upgrade_id"):
				var up_id = card.get_meta("upgrade_id")
				btn.pressed.connect(func(): _on_buy_button_pressed(up_id))
			elif card.has_meta("room_id"):
				var r_id = card.get_meta("room_id")
				btn.pressed.connect(func(): _on_buy_room_pressed(r_id))
			elif card.has_meta("device_id"):
				var d_id = card.get_meta("device_id")
				btn.pressed.connect(func(): _on_buy_device_pressed(d_id))

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

func toggle_shop_modal() -> void:
	if not shop_modal:
		return
	if _ui_tween:
		_ui_tween.kill()
	if sound_manager: sound_manager.play_interaction("button", player.global_position)
	shop_is_open = not shop_is_open
	var panel: Control = shop_modal.get_node("Panel")
	var backdrop: ColorRect = shop_modal.get_node("Backdrop")
	panel.hide()
	backdrop.color = Color(0.015, 0.025, 0.035, 0.0)
	if shop_is_open:
		if not shop_modal.visible:
			_hud_was_visible = _main.get_node("UI/HUD").visible
		shop_modal.show()
		_main.get_node("UI/HUD").hide()
		if is_instance_valid(_main.get("quest_ui")):
			_quest_was_visible = _main.quest_ui.visible
			_main.quest_ui.hide()
		current_tier = 0
		update_all_shop_cards()
		player.set_ui_open(true, true)
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	else:
		# Keep input locked until both hands finish putting the tablet away.
		player.hands.set_tablet_mode(false)
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
		save_requested.emit()

func _on_tablet_presented() -> void:
	if not shop_is_open:
		return
	var panel: Control = shop_modal.get_node("Panel")
	tablet_view.layout(player.hands.tablet_rig.screen_rect())
	panel.modulate.a = 0.0
	panel.show()
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	_ui_tween = create_tween().set_parallel(true)
	_ui_tween.tween_property(panel, "modulate:a", 1.0, 0.14)
	_ui_tween.tween_property(shop_modal.get_node("Backdrop"), "color:a", 0.18, 0.14)

func _on_tablet_stowed() -> void:
	if shop_is_open:
		return
	shop_modal.hide()
	_main.get_node("UI/HUD").visible = _hud_was_visible
	if is_instance_valid(_main.get("quest_ui")):
		_main.quest_ui.visible = _quest_was_visible
	player.set_ui_open(false)
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED

var market_dirty := true
var market_refresh_elapsed := 0.0

func request_refresh() -> void:
	market_dirty = true

func _process(_delta: float) -> void:
	market_refresh_elapsed += _delta
	if shop_is_open and market_dirty and market_refresh_elapsed >= 0.1:
		update_all_shop_cards()
	if shop_is_open and tablet_view and shop_modal.get_node("Panel").visible:
		tablet_view.layout(player.hands.tablet_rig.screen_rect())

func set_tier_filter(tier_num: int) -> void:
	current_tier = tier_num
	tier_user_selected = true
	update_all_shop_cards()
	shop_modal.get_node("Panel/Margin/VBox/Scroll").scroll_vertical = 0

func set_category_filter(filter_name: String) -> void:
	if sound_manager: sound_manager.play_interaction("button", player.global_position)
	current_filter = filter_name
	if tablet_view and tablet_view.progression:
		tablet_view.progression.list_scroll.scroll_vertical = 0
		tablet_view.progression.list_scroll.scroll_horizontal = 0
	update_all_shop_cards()
	shop_modal.get_node("Panel/Margin/VBox/Scroll").scroll_vertical = 0

func get_card_tier(card: Control) -> int:
	if card.has_meta("upgrade_id"):
		return 1
	elif card.has_meta("device_id"):
		var d_id = card.get_meta("device_id")
		if d_id == "spike_wall":
			return 1
		elif d_id in ["gravity_regulator", "magnet_pylon", "electric_wall"]:
			return 2
		return 2
	elif card.has_meta("room_id"):
		var r_id = card.get_meta("room_id")
		if r_id == "small_room":
			return 1
		elif r_id == "medium_room":
			return 2
		elif r_id in ["hangar"]:
			return 3
		return 1
	return 1

func get_card_category(card: Control) -> String:
	if card.has_meta("upgrade_id"):
		return "upgrades"
	elif card.has_meta("device_id"):
		return "devices"
	elif card.has_meta("room_id"):
		return "rooms"
	return ""

func is_weapon_card(card: Control) -> bool:
	return str(card.get_meta("upgrade_id", "")) in ["auto_pop", "splash_pop", "dart_gun", "shotgun_dart", "minigun_weapon"]

func weapon_preview(id: String) -> String:
	var data: Dictionary = shop_manager.upgrades[id]
	var level: int = data.level
	if id == "auto_pop":
		return "İğneye özel • atış hızı ve otomatik kullanım\n" + shop_manager.upgrade_preview(id)
	elif id == "splash_pop":
		return "İğneye özel • aynı renk balon zinciri\n" + shop_manager.upgrade_preview(id)
	elif id == "shotgun_dart":
		var next_lvl = mini(level + 1, int(data.max_level))
		var idx = clamp(level - 1, 0, 4)
		var n_idx = clamp(next_lvl - 1, 0, 4)
		return "[3] Pompalı Dart • %d saçma • %d delme\nŞarjör %d • Doldurma %.1f sn" % [data.pellets[idx if level > 0 else n_idx], data.pierce[idx if level > 0 else n_idx], data.magazine_sizes[idx if level > 0 else n_idx], data.reload_seconds[idx if level > 0 else n_idx]]
	elif id == "minigun_weapon":
		return "[4] Kalıcı Ağır Minigun\nSaniyede 26 delip geçen mermi sıkar. Delme sınırı yok!"
	var next_level := mini(level + 1, int(data.max_level))
	var next_idx := next_level - 1
	var result := "Delme ve sekme bu seviyeye dahil\n"
	if level == 0:
		return result + "%.1f atış/sn • %d delme + %d sekme\nSekme %.1f m • Menzil %.0f m\nŞarjör %d • Doldurma %.1f sn" % [
			1.0 / float(data.intervals[next_idx]),
			data.pierce[next_idx],
			data.ricochet_targets[next_idx],
			data.ricochet_radius[next_idx],
			data.range,
			data.magazine_sizes[next_idx],
			data.reload_seconds[next_idx]
		]
	var idx := level - 1
	if level == next_level:
		return result + "%.1f atış/sn • %d delme + %d sekme\nSekme %.1f m • Menzil %.0f m\nŞarjör %d • Doldurma %.1f sn" % [
			1.0 / float(data.intervals[idx]),
			data.pierce[idx],
			data.ricochet_targets[idx],
			data.ricochet_radius[idx],
			data.range,
			data.magazine_sizes[idx],
			data.reload_seconds[idx]
		]
	return result + "Atış/sn: %.1f → %.1f • Delme: %d → %d\nSekme: %d → %d (%.1f → %.1f m) • Menzil %.0f m\nŞarjör: %d → %d • Doldurma: %.1f → %.1f sn" % [
		1.0 / float(data.intervals[idx]),
		1.0 / float(data.intervals[next_idx]),
		data.pierce[idx],
		data.pierce[next_idx],
		data.ricochet_targets[idx],
		data.ricochet_targets[next_idx],
		data.ricochet_radius[idx],
		data.ricochet_radius[next_idx],
		data.range,
		data.magazine_sizes[idx],
		data.magazine_sizes[next_idx],
		data.reload_seconds[idx],
		data.reload_seconds[next_idx]
	]

func format_level_pips(lvl: int, max_lvl: int) -> String:
	var s = ""
	for i in range(max_lvl):
		if i < lvl:
			s += "■ "
		else:
			s += "□ "
	return s.strip_edges()

func update_all_shop_cards(force: bool = false) -> void:
	if not shop_is_open and not force:
		market_dirty = true
		return
	market_dirty = false
	market_refresh_elapsed = 0.0
	if not upgrades_container or not shop_manager or not tablet_view:
		return
	var pops: int = game_manager.total_pops if game_manager else 0
	shop_coins_label.text = format_number(shop_manager.get_spendable_coin_balance()) + " COIN"
	lbl_room_device_cap.text = "%d / %d cihaz" % [shop_manager.get_total_placed_devices(), shop_manager.get_current_room_max_devices()]
	btn_tab_devices.visible = true
	tablet_view.refresh_tabs(current_filter)
	var room: Dictionary = shop_manager.get_current_room_data()
	var active_b: int = game_manager.active_balloons if game_manager else 0
	var max_b: int = max(1, game_manager.max_room_balloons if game_manager else 100)
	var pressure_pct: int = clamp(int((float(active_b) / float(max_b)) * 100.0), 0, 100)
	var room_name: String = str(room.get("name", "Laboratuvar")).split(" (")[0]
	tablet_view.footer.text = "%s  ·  %s balon patlatıldı  ·  Oda Basıncı: %%%d (%d/%d puan)     |     TAB / ESC  Kapat" % [
		room_name, format_number(pops), pressure_pct, active_b, max_b
	]
	var sorted: Array = []
	var visible_count := 0
	for card in upgrades_container.get_children():
		var category := get_card_category(card)
		if card.has_meta("device_id") and str(card.get_meta("device_id")) == "gravity_regulator":
			card.visible = false
			continue
		# In "Katalog" (all) view, only show upgrades, not rooms or devices. Rooms are viewed in "Odalar" tab.
		if current_filter == "all" and category == "rooms":
			card.visible = false
			continue
		card.visible = (current_filter == "all" or category == current_filter) and (current_tier == 0 or get_card_tier(card) == current_tier)
		if current_filter == "weapons": card.visible = is_weapon_card(card)
		elif current_filter == "upgrades" and is_weapon_card(card): card.visible = false
		if not card.visible:
			continue
		visible_count += 1
		var data: Dictionary
		var cost := 0
		var required := 0
		var meta := ""
		var action := "Satın al"
		var state := ""
		var title := ""
		var terminal := false
		var device_market_locked := false
		var device_room_locked := false
		var progression_lock := ""
		if category == "upgrades":
			var id: String = card.get_meta("upgrade_id")
			data = shop_manager.upgrades[id]
			progression_lock = shop_manager.get_upgrade_prerequisite_message(id)
			var level: int = data.level
			var room_cap: int = shop_manager.get_upgrade_room_cap(id)
			var reached_room_cap: bool = level >= room_cap
			terminal = level >= int(data.max_level) or reached_room_cap
			meta = "GELİŞTİRME  /  SEVİYE %d–%d" % [level, data.max_level]
			title = data.title
			action = "Geliştir"
			if is_weapon_card(card):
				var weapon_prefix = "İĞNE [1]"
				if id == "dart_gun": weapon_prefix = "DART [2]"
				elif id == "shotgun_dart": weapon_prefix = "POMPALI [3]"
				elif id == "minigun_weapon": weapon_prefix = "MİNİGUN [4]"
				meta = weapon_prefix + "  /  SEVİYE %d–%d" % [level, data.max_level]
				var default_title = str(data.get("title", id))
				var weapon_titles = {
					"auto_pop": "İğne: Hız ve Otomatik Atış",
					"splash_pop": "İğne: Renk Zinciri (Splash)",
					"dart_gun": "Dart Tabancası",
					"shotgun_dart": "Pompalı Dart",
					"minigun_weapon": "Ağır Minigun"
				}
				title = weapon_titles.get(id, default_title)
				if id in ["dart_gun", "shotgun_dart", "minigun_weapon"]:
					title += " • Sv. %d" % level if terminal else (" • Sv.1'i aç" if level == 0 else " • Sv.%d → Sv.%d" % [level, level + 1])
					action = "Sv.1'i al" if level == 0 else "Yükselt → Sv.%d" % (level + 1)
			if terminal:
				if level >= int(data.max_level):
					state = "Maksimum seviye"
				elif reached_room_cap:
					if shop_manager.current_room == "hangar":
						state = "Maksimum: %d boru" % shop_manager.get_pipe_limit() if id == "pipe_count" else "Maksimum seviye: %d" % room_cap
					elif id == "pipe_count":
						state = "Oda sınırı: %d boru • Daha büyük oda gerekli" % shop_manager.get_pipe_limit()
					elif room_cap == 0:
						state = "Bu odada kilitli • Sonraki odaya geç"
					else:
						state = "Oda sınırı: Sv. %d • Sonraki oda gerekli" % room_cap
				else:
					state = "Maksimum seviye"
			else:
				cost = shop_manager.get_upgrade_cost(id, level)
				required = shop_manager.get_upgrade_req_pops(id, level)
		elif category == "devices":
			var id: String = card.get_meta("device_id")
			data = shop_manager.devices[id]
			device_market_locked = not DEVICE_MARKET_ENABLED
			device_room_locked = not shop_manager.automation_available()
			progression_lock = shop_manager.get_device_prerequisite_message(id)
			var gravity: bool = id == "gravity_regulator"
			var count: int = data.level if gravity else data.count
			var maximum: int = data.max_level if gravity else mini(int(data.max_count), shop_manager.device_count_limit())
			title = data.name
			meta = ("KONTROL  /  SEVİYE %d–%d" if gravity else "OTOMASYON  /  %d–%d CİHAZ") % [count, maximum]
			terminal = count >= maximum
			action = "Geliştir" if gravity else "Kargo siparişi ver"
			if device_market_locked:
				terminal = true
				state = "Şimdilik kilitli • Cihazlar sonraki güncellemede açılacak"
			elif device_room_locked:
				terminal = true
				required = int(shop_manager.rooms.medium_room.get("unlock_pops", 15000))
				state = "Oda 2'de açılır • Odaya geçince satın alabilirsin"
			elif terminal:
				state = "Maksimum seviye" if gravity else "Cihaz sınırına ulaşıldı"
			else:
				cost = shop_manager.get_device_tech_cost(id, count) if gravity else shop_manager.get_device_unit_cost(id, count)
				required = shop_manager.get_device_tech_req_pops(id, count) if gravity else shop_manager.get_device_unit_req_pops(id, count)
				required = maxi(required, int(data.get("unlock_pops", 0)))
				if not gravity and shop_manager.get_total_placed_devices() >= shop_manager.get_current_room_max_devices():
					terminal = true
					state = "Oda kapasitesi dolu"
		else:
			var id: String = card.get_meta("room_id")
			data = shop_manager.rooms[id]
			title = data.name
			meta = "ODA  /  %d × %d m" % [data.floor_size.x, data.floor_size.y]
			required = int(data.get("unlock_pops", 0))
			cost = 0
			terminal = shop_manager.current_room == id
			if terminal:
				state = "Şu an bu odadasın"
			elif shop_manager.pending_room == id:
				terminal = true
				state = "Portal için odadaki balonları temizle" if _main.factory.waiting_for_clear else "Portal odanın ortasında • İçine girerek geç"
			else:
				state = "Eşik: %s patlatma • Ulaşınca üretim durur ve portal açılır" % format_number(required)
				action = "Eşikte otomatik geçiş"
		var locked := pops < required or device_market_locked or device_room_locked or progression_lock != ""
		var affordable: bool = shop_manager.can_afford(cost)
		if not terminal:
			if device_market_locked:
				state = "Şimdilik kilitli • Cihazlar sonraki güncellemede açılacak"
			elif device_room_locked:
				state = "Oda 2'de açılır • Odaya geçince satın alabilirsin"
			elif progression_lock != "":
				state = progression_lock
			elif locked:
				state = "%s / %s balon patlatma gerekli" % [format_number(pops), format_number(required)]
			elif not affordable:
				state = "%s coin daha gerekli" % format_number(cost - shop_manager.get_spendable_coin_balance())
			else:
				state = "Satın almaya hazır" if cost > 0 else "Kullanıma hazır"
			if is_weapon_card(card) and not locked:
				state += " • Eşik: %s patlatma" % format_number(required)
		var box: VBoxContainer = card.get_node("Margin/VBox")
		box.get_node("Meta").text = meta
		box.get_node("Title").text = title.split(" (")[0]
		box.get_node("Title").modulate = Color.WHITE
		var preview := ""
		if category == "upgrades": preview = shop_manager.upgrade_preview(str(card.get_meta("upgrade_id")))
		elif category == "devices":
			var device_id: String = card.get_meta("device_id")
			preview = shop_manager.upgrade_preview(device_id) if device_id == "gravity_regulator" else "Yeni cihaz • Sv. 1 → Kargo\n%s\nKurulu cihazı [F] ile ayrı yükselt" % shop_manager.device_output_preview(device_id, 1)
		else: preview = "%d boru • %d cihaz\n%s fiziksel • %s yük" % [data.get("max_pipes", 1), data.max_devices, format_number(data.get("physics_budget", data.capacity)), format_number(data.capacity)]
		if is_weapon_card(card): preview = weapon_preview(str(card.get_meta("upgrade_id")))
		box.get_node("Desc").text = preview
		box.get_node("Desc").tooltip_text = data.get("desc", "")
		card.tooltip_text = data.get("desc", "")
		box.get_node("Desc").modulate = Color.WHITE
		box.get_node("Status").text = state
		box.get_node("Status").modulate = TabletView.GOLD if locked or not affordable else TabletView.ACCENT
		box.get_node("Price").text = "YAKINDA" if device_market_locked else ("ODA 2" if device_room_locked else (format_number(cost) + " COIN" if cost > 0 else ("TAMAMLANDI" if terminal else "ÜCRETSİZ")))
		box.get_node("Price").add_theme_font_size_override("font_size", 13 if cost == 0 else 19)
		var buy: Button = box.get_node("BtnBuy")
		var unlock_progress: ProgressBar = box.get_node("UnlockProgress")
		unlock_progress.visible = locked and not device_market_locked and not device_room_locked and progression_lock == ""
		unlock_progress.value = minf(100.0, float(pops) / maxi(1, required) * 100.0)
		card.set_meta("progression_state", {"locked": locked, "terminal": terminal, "affordable": affordable, "cost": cost, "required": required})
		var is_room_card := category == "rooms"
		var ready_to_buy: bool = not is_room_card and not terminal and not locked and affordable
		if not card.has_meta("ready_to_buy") or card.get_meta("ready_to_buy", false) != ready_to_buy:
			card.set_meta("ready_to_buy", ready_to_buy)
			card.add_theme_stylebox_override("panel", TabletView.style(Color("182a37"), Color("367f71") if ready_to_buy else Color("2c4352"), 12))
		buy.disabled = is_room_card or terminal or locked or not affordable
		buy.text = "Kilitli" if locked else ("Tamamlandı" if terminal else action)
		if is_room_card and not terminal: buy.text = "Eşikte otomatik geçiş"
		if device_market_locked: buy.text = "Şimdilik kilitli"
		elif device_room_locked: buy.text = "Oda 2'de açılır"
		elif category == "rooms" and str(card.get_meta("room_id")) == shop_manager.pending_room: buy.text = "Odayı temizle" if _main.factory.waiting_for_clear else "Portal açık"
		var priority := (30000000 if terminal else (20000000 + required if locked else (10000000 + cost if not affordable else cost)))
		if current_filter == "weapons": priority = ["auto_pop", "splash_pop", "dart_gun"].find(str(card.get_meta("upgrade_id", "")))
		sorted.append({"node": card, "priority": priority})
	sorted.sort_custom(func(a, b): return a.priority < b.priority)
	for i in range(sorted.size()):
		if sorted[i].node.get_index() != i:
			upgrades_container.move_child(sorted[i].node, i)
	tablet_view.empty.visible = visible_count == 0 and current_filter != "facility"
	if tablet_view.progression: tablet_view.progression.refresh()

func _on_buy_button_pressed(upgrade_id: String) -> void:
	if shop_manager and game_manager:
		if shop_manager.buy_upgrade(upgrade_id, game_manager.total_pops):
			tablet_view.purchase_feedback(upgrade_id)
			if sound_manager: sound_manager.play_interaction("confirm", player.global_position)

func _on_buy_room_pressed(room_id: String) -> void:
	if shop_manager and game_manager:
		if shop_manager.buy_room(room_id, game_manager.total_pops):
			update_all_shop_cards()
			if shop_is_open: toggle_shop_modal()

func _on_buy_device_pressed(device_id: String) -> void:
	if not shop_manager or not game_manager: return
	if device_id == "gravity_regulator": return
	shop_manager.buy_device_unit(device_id, game_manager.total_pops)

func _on_buy_tech_pressed(tech_id: String) -> void:
	if not shop_manager or not game_manager: return
	shop_manager.buy_device_upgrade(tech_id, game_manager.total_pops)
