class_name BalloonSpawnerController
extends Node

var _main: Node3D = null

var vent_chute_counter: int = 0
var _active_float_labels: int = 0

func setup(main_node: Node3D) -> void:
	_main = main_node

func clamp_tier_for_current_room(tier: int) -> int:
	if not _main or not _main.shop_manager: return tier
	var room: Dictionary = _main.shop_manager.get_current_room_data()
	return mini(tier, int(room.get("max_balloon_tier", 50)))

func normalize_live_balloon_tiers() -> void:
	if not _main or not _main.balloon_container: return
	for balloon in _main.balloon_container.get_children():
		if not is_instance_valid(balloon) or balloon.is_queued_for_deletion(): continue
		if not ("tier_value" in balloon) or not balloon.has_method("setup_tier"): continue
		var safe_tier := clamp_tier_for_current_room(int(balloon.tier_value))
		if safe_tier != int(balloon.tier_value):
			balloon.setup_tier(safe_tier)

func drop_balloons_from_vent(count: int) -> void:
	if not _main or not _main.balloon_scene or not _main.balloon_container or _main.get_tree().paused or _main.is_blackout:
		return
		
	var current_physical = _main.game_manager.get_physical_balloon_count()
	var physics_budget = _main.game_manager.get_physics_budget()
	if not _main.game_manager.production_enabled: return
	if current_physical >= physics_budget:
		return
		
	var spawn_allowed = min(count, physics_budget - current_physical)
	var grav = _main.room_controller.get_current_gravity_scale() if _main.room_controller else 0.25
	var damp = _main.room_controller.get_current_linear_damp() if _main.room_controller else 2.2
	
	for i in range(spawn_allowed):
		var ejection = _main.room_controller.get_vent_ejection(i) if (_main.room_controller and _main.room_controller.has_method("get_vent_ejection")) else {
			"position": (_main.room_controller.get_next_vent_spawn_position(i) if _main.room_controller else Vector3(0, 4.0, 0)),
			"direction": Vector3(0, 0, 1),
			"chute_index": 0
		}
		
		if _main.sound_manager and _main.sound_manager.has_method("play_vent_spawn"):
			_main.sound_manager.play_vent_spawn()
			
		var spawn_pos: Vector3 = ejection["position"]
		var chute_dir: Vector3 = ejection["direction"]
		
		var roll = randf()
		var b_tier = 1
		var b_special = "normal"
		
		var special_roll = randf()
		if special_roll < 0.04:
			b_special = "bomb"
		elif special_roll < 0.08:
			b_special = "gold"
			
		var bonus_kind: String = _main.bonus_controller.roll_spawn()
		if bonus_kind != "": b_special = bonus_kind
		var room_tw = {1: 0.92, 5: 0.08, 10: 0.0, 50: 0.0}
		if _main.shop_manager and _main.shop_manager.has_method("get_current_room_data"):
			var r_data = _main.shop_manager.get_current_room_data()
			if r_data.has("tier_weights"):
				room_tw = r_data["tier_weights"]
				
		var w50 = room_tw.get(50, 0.0)
		var w10 = room_tw.get(10, 0.0)
		var w5 = room_tw.get(5, 0.06)
		var room_max_tier := int(_main.shop_manager.get_current_room_data().get("max_balloon_tier", 50)) if _main.shop_manager else 50
		
		# Hangar weights are tuned as a fixed large-balloon mix. Keep the adaptive
		# density boost in early rooms only so it cannot skew that mix further.
		var current_room_id: String = _main.shop_manager.current_room if _main.shop_manager else "small_room"
		if current_room_id != "hangar" and current_physical > 240:
			var ratio = clamp(float(current_physical - 240) / 140.0, 0.0, 1.0)
			if room_max_tier >= 5: w5 += 0.10 * ratio
			if room_max_tier >= 10 and w10 > 0.0: w10 += 0.05 * ratio
			if room_max_tier >= 50 and w50 > 0.0: w50 += 0.02 * ratio
		
		if roll < w50:
			b_tier = 50
		elif roll < (w50 + w10):
			b_tier = 10
		elif roll < (w50 + w10 + w5):
			b_tier = 5
		else:
			b_tier = 1

		if b_special.begins_with("bonus_"): b_tier = 1
		b_tier = clamp_tier_for_current_room(b_tier)
		var remaining: int = _main.game_manager.max_room_balloons - _main.game_manager.active_balloons
		if remaining <= 0: break
		if b_tier > remaining: b_tier = 1
		var balloon = _main.balloon_scene.instantiate()
		balloon.position = spawn_pos
		_main.balloon_container.add_child(balloon)
		if balloon.has_method("setup_tier"):
			balloon.setup_tier(b_tier)
		if b_special != "normal" and balloon.has_method("setup_special_type"):
			balloon.setup_special_type(b_special)
		
		if balloon is RigidBody3D:
			if balloon.has_method("apply_room_physics"):
				balloon.apply_room_physics(grav, damp)
			else:
				balloon.gravity_scale = grav
			# Balonları tavan borusundan aşağı düşer gibi değil, odaya kuvvetle itilir/püskürtülür şekilde fırlat
			var forward_speed = randf_range(11.0, 16.5)
			var spread_angle = randf_range(-0.55, 0.55)
			var shoot_dir_h = Vector2(chute_dir.x, chute_dir.z).rotated(spread_angle)
			# Yatayda güçlü bir dağılma, dikeyde ise hafif yay şeklinde başlangıç itişi
			var blast_down = randf_range(-1.8, -3.2)
			var ejection_vel = Vector3(shoot_dir_h.x * forward_speed, blast_down, shoot_dir_h.y * forward_speed)
			balloon.linear_velocity = ejection_vel
			balloon.rotation = Vector3(randf_range(-0.35, 0.35), randf_range(0.0, TAU), randf_range(-0.35, 0.35))
			balloon.angular_velocity = Vector3(randf_range(-5.0, 5.0), randf_range(-5.0, 5.0), randf_range(-5.0, 5.0))
			if balloon.has_method("apply_elastic_impact"):
				balloon.apply_elastic_impact(ejection_vel * 0.4)
			
		if balloon.has_signal("popped"):
			var balloon_spec = b_special
			balloon.popped.connect(func(_b, pos, col, combo = 0, b_type = 1, is_midair = false): 
				var now_sec = Time.get_ticks_msec() / 1000.0
				var fan_blown = (now_sec - _b.blown_by_fan_time) < 4.0 if ("blown_by_fan_time" in _b) else false
				var magnet_pulled = (now_sec - _b.pulled_by_magnet_time) < 4.0 if ("pulled_by_magnet_time" in _b) else false
				var pop_src = str(_b.last_pop_source)
				
				var combo_mult = 1
				var combo_tag = ""
				if fan_blown and magnet_pulled:
					combo_mult = 5
					combo_tag = "combo_triple"
				elif fan_blown and (pop_src == "electric_grid" or pop_src == "laser_fence"):
					combo_mult = 3
					combo_tag = "combo_airsweep"
				elif magnet_pulled and pop_src == "spike_wall":
					combo_mult = 2
					combo_tag = "combo_vortex"
					
				if _main.game_manager: 
					_main.game_manager.on_balloon_popped(pos, col, combo, b_type, is_midair, pop_src, combo_mult)
				show_pop_visual(pos, combo, b_type, balloon_spec, is_midair, combo_tag, combo_mult)
			)
			
		if _main.game_manager and _main.game_manager.has_method("on_balloon_spawned"):
			_main.game_manager.on_balloon_spawned(b_tier)
			
		current_physical += 1
			
	vent_chute_counter = (vent_chute_counter + spawn_allowed) % 4
			
	if _main.room_controller:
		_main.room_controller.advance_vent_cycle(count)

