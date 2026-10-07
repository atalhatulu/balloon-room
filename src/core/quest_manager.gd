extends Node

signal quest_started(title: String, desc: String, target: int, duration: float, reward: int)
signal quest_progress_updated(current: int, target: int)
signal quest_completed(reward: int)
signal quest_failed()
signal state_reset()
signal automation_guide_updated()

const TYPES := ["total_pops", "tier_pops", "combo_chain", "pressure_hold"]
const COMBO_GAP := 1.5
var is_active := false
var quest_type := "total_pops"
var current_target := 0
var current_progress := 0
var time_left := 0.0
var current_reward := 0
var quest_title := ""
var quest_desc := ""
var initial_pops_at_start := 0
var cooldown_timer := 20.0
var quest_duration := 0.0
var pressure_elapsed := 0.0
var combo_count := 0
var combo_time_left := 0.0
var last_quest_type := ""
var automation_guide_stage := 0
var _guide_poll_timer := 0.0

@onready var game_manager = get_node_or_null("../GameManager")
@onready var shop_manager = get_node_or_null("../ShopManager")

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_PAUSABLE
	if game_manager:
		game_manager.pop_registered.connect(_on_pop_registered)
		game_manager.balloon_popped_detailed.connect(_on_balloon_popped_detailed)
	if shop_manager:
		shop_manager.room_switched.connect(_on_guide_room_switched)

func is_suspended() -> bool:
	if not game_manager or not game_manager.is_game_started or get_tree().paused:
		return true
	var main := get_parent()
	if main.get("is_loading_save"): return true
	var startup = main.get("startup_modal")
	return (is_instance_valid(startup) and startup.visible) or not game_manager.production_enabled

func _process(delta: float) -> void:
	_update_automation_guide(delta)
	if is_suspended(): return
	combo_time_left = maxf(0.0, combo_time_left - delta)
	if combo_time_left <= 0: combo_count = 0
	if not is_active:
		cooldown_timer -= delta
		if cooldown_timer <= 0: generate_random_quest()
		return
	time_left = maxf(0.0, time_left - delta)
	if quest_type == "pressure_hold":
		if pressure_ratio() >= 0.85:
			fail_quest()
			return
		pressure_elapsed = minf(quest_duration, pressure_elapsed + delta)
		current_progress = mini(current_target, int(pressure_elapsed))
		quest_progress_updated.emit(current_progress, current_target)
		if time_left <= 0: complete_quest()
	elif time_left <= 0:
		fail_quest()

func _on_guide_room_switched(room_id: String) -> void:
	if room_id == "medium_room" and automation_guide_stage == 0:
		automation_guide_stage = 1
		automation_guide_updated.emit()
		if get_parent().hud_controller:
			get_parent().hud_controller.show_prompt("Otomasyon rehberi başladı. Tablet → Tesis sekmesini aç.", 4.0)
		_save()

