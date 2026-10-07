extends Node

const DURATION := 12.0
const MINIGUN_DURATION := 10.0
var special_flash_seconds := 0.0

func signal_special_pop() -> void:
	special_flash_seconds = 2.5

var coin_seconds := 0.0
var magnet_seconds := 0.0
var minigun_seconds := 0.0
var spawn_cooldown := 25.0
var status: Label

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_PAUSABLE
	status = Label.new()
	status.name = "BonusStatus"
	status.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	status.mouse_filter = Control.MOUSE_FILTER_IGNORE
	status.add_theme_color_override("font_color", Color("ffe78a"))
	status.add_theme_color_override("font_outline_color", Color("12202b"))
	status.add_theme_constant_override("outline_size", 5)
	get_parent().get_node("UI").add_child(status)
	status.set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP)
	status.offset_left = -280
	status.offset_right = 280
	status.offset_top = 52
	status.offset_bottom = 90
	refresh()

func suspended() -> bool:
	var main = get_parent()
	return main.is_loading_save or not main.game_manager.is_game_started or not main.game_manager.production_enabled or main.is_blackout or main.startup_modal.visible

var _supernova_queue: Array = []
var _supernova_timer: float = 0.0

func _process(delta: float) -> void:
	special_flash_seconds = maxf(0.0, special_flash_seconds - delta)
	if not suspended():
		coin_seconds = maxf(0, coin_seconds - delta)
		magnet_seconds = maxf(0, magnet_seconds - delta)
		if minigun_seconds > 0.0:
			minigun_seconds = maxf(0, minigun_seconds - delta)
			if minigun_seconds <= 0.0:
				_end_minigun()
		spawn_cooldown = maxf(0, spawn_cooldown - delta)
		
		# Process staggered Supernova pops without creating fragile timer closures
		if not _supernova_queue.is_empty():
			_supernova_timer += delta
			if _supernova_timer >= 0.025:
				_supernova_timer = 0.0
				var batch = 0
				while not _supernova_queue.is_empty() and batch < 8:
					batch += 1
					var b = _supernova_queue.pop_front()
					if is_instance_valid(b) and not b.is_queued_for_deletion() and not b.get("is_popped"):
						b.pop("supernova")
	refresh()

func activate(kind: String) -> void:
	var main = get_parent()
	if kind == "bonus_coin":
		coin_seconds = DURATION
		if main and main.sound_manager and main.sound_manager.has_method("play_jackpot_fanfare"):
			main.sound_manager.play_jackpot_fanfare()
		if main and main.hud_controller and main.hud_controller.has_method("trigger_jackpot_rain"):
			main.hud_controller.trigger_jackpot_rain(12, "2X GOLD FRENZY")
	elif kind == "bonus_magnet":
		magnet_seconds = DURATION
	refresh()

func activate_chroma() -> void:
	var main = get_parent()
	var event_roll = randf()
	if event_roll < 0.34:
		# 1. 2x Coin Rush (15 seconds)
		coin_seconds = 15.0
		if main.sound_manager and main.sound_manager.has_method("play_jackpot_fanfare"):
			main.sound_manager.play_jackpot_fanfare()
		if main.hud_controller and main.hud_controller.has_method("trigger_jackpot_rain"):
			main.hud_controller.trigger_jackpot_rain(15, "CHROMA 2X GOLD")
		elif main.sound_manager and main.sound_manager.has_method("play_gold_pop"):
			main.sound_manager.play_gold_pop()
	elif event_roll < 0.67:
		# 2. Supernova (Chain-pop all room balloons with staged shockwave)
		trigger_supernova()
	else:
		# Save the minigun preview for later rooms; room one teaches needle and dart.
		if main.shop_manager.current_room == "small_room":
			activate("bonus_coin")
		else:
			trigger_minigun_frenzy()
	refresh()

func trigger_supernova() -> void:
	var main = get_parent()
	if main.hud_controller and main.hud_controller.has_method("show_prompt"):
		main.hud_controller.show_prompt("💥 GİZEMLİ ETKİNLİK: SÜPERNOVA! TÜM BALONLAR PATLIYOR!", 3.5)
	if main.sound_manager and main.sound_manager.has_method("play_bomb_pop"):
		main.sound_manager.play_bomb_pop()
		
	var bc = main.balloon_container if main else null
	if not bc: return
	_supernova_queue.clear()
	_supernova_timer = 0.0
	for child in bc.get_children():
		if child is RigidBody3D and is_instance_valid(child) and not child.is_queued_for_deletion() and not child.get("is_popped"):
			_supernova_queue.append(child)
	_supernova_queue.shuffle()

func trigger_minigun_frenzy() -> void:
	var main = get_parent()
	minigun_seconds = MINIGUN_DURATION
	if main.player and main.player.has_method("set_minigun_frenzy"):
		main.player.set_minigun_frenzy(true)
	if main.hud_controller and main.hud_controller.has_method("show_prompt"):
		main.hud_controller.show_prompt("🔥 GİZEMLİ ETKİNLİK: MİNİGUN ÇILGINLIĞI (10 sn)!", 3.5)
	if main.sound_manager and main.sound_manager.has_method("play_plasma_pop"):
		main.sound_manager.play_plasma_pop()

func _end_minigun() -> void:
	var main = get_parent()
	if main.player and main.player.has_method("set_minigun_frenzy"):
		main.player.set_minigun_frenzy(false)

func multiplier() -> int:
	return 2 if coin_seconds > 0 else 1

func roll_spawn() -> String:
	if spawn_cooldown > 0 or get_tree().get_nodes_in_group("needle_bonus").size() >= 2: return ""
	# 0.6% ultra-rare chance for Rainbow Chroma Balloon
	if randf() < 0.006:
		spawn_cooldown = 35.0
		return "chroma"
	# Regular bonus chance
	if randf() >= 0.008: return ""
	spawn_cooldown = 28.0
	return "bonus_coin" if randf() < 0.5 else "bonus_magnet"

func refresh() -> void:
	var parts: PackedStringArray = []
	if coin_seconds > 0: parts.append("2× COIN KAZANCI · %d sn" % ceili(coin_seconds))
	if magnet_seconds > 0: parts.append("PARA ÇEKİMİ · %d sn" % ceili(magnet_seconds))
	if minigun_seconds > 0: parts.append("MİNİGUN ÇILGINLIĞI · %d sn" % ceili(minigun_seconds))
	var compact := get_viewport().get_visible_rect().size.x < 1100
	status.offset_top = 158 if compact else 52
	status.offset_bottom = 206 if compact else 90
	status.text = ("\n" if compact else "   |   ").join(parts)
	status.visible = not parts.is_empty()

func save_state() -> Dictionary:
	return {"coin": coin_seconds, "magnet": magnet_seconds, "minigun": minigun_seconds, "spawn": spawn_cooldown}

func restore(data: Dictionary) -> void:
	coin_seconds = clampf(float(data.get("coin", 0)), 0, 15.0)
	magnet_seconds = clampf(float(data.get("magnet", 0)), 0, DURATION)
	minigun_seconds = clampf(float(data.get("minigun", 0)), 0, MINIGUN_DURATION)
	var main = get_parent()
	if main.player and main.player.has_method("set_minigun_frenzy"):
		main.player.set_minigun_frenzy(minigun_seconds > 0)
	spawn_cooldown = clampf(float(data.get("spawn", 25)), 0, 35)
	refresh()