func spawn_floor_coin(pop_pos: Vector3, val: int = 1, _tier: int = 1) -> void:
	if not _main.coin_scene or not _main.coin_container: return

	# 1. Break val into optimal denominations (50 Large Gold, 10 Gold, 5 Silver, 1 Bronze)
	var remaining = max(1, val)
	var denominations = [50, 10, 5, 1]
	
	for denom in denominations:
		while remaining >= denom:
			_create_or_recycle_coin(pop_pos, denom)
			remaining -= denom
			
	# 2. Check total ground coin pressure and compact if too high (> 60 coins)
	_compact_coins_if_needed()

func _create_or_recycle_coin(pop_pos: Vector3, denom: int) -> void:
	if _main.coin_container.get_child_count() >= 90:
		for oldest_coin in _main.coin_container.get_children():
			if not is_instance_valid(oldest_coin) or oldest_coin.is_queued_for_deletion() or oldest_coin.collected or oldest_coin.is_merging or oldest_coin.is_collecting:
				continue
			_main.shop_manager.add_coins(oldest_coin.coin_value)
			oldest_coin.init(pop_pos, denom, denom)
			_main.coin_container.move_child(oldest_coin, -1)
			return

	var coin = _main.coin_scene.instantiate()
	_main.coin_container.add_child(coin)
	if coin.has_method("init"):
		coin.init(pop_pos, denom, denom)