func _update_automation_guide(delta: float) -> void:
	if automation_guide_stage >= 5:
		return
	if get_tree().paused or not game_manager or get_parent().get("is_loading_save"):
		return
	if automation_guide_stage == 0:
		if shop_manager.current_room == "medium_room":
			_on_guide_room_switched("medium_room")
		return
	_guide_poll_timer += delta
	if _guide_poll_timer < 0.4:
		return
	_guide_poll_timer = 0.0
	if shop_manager.current_room != "medium_room":
		return
	var devices: Array = get_parent().active_placed_devices
	var crusher: Node3D
	var fan: Node3D
	var magnet: Node3D
	for device in devices:
		if not is_instance_valid(device) or device.is_queued_for_deletion():
			continue
		match str(device.get_meta("device_type", "")):
			"spike_wall": crusher = device
			"fan": fan = device
			"magnet_pylon": magnet = device
	if automation_guide_stage == 1 and is_instance_valid(crusher):
		_set_automation_guide_stage(2, "Zemin kırıcı kuruldu. Şimdi vantilatörü sipariş edip önünü kırıcıya çevir.")
	elif automation_guide_stage == 2 and is_instance_valid(fan) and is_instance_valid(crusher):
		var toward_crusher := crusher.global_position - fan.global_position
		toward_crusher.y = 0.0
		if toward_crusher.length_squared() > 0.01 and -fan.global_basis.z.dot(toward_crusher.normalized()) >= 0.6:
			_set_automation_guide_stage(3, "Vantilatör akışı kırıcıya yönlendi. Mıknatısı kırıcının merkezine yakın yerleştir.")
	elif automation_guide_stage == 3 and is_instance_valid(magnet) and is_instance_valid(crusher):
		var spacing := Vector2(magnet.global_position.x - crusher.global_position.x, magnet.global_position.z - crusher.global_position.z).length()
		if spacing <= 1.0:
			_set_automation_guide_stage(4, "Kurulum tamam. Üretimi aç ve kırıcının ilk balonları patlatmasını izle.")
	elif automation_guide_stage == 4 and is_instance_valid(crusher):
		var feedback = crusher.get("feedback")
		if is_instance_valid(feedback) and feedback.has_method("last_output") and feedback.last_output() > 0:
			_set_automation_guide_stage(5, "Otomasyon hattı çalışıyor. Cihaz katkısını Tesis ekranından takip edebilirsin.")
			shop_manager.add_coins(500)
			if get_parent().hud_controller:
				get_parent().hud_controller.show_prompt("Otomasyon kurulumu tamamlandı! +500 Coin", 4.0)
			if get_parent().sound_manager and get_parent().sound_manager.has_method("play_quest_complete"):
				get_parent().sound_manager.play_quest_complete()

func _set_automation_guide_stage(next_stage: int, notice: String) -> void:
	automation_guide_stage = next_stage
	automation_guide_updated.emit()
	if get_parent().hud_controller:
		get_parent().hud_controller.show_prompt(notice, 4.0)
	_save()

func get_automation_guide_data() -> Dictionary:
	if shop_manager and shop_manager.current_room == "medium_room" and automation_guide_stage == 0:
		return {"visible": true, "status": "Oda 2 otomasyon kurulumu", "details": "Oda 2'ye ilk girişinde kurulum rehberi açılır."}
	match automation_guide_stage:
		1: return {"visible": true, "status": "1 / 4 • Zemin kırıcı", "details": "Tabletten Zemin Kırıcısı sipariş et, paketi al ve odaya yerleştir."}
		2: return {"visible": true, "status": "2 / 4 • Akışı yönlendir", "details": "Vantilatör sipariş et ve yerleştir. R ile önünü zemin kırıcıya çevir."}
		3: return {"visible": true, "status": "3 / 4 • Mıknatısı yerleştir", "details": "Mıknatısı zemin kırıcının merkezinden en fazla 1 m uzağa yerleştir."}
		4: return {"visible": true, "status": "4 / 4 • İlk otomatik patlatma", "details": "Üretimi çalıştır. Kırıcı ilk balonu patlatınca rehber tamamlanır ve 500 Coin kazanırsın."}
		5: return {"visible": true, "status": "TAMAMLANDI • Otomasyon hattı aktif", "details": "Cihazların son 10 saniyedeki gerçek katkısını bu ekrandan izle."}
	return {"visible": false, "status": "", "details": ""}

func pressure_ratio() -> float:
	return float(game_manager.get_physical_balloon_count()) / maxi(1, game_manager.get_physics_budget())

func _on_pop_registered(total_pops: int) -> void:
	if not is_active or is_suspended() or quest_type != "total_pops": return
	current_progress = clampi(total_pops - initial_pops_at_start, 0, current_target)
	quest_progress_updated.emit(current_progress, current_target)
	if current_progress >= current_target: complete_quest()

func _on_balloon_popped_detailed(_pos: Vector3, b_tier: int, _chain_depth: int) -> void:
	if not is_active or is_suspended(): return
	if quest_type == "tier_pops" and b_tier >= 5:
		current_progress += 1
	elif quest_type == "combo_chain":
		combo_count = combo_count + 1 if combo_time_left > 0 else 1
		combo_time_left = COMBO_GAP
		current_progress = maxi(current_progress, combo_count)
	else: return
	current_progress = mini(current_progress, current_target)
	quest_progress_updated.emit(current_progress, current_target)
	if current_progress >= current_target: complete_quest()

