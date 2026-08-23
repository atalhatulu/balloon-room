extends Node

signal pop_registered(total_pops: int)
signal spawn_requested(count: int)
signal active_count_changed(active_count: int, max_capacity: int)

var total_pops: int = 0
var active_balloons: int = 0
var is_game_started: bool = false

# Base Upgrade Tables (Substantial factory waterfall flow & high capacity with 144 FPS)
var base_rate_table: Array = [2.5, 4.5, 7.5, 12.0, 18.0, 28.0, 42.0, 60.0, 85.0, 120.0, 170.0, 240.0, 320.0]
var base_cap_table: Array = [120, 220, 380, 600, 950, 1450, 2100, 2900, 3800, 5000, 6800]

var current_vent_level: int = 0
var current_cap_level: int = 0

# Room Expansion Multipliers
var room_cap_bonus: int = 0
var room_flow_multiplier: float = 1.0

var balloons_per_second: float = 2.5
var max_room_balloons: int = 120
var spawn_accumulator: float = 0.0

@onready var sound_manager = get_node_or_null("../SoundManager")
@onready var shop_manager = get_node_or_null("../ShopManager")

func _ready() -> void:
	if shop_manager:
		if shop_manager.has_signal("upgrade_purchased"):
			shop_manager.upgrade_purchased.connect(_on_upgrade_purchased)
		if shop_manager.has_signal("room_switched"):
			shop_manager.room_switched.connect(_on_room_switched)
		if shop_manager.has_signal("prestige_performed"):
			shop_manager.prestige_performed.connect(func(_lvl, _he): recalculate_effective_stats())
	
	recalculate_effective_stats()
	start_game()

func start_game() -> void:
	is_game_started = true
	_start_initial_stream()

func _start_initial_stream() -> void:
	if active_balloons == 0:
		spawn_requested.emit(1)
	active_count_changed.emit(active_balloons, max_room_balloons)

func recalculate_effective_stats() -> void:
	var prestige_bonus = 1.0
	if shop_manager and "prestige_level" in shop_manager:
		prestige_bonus = 1.0 + (shop_manager.prestige_level * 0.5)
		
	if shop_manager and shop_manager.has_method("get_current_room_data"):
		var r_data = shop_manager.get_current_room_data()
		room_cap_bonus = r_data.get("cap_bonus", 0)
		room_flow_multiplier = r_data.get("flow_mult", 1.0)
	
	var pipe_count = 1
	if shop_manager and shop_manager.upgrades.has("pipe_count"):
		pipe_count = 1 + shop_manager.upgrades["pipe_count"]["level"]
		
	var base_rate = base_rate_table[clamp(current_vent_level, 0, base_rate_table.size() - 1)]
	var base_cap = base_cap_table[clamp(current_cap_level, 0, base_cap_table.size() - 1)]
	
	# Each extra pipe adds true 100% full nozzle throughput pouring into the room
	var pipe_flow_mult = float(pipe_count) * 1.0
	balloons_per_second = (base_rate * pipe_flow_mult) * room_flow_multiplier * prestige_bonus
	max_room_balloons = base_cap + room_cap_bonus
	active_count_changed.emit(active_balloons, max_room_balloons)

var pop_history: Array[float] = []
var pops_per_second: int = 0
var smooth_pps: float = 0.0

func get_eta_to_target(target: int = 1000000) -> float:
	var remaining = max(0, target - total_pops)
	if remaining <= 0:
		return 0.0
	var effective_rate = max(smooth_pps, float(pops_per_second))
	if effective_rate < 0.5:
		return -1.0
	return float(remaining) / effective_rate

func _process(delta: float) -> void:
	# Calculate real-time Pops Per Second (rolling 1-second window)
	var now = Time.get_ticks_msec() / 1000.0
	while not pop_history.is_empty() and pop_history[0] < (now - 1.0):
		pop_history.remove_at(0)
	pops_per_second = pop_history.size()
	smooth_pps = lerp(smooth_pps, float(pops_per_second), clamp(delta * 1.5, 0.0, 1.0))

	if not is_game_started:
		return
		
	var bc = get_node_or_null("../BalloonContainer")
	if bc and is_instance_valid(bc):
		active_balloons = bc.get_child_count()
		
	if active_balloons < max_room_balloons:
		spawn_accumulator += delta * balloons_per_second
		if spawn_accumulator >= 1.0:
			var to_spawn = int(spawn_accumulator)
			var remaining_space = max_room_balloons - active_balloons
			var final_count = min(to_spawn, remaining_space)
			final_count = min(final_count, 12)
			if final_count > 0:
				spawn_accumulator -= float(final_count)
				spawn_requested.emit(final_count)
			else:
				spawn_accumulator = min(spawn_accumulator, 2.0)
	else:
		spawn_accumulator = 0.0

func on_balloon_spawned(count: int = 1) -> void:
	active_balloons += count
	active_count_changed.emit(active_balloons, max_room_balloons)

func on_balloon_popped(pop_position: Vector3, _balloon_color: Color, combo_step: int = 0, _b_type: int = 0) -> void:
	total_pops += 1
	active_balloons = max(0, active_balloons - 1)
	pop_history.append(Time.get_ticks_msec() / 1000.0)
	
	if sound_manager and sound_manager.has_method("play_pop"):
		var pitch_idx = (combo_step if combo_step > 0 else (total_pops % 8))
		sound_manager.play_pop(pitch_idx)
		
	# Apply Room Tier Coin Multiplier (1.0x in Small -> 8.0x in Hyper Lab!)
	var room_mult = 1.0
	if shop_manager and shop_manager.has_method("get_current_room_data"):
		var r_data = shop_manager.get_current_room_data()
		room_mult = r_data.get("coin_multiplier", 1.0)
		
	var coin_reward = max(1, int(1.0 * room_mult))
	
	# Drop physical gold coin to floor for player to collect
	var main_node = get_node_or_null("/root/Main")
	if main_node and main_node.has_method("spawn_floor_coin"):
		main_node.spawn_floor_coin(pop_position, coin_reward)
		
	pop_registered.emit(total_pops)
	active_count_changed.emit(active_balloons, max_room_balloons)

func _on_upgrade_purchased(upgrade_id: String, level: int) -> void:
	match upgrade_id:
		"vent_rate":
			current_vent_level = level
			recalculate_effective_stats()
		"room_capacity":
			current_cap_level = level
			recalculate_effective_stats()
		"pipe_count":
			recalculate_effective_stats()

func _on_room_switched(_room_id: String) -> void:
	recalculate_effective_stats()