func _compact_coins_if_needed() -> void:
	var total_coins = _main.coin_container.get_child_count()
	if total_coins <= 60:
		return

	# Gather grounded/settled coins eligible for merging
	var settled_coins: Array = []
	for child in _main.coin_container.get_children():
		if is_instance_valid(child) and not child.is_queued_for_deletion() and not child.is_merging and not child.collected:
			if child.get("is_grounded") and not child.get("is_collecting") and child.get("coin_value") < 50:
				settled_coins.append(child)

	if settled_coins.size() < 4:
		return

	# Sort spatially or group nearby settled coins
	# Group 1s into 5s, 5s into 10s, 10s into 50s
	var value_groups = {1: [], 5: [], 10: []}
	for c in settled_coins:
		var cv = c.get("coin_value")
		if value_groups.has(cv):
			value_groups[cv].append(c)

	# Merge 5x 1s -> 1x 5
	_merge_coin_group(value_groups[1], 5, 5)
	# Merge 2x 5s -> 1x 10
	_merge_coin_group(value_groups[5], 2, 10)
	# Merge 5x 10s -> 1x 50
	_merge_coin_group(value_groups[10], 5, 50)

func _merge_coin_group(coins_list: Array, batch_size: int, target_denom: int) -> void:
	while coins_list.size() >= batch_size:
		var batch: Array = []
		for i in range(batch_size):
			batch.append(coins_list.pop_back())
			
		var lead_coin = batch[0]
		var avg_pos: Vector3 = lead_coin.global_position
		
		# Animate other coins flying into lead coin
		for i in range(1, batch.size()):
			var sub_coin = batch[i]
			if is_instance_valid(sub_coin) and not sub_coin.is_queued_for_deletion():
				sub_coin.is_merging = true
				sub_coin.collected = true
				if sub_coin.visual_tween and sub_coin.visual_tween.is_valid(): sub_coin.visual_tween.kill()
				# Disable collision monitoring to prevent Jolt physics singular transform warning
				if sub_coin is Area3D:
					sub_coin.set_deferred("monitoring", false)
					sub_coin.set_deferred("monitorable", false)
				var tw = sub_coin.create_tween()
				tw.tween_property(sub_coin, "global_position", avg_pos + Vector3(0, 0.2, 0), 0.12).set_trans(Tween.TRANS_QUAD)
				tw.tween_property(sub_coin, "scale", Vector3(0.05, 0.05, 0.05), 0.08)
				tw.tween_callback(sub_coin.queue_free)
				
		# Upgrade lead coin to higher tier with pop bounce
		if is_instance_valid(lead_coin) and not lead_coin.is_queued_for_deletion():
			lead_coin.set("coin_value", target_denom)
			lead_coin.upgrade_tier(target_denom)
			if _main.sound_manager and _main.sound_manager.has_method("play_pop"):
				_main.sound_manager.play_pop(6)

var _last_midair_label_time: int = 0
var _last_combo_label_time: int = 0