func supply_profile(duration: float) -> Dictionary:
	var room: Dictionary = shop_manager.get_current_room_data()
	var weights: Dictionary = room.get("tier_weights", {1: 1.0})
	var expected_value := 0.0
	var elite_chance := 0.0
	for tier in weights:
		expected_value += int(tier) * float(weights[tier])
		if int(tier) >= 5: elite_chance += float(weights[tier])
	var elite_in_room := 0
	var container := get_node_or_null("../BalloonContainer")
	if container:
		for balloon in container.get_children():
			if balloon is RigidBody3D and not balloon.is_queued_for_deletion() and not balloon.get("is_popped") and int(balloon.get("tier_value")) >= 5:
				elite_in_room += 1
	var flow := float(game_manager.get_effective_balloons_per_second())
	return {"total": maxf(1.0, game_manager.get_physical_balloon_count() + flow * duration),
		"elite": elite_in_room + flow * duration * elite_chance, "value": expected_value}

func eligible_types() -> Array[String]:
	var eligible: Array[String] = ["total_pops"]
	if supply_profile(60.0).elite >= 6: eligible.append("tier_pops")
	if int(shop_manager.upgrades.auto_pop.level) > 0 or int(shop_manager.upgrades.splash_pop.level) > 0 or not get_parent().active_placed_devices.is_empty():
		eligible.append("combo_chain")
	# Avoid free survival rewards in nearly empty rooms and immediate failure above the threshold.
	if pressure_ratio() >= 0.35 and pressure_ratio() < 0.75:
		eligible.append("pressure_hold")
	return eligible

func production_target(duration: float) -> int:
	var profile := supply_profile(duration)
	var measured: float = game_manager.minute_measured_seconds
	var rate: float = float(game_manager.last_minute_pops) / maxf(1.0, measured)
	if measured < 10.0:
		rate = float(game_manager.get_effective_balloons_per_second()) * 0.6
	var desired := maxi(5, int(round(rate * duration * 1.15)))
	return mini(desired, maxi(1, int(float(profile.total) * 0.8)))

func generate_random_quest() -> void:
	if is_suspended(): return
	var eligible := eligible_types()
	if eligible.size() > 1: eligible.erase(last_quest_type)
	quest_type = eligible.pick_random()
	var duration := float(randi_range(45, 75))
	var target := 1
	var title := ""
	var description := ""
	match quest_type:
		"total_pops":
			target = production_target(duration)
			title = "ÜRETİM GÖREVİ"
			description = "%d sn içinde %d balon patlat. Her balon bir kez sayılır." % [duration, target]
		"tier_pops":
			target = clampi(int(float(supply_profile(duration).elite) * 0.4), 2, 12)
			title = "DEĞERLİ HEDEF"
			description = "%d sn içinde değeri 5 veya daha yüksek %d balon patlat." % [duration, target]
		"combo_chain":
			target = randi_range(4, 7)
			title = "SERİ KOMBO"
			description = "%d sn içinde aralarında en fazla 1,5 sn olacak şekilde %d balon patlat. Cihazlar da sayılır." % [duration, target]
		"pressure_hold":
			duration = float(randi_range(25, 40))
			target = int(duration)
			title = "BASINÇ KONTROLÜ"
			description = "Üretim açıkken %d sn boyunca doluluğu %%85 altında tut." % target
	# Görev ödülleri: Oyuncunun zamanına ve emeğine değecek seviyeye çekildi.
	# Bulunulan odanın ortalama balon değeri, coin çarpanı ve hedefin zorluğuyla katlanarak çarpar.
	var room_data: Dictionary = shop_manager.get_current_room_data() if shop_manager else {}
	var room_coin_mult: float = float(room_data.get("coin_multiplier", 1.0))
	var room_id: String = str(room_data.get("id", "small_room"))
	
	# Oda bazlı taban bonus (Oyuncu ilerledikçe görevlerin önemsiz kalmasını engeller)
	var room_base_bonus: int = 250
	match room_id:
		"small_room": room_base_bonus = 250
		"medium_room": room_base_bonus = 1500
		"hangar": room_base_bonus = 8000
	
	var reward_units := 0
	match quest_type:
		"total_pops":
			# Hedeflenen balon başına 8-15 altın değerinde katkı
			reward_units = int(target * 10.0)
		"tier_pops":
			# Nadir balon avı yüksek ödül verir
			reward_units = int(target * 65.0)
		"combo_chain":
			# Seri kombo beceri gerektirir
			reward_units = int(target * 45.0)
		"pressure_hold":
			# Hayatta kalma görevi
			reward_units = int(target * 15.0)
			
	var calculated_reward: int = int((reward_units * room_coin_mult) + room_base_bonus)
	# Minimum ödül 350 altın, üst sınır 250.000 altın (üst odalar için)
	var reward := clampi(calculated_reward, 350, 250000)
	start_quest(title, description, target, duration, reward)

