extends Node

signal pop_registered(total_pops: int)
signal spawn_requested(count: int)
signal active_count_changed(active_count: int, max_capacity: int)

var total_pops: int = 0
var active_balloons: int = 0
var is_game_started: bool = false

# Base Upgrade Tables (Smooth progression starting at 1 balloon/sec up to 450/sec)
var base_rate_table: Array = [1.0, 2.0, 3.5, 6.0, 10.0, 16.0, 26.0, 42.0, 70.0, 110.0, 180.0, 280.0, 450.0]
var base_cap_table: Array = [30, 50, 80, 130, 200, 320, 500, 750, 1100, 1600, 2400]

var current_vent_level: int = 0
var current_cap_level: int = 0

# Room Expansion Multipliers
var room_cap_bonus: int = 0
var room_flow_multiplier: float = 1.0

var balloons_per_second: float = 1.0
var max_room_balloons: int = 40
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
	
	var base_rate = base_rate_table[clamp(current_vent_level, 0, base_rate_table.size() - 1)]
	var base_cap = base_cap_table[clamp(current_cap_level, 0, base_cap_table.size() - 1)]
	
	balloons_per_second = base_rate * room_flow_multiplier * prestige_bonus
	max_room_balloons = base_cap + room_cap_bonus
	active_count_changed.emit(active_balloons, max_room_balloons)

func _process(delta: float) -> void:
	if not is_game_started:
		return
		
	if active_balloons < max_room_balloons:
		spawn_accumulator += delta * balloons_per_second
		if spawn_accumulator >= 1.0:
			var to_spawn = int(spawn_accumulator)
			spawn_accumulator -= float(to_spawn)
			
			var remaining_space = max_room_balloons - active_balloons
			var final_count = min(to_spawn, remaining_space)
			if final_count > 0:
				spawn_requested.emit(final_count)
	else:
		spawn_accumulator = 0.0

func on_balloon_spawned(count: int = 1) -> void:
	active_balloons += count
	active_count_changed.emit(active_balloons, max_room_balloons)

func on_balloon_popped(_pop_position: Vector3, _balloon_color: Color, combo_step: int = 0, _b_type: int = 0) -> void:
	total_pops += 1
	active_balloons = max(0, active_balloons - 1)
	
	if sound_manager and sound_manager.has_method("play_pop"):
		var pitch_idx = (combo_step if combo_step > 0 else (total_pops % 8))
		sound_manager.play_pop(pitch_idx)
		
	# Apply Room Tier Coin Multiplier (1.0x in Small -> 8.0x in Hyper Lab!)
	var room_mult = 1.0
	if shop_manager and shop_manager.has_method("get_current_room_data"):
		var r_data = shop_manager.get_current_room_data()
		room_mult = r_data.get("coin_multiplier", 1.0)
		
	var coin_reward = max(1, int(1.0 * room_mult))
	
	if shop_manager and shop_manager.has_method("add_coins"):
		shop_manager.add_coins(coin_reward)
		
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

func _on_room_switched(_room_id: String) -> void:
	recalculate_effective_stats()