func show_pop_visual(pos: Vector3, combo: int, b_type: int, spec_type: String = "normal", is_midair: bool = false, combo_tag: String = "", combo_mult: int = 1) -> void:
	var now = Time.get_ticks_msec()
	var cur_pps = _main.game_manager.smooth_pps if (_main and _main.game_manager and "smooth_pps" in _main.game_manager) else 0.0
	
	# Noise Filter: If production is rapid (PPS > 12), mute single-balloon and low-tier spam completely
	var is_intense = cur_pps > 12.0
	
	var txt = ""
	var col = Color(1.0, 1.0, 1.0)
	var sz = 28
	
	if combo_tag != "":
		match combo_tag:
			"combo_triple":
				txt = "⚡ SÜPER KOMBO x%d POP!" % combo_mult
				col = Color(1.0, 0.35, 1.0)
				sz = 36
			"combo_airsweep":
				txt = "🌪️ HAVA SÜPÜRME x%d POP!" % combo_mult
				col = Color(0.2, 0.95, 1.0)
				sz = 34
			"combo_vortex":
				txt = "🌀 GİRDAP EZİCİ x%d POP!" % combo_mult
				col = Color(1.0, 0.85, 0.2)
				sz = 32
	elif spec_type.begins_with("bonus_"):
		if _main.sound_manager: _main.sound_manager.play_gold_pop()
		return # Persistent HUD countdown replaces extra floating text.
	if spec_type == "chroma":
		txt = "🌈 GİZEMLİ BALON!"
		col = Color(1.0, 0.4, 0.9)
		sz = 38
		if _main.sound_manager and _main.sound_manager.has_method("play_quest_complete"):
			_main.sound_manager.play_quest_complete()
	elif spec_type == "supernova":
		txt = "💥 SÜPERNOVA!"
		col = Color(1.0, 0.95, 0.4)
		sz = 34
	elif spec_type == "bomb":
		txt = "💣 PATLAMA!"
		col = Color(1.0, 0.35, 0.15)
		sz = 34
		if _main.sound_manager and _main.sound_manager.has_method("play_bomb_pop"):
			_main.sound_manager.play_bomb_pop()
	elif spec_type == "gold":
		txt = "✨ +50 ALTIN!"
		col = Color(1.0, 0.85, 0.15)
		sz = 34
		if _main.sound_manager and _main.sound_manager.has_method("play_gold_pop"):
			_main.sound_manager.play_gold_pop()
		if _main.shop_manager and _main.shop_manager.has_method("add_coins"):
			_main.shop_manager.add_coins(50 * _main.bonus_controller.multiplier())
	elif spec_type == "air":
		txt = "💨 HAVA DALGASI!"
		col = Color(0.35, 0.90, 1.0)
		sz = 32
		if _main.sound_manager and _main.sound_manager.has_method("play_air_blast"):
			_main.sound_manager.play_air_blast()
	elif b_type >= 50:
		txt = "+50 💎"
		col = Color(0.85, 0.35, 1.0)
		sz = 34
	elif b_type >= 10:
		txt = "+10 ⭐"
		col = Color(0.3, 0.95, 0.7)
		sz = 30
	elif combo >= 4:
		# Throttle rapid combo text popups to at most once per 200ms
		if (now - _last_combo_label_time) < 200:
			return
		_last_combo_label_time = now
		txt = "💥 KOMBO x%d!" % combo
		col = Color(0.2, 0.95, 1.0)
		sz = 32
	elif b_type >= 5 and not is_intense:
		txt = "+5 🎈"
		col = Color(1.0, 0.65, 0.2)
		sz = 28
	else:
		return
		
	# Strict clutter cap: at most 4 floating labels visible simultaneously
	if _active_float_labels >= 4:
		return
	_active_float_labels += 1
	var lbl = Label3D.new()
	lbl.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	lbl.no_depth_test = true
	lbl.text = txt
	lbl.modulate = col
	lbl.outline_modulate = Color(0.05, 0.05, 0.08, 0.9)
	lbl.outline_size = 8
	lbl.font_size = sz
	lbl.pixel_size = 0.0075
	lbl.position = pos + Vector3(0.0, 0.35, 0.0)
	_main.add_child(lbl)
	
	var tw = _main.create_tween()
	tw.set_parallel(true)
	tw.tween_property(lbl, "position:y", lbl.position.y + 0.60, 0.38).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tw.tween_property(lbl, "scale", Vector3(1.15, 1.15, 1.15), 0.12).from(Vector3(0.5, 0.5, 0.5))
	tw.chain().tween_property(lbl, "modulate:a", 0.0, 0.15)
	tw.chain().tween_callback(func():
		_active_float_labels = max(0, _active_float_labels - 1)
		lbl.queue_free()
	)

var _pile_check_timer: float = 0.0

func update_pile_optimization(delta: float) -> void:
	if not _main or not _main.balloon_container or _main.get_tree().paused: return
	_pile_check_timer += delta
	if _pile_check_timer < 0.35: return # Saniyede ~3 kez hafif ve akıcı kontrol
	_pile_check_timer = 0.0
	
	var player_pos: Vector3 = _main.player.global_position if _main.player else Vector3.ZERO
	var active_devices: Array = _main.active_placed_devices
	
	for b in _main.balloon_container.get_children():
		if not is_instance_valid(b) or b.is_queued_for_deletion() or not (b is RigidBody3D):
			continue
			
		var b_pos: Vector3 = b.global_position
		# 1. Oyuncunun 4.0 metre yakınındaki veya cihazların etrafındaki balonlar DAİMA çözülür (Active)
		var near_player = b_pos.distance_squared_to(player_pos) < 16.0
		var near_device = false
		if not near_player:
			for dev in active_devices:
				if is_instance_valid(dev) and b_pos.distance_squared_to(dev.global_position) < 25.0: # 5m cihaz çekim alanı
					near_device = true
					break
					
		if near_player or near_device:
			if b.freeze:
				b.thaw_physics()
			if b.can_sleep:
				b.can_sleep = false
		else:
			# 2. Oyuncudan ve cihazlardan uzakta, tabana (y <= 1.8m) inmiş balonlar uyuyabilir ve dondurulabilir
			var is_grounded = b_pos.y <= 1.8
			if is_grounded:
				if not b.can_sleep:
					b.can_sleep = true
				if not b.freeze and (b.sleeping or b.linear_velocity.length_squared() < 0.04):
					b.freeze_pile()
			else:
				# Havadaki balonlar asla uyuyamaz ve dondurulamaz
				if b.freeze:
					b.thaw_physics()
				if b.can_sleep:
					b.can_sleep = false