func start_quest(title: String, desc: String, target: int, duration: float, reward: int) -> void:
	is_active = true
	last_quest_type = quest_type
	current_target = maxi(1, target)
	time_left = maxf(1.0, duration)
	quest_duration = time_left
	current_reward = maxi(0, reward)
	quest_title = title
	quest_desc = desc
	initial_pops_at_start = game_manager.total_pops
	current_progress = 0
	pressure_elapsed = 0.0
	combo_count = 0
	combo_time_left = 0.0
	quest_started.emit(title, desc, current_target, quest_duration, current_reward)
	_save()

func complete_quest() -> void:
	if not is_active: return
	is_active = false
	cooldown_timer = randf_range(30.0, 50.0)
	if shop_manager:
		shop_manager.coins += current_reward
		shop_manager.coins_changed.emit(shop_manager.coins)
	quest_completed.emit(current_reward)
	_save()

func fail_quest() -> void:
	if not is_active: return
	is_active = false
	cooldown_timer = randf_range(20.0, 35.0)
	quest_failed.emit()
	_save()

func _save() -> void:
	if get_parent().has_method("save_current_data"): get_parent().save_current_data.call_deferred()

func save_state() -> Dictionary:
	return {"active": is_active, "type": quest_type, "target": current_target,
		"progress": current_progress, "time_left": time_left, "duration": quest_duration,
		"reward": current_reward, "title": quest_title, "description": quest_desc,
		"cooldown": cooldown_timer, "pressure_elapsed": pressure_elapsed,
		"combo_count": combo_count, "combo_time_left": combo_time_left, "last_type": last_quest_type,
		"automation_guide_stage": automation_guide_stage}

func restore(state: Dictionary) -> void:
	is_active = false
	state_reset.emit()
	quest_type = str(state.get("type", "total_pops"))
	last_quest_type = str(state.get("last_type", ""))
	cooldown_timer = clampf(float(state.get("cooldown", 20.0)), 0, 120)
	current_target = maxi(1, int(state.get("target", 1)))
	current_progress = clampi(int(state.get("progress", 0)), 0, current_target)
	quest_duration = clampf(float(state.get("duration", 60)), 1, 300)
	time_left = clampf(float(state.get("time_left", 0)), 0, quest_duration)
	current_reward = clampi(int(state.get("reward", 0)), 0, 250000)
	quest_title = str(state.get("title", "GÖREV"))
	quest_desc = str(state.get("description", ""))
	pressure_elapsed = clampf(float(state.get("pressure_elapsed", 0)), 0, quest_duration)
	combo_count = clampi(int(state.get("combo_count", 0)), 0, current_target)
	combo_time_left = clampf(float(state.get("combo_time_left", 0)), 0, COMBO_GAP)
	automation_guide_stage = clampi(int(state.get("automation_guide_stage", 0)), 0, 5)
	initial_pops_at_start = game_manager.total_pops - current_progress
	is_active = bool(state.get("active", false)) and TYPES.has(quest_type) and time_left > 0 and current_progress < current_target
	if is_active:
		quest_started.emit(quest_title, quest_desc, current_target, quest_duration, current_reward)
		quest_progress_updated.emit(current_progress, current_target)
	automation_guide_updated.emit()
