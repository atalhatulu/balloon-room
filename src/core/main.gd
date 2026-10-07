extends Node3D

@export var balloon_scene: PackedScene = preload("res://src/entities/balloon.tscn")
@export var coin_scene: PackedScene = preload("res://src/entities/coin.tscn")
@export var override_initial_room: String = ""

const DEVICE_SCENES = {
	"fan": preload("res://src/devices/fan.tscn"),
	"spike_wall": preload("res://src/devices/spike_wall.tscn"),
	"electric_wall": preload("res://src/devices/electric_wall.tscn"),
	"magnet_pylon": preload("res://src/devices/magnet_pylon.tscn"),
	"conveyor_crusher": preload("res://src/devices/conveyor_crusher.tscn"),
	"sentry_drone": preload("res://src/devices/sentry_drone.tscn")
}

const ModalManagerClass = preload("res://src/controllers/modal_manager.gd")
const HUDControllerClass = preload("res://src/controllers/hud_controller.gd")
const InteractionControllerClass = preload("res://src/controllers/interaction_controller.gd")
const EnvironmentControllerClass = preload("res://src/controllers/environment_controller.gd")
const BalloonSpawnerControllerClass = preload("res://src/controllers/balloon_spawner_controller.gd")
const GameStateControllerClass = preload("res://src/controllers/game_state_controller.gd")
const GodModeControllerClass = preload("res://src/controllers/god_mode_controller.gd")

@onready var game_manager: Node = $GameManager
@onready var sound_manager: Node = $SoundManager
@onready var shop_manager: Node = $ShopManager
@onready var save_manager: Node = $SaveManager
@onready var room_controller: Node = $RoomController
@onready var device_placement: Node = $DevicePlacementController
@onready var shop_ui: Node = $ShopUIController
@onready var theme_controller: ThemeController = get_node_or_null("ThemeController")
@onready var player: CharacterBody3D = $Player
@onready var balloon_container: Node3D = $BalloonContainer
@onready var coin_container: Node3D = $CoinContainer

var bonus_controller: Node
var quest_manager: Node
var quest_ui: Control
var tablet_notification_manager: TabletNotificationManager = null

# Automation Devices (Delegated to DevicePlacementController)
var active_placed_devices: Array[Node3D]:
	get:
		return device_placement.active_placed_devices if device_placement else _active_placed_devices
	set(val):
		if device_placement:
			device_placement.active_placed_devices = val
		else:
			_active_placed_devices = val
var _active_placed_devices: Array[Node3D] = []

var carried_device: Node3D:
	get:
		return device_placement.carried_device if device_placement else null
	set(val):
		if device_placement:
			device_placement.carried_device = val

var corner_fan: Node3D = null
var electric_wall: Node3D = null
var spike_wall: Node3D = null
var magnet_pylon: Node3D = null
var conveyor_crusher: Node3D = null
var sentry_drone: Node3D = null

# Environment Nodes for Dynamic Room Expansion
@onready var env_main_room: Node3D = $Environment/MainRoom
@onready var floor_body: StaticBody3D = $Environment/MainRoom/Floor
@onready var floor_mesh: MeshInstance3D = $Environment/MainRoom/Floor/MeshInstance3D
@onready var floor_shape: CollisionShape3D = $Environment/MainRoom/Floor/CollisionShape3D

@onready var ceiling_body: StaticBody3D = $Environment/MainRoom/Ceiling
@onready var ceiling_mesh: MeshInstance3D = $Environment/MainRoom/Ceiling/MeshInstance3D
@onready var ceiling_shape: CollisionShape3D = $Environment/MainRoom/Ceiling/CollisionShape3D

@onready var wall_north_body: StaticBody3D = $Environment/MainRoom/WallNorth
@onready var wall_north_mesh: MeshInstance3D = $Environment/MainRoom/WallNorth/MeshInstance3D
@onready var wall_north_shape: CollisionShape3D = $Environment/MainRoom/WallNorth/CollisionShape3D

@onready var wall_south_body: StaticBody3D = $Environment/MainRoom/WallSouth
@onready var wall_south_mesh: MeshInstance3D = $Environment/MainRoom/WallSouth/MeshInstance3D
@onready var wall_south_shape: CollisionShape3D = $Environment/MainRoom/WallSouth/CollisionShape3D

@onready var wall_west_body: StaticBody3D = $Environment/MainRoom/WallWest
@onready var wall_west_mesh: MeshInstance3D = $Environment/MainRoom/WallWest/MeshInstance3D
@onready var wall_west_shape: CollisionShape3D = $Environment/MainRoom/WallWest/CollisionShape3D

@onready var wall_east_body: StaticBody3D = $Environment/MainRoom/WallEast
@onready var wall_east_mesh: MeshInstance3D = $Environment/MainRoom/WallEast/MeshInstance3D
@onready var wall_east_shape: CollisionShape3D = $Environment/MainRoom/WallEast/CollisionShape3D

@onready var ceiling_vents_container: Node3D = get_node_or_null("Environment/MainRoom/CeilingVents")
@onready var main_room_light: OmniLight3D = get_node_or_null("MainRoomLight")

var modal_manager: Node = null
var hud_controller: Node = null
var interaction_controller: Node = null
var environment_controller: Node = null
var spawner_controller: Node = null
var game_state_controller: Node = null
var god_mode_controller: Node = null

var is_blackout: bool:
	get: return environment_controller.is_blackout if environment_controller else false
	set(val):
		if environment_controller: environment_controller.is_blackout = val

var _overpressure_hazard_timer: float = 0.0
var blackout_cooldown_timer: float = 0.0

# Backward compatibility proxies for HUD & Modals
var startup_modal: Control:
	get: return modal_manager.startup_modal if modal_manager else null
var pause_modal: Control:
	get: return modal_manager.pause_modal if modal_manager else null
var victory_modal: Control:
	get: return modal_manager.victory_modal if modal_manager else null
var desk_prompt: Label:
	get: return hud_controller.desk_prompt if hud_controller else null

var current_pressure_ratio: float:
	get: return hud_controller.current_pressure_ratio if hud_controller else 0.0
	set(val):
		if hud_controller: hud_controller.current_pressure_ratio = val
var _was_overpressure_critical: bool:
	get: return hud_controller.was_overpressure_critical if hud_controller else false
	set(val):
		if hud_controller: hud_controller.was_overpressure_critical = val

var vent_chute_counter: int:
	get: return spawner_controller.vent_chute_counter if spawner_controller else 0
	set(val):
		if spawner_controller: spawner_controller.vent_chute_counter = val
var fps_update_timer: float = 0.0

# Speedrun & Playtime Tracking
var playtime_seconds: float = 0.0
var best_speedrun_time: float = 0.0

var highlighted_balloon: Node = null
var is_victory_shown: bool = false

# Theme Selector Modal
@onready var theme_modal: Control = get_node_or_null("UI/ThemeModal")

# Shop UI Modal Proxies
var shop_modal: Control:
	get: return shop_ui.shop_modal if shop_ui else null
var shop_coins_label: Label:
	get: return shop_ui.shop_coins_label if shop_ui else null
var btn_close_shop: Button:
	get: return shop_ui.btn_close_shop if shop_ui else null
var upgrades_container: GridContainer:
	get: return shop_ui.upgrades_container if shop_ui else null

var btn_tier_1: Button:
	get: return shop_ui.btn_tier_1 if shop_ui else null
var btn_tier_2: Button:
	get: return shop_ui.btn_tier_2 if shop_ui else null
var btn_tier_3: Button:
	get: return shop_ui.btn_tier_3 if shop_ui else null
var btn_tier_all: Button:
	get: return shop_ui.btn_tier_all if shop_ui else null

var btn_tab_all: Button:
	get: return shop_ui.btn_tab_all if shop_ui else null
var btn_tab_upgrades: Button:
	get: return shop_ui.btn_tab_upgrades if shop_ui else null
var btn_tab_devices: Button:
	get: return shop_ui.btn_tab_devices if shop_ui else null
var btn_tab_rooms: Button:
	get: return shop_ui.btn_tab_rooms if shop_ui else null
var lbl_room_device_cap: Label:
	get: return shop_ui.lbl_room_device_cap if shop_ui else null

# 3D Gravity Terminal (Removed from physical room)
@onready var gravity_terminal: Node3D = get_node_or_null("Environment/GravityTerminal")
@onready var gravity_display_label: Label3D = get_node_or_null("Environment/GravityTerminal/DisplayLabel")
@onready var gravity_btn_mesh: MeshInstance3D = get_node_or_null("Environment/GravityTerminal/ButtonMesh")

var is_near_grav_terminal: bool = false
var raycast_target_type: String:
	get: return interaction_controller.raycast_target_type if interaction_controller else ""
	set(val):
		if interaction_controller: interaction_controller.raycast_target_type = val
var raycast_target_device: Node3D:
	get: return interaction_controller.raycast_target_device if interaction_controller else null
	set(val):
		if interaction_controller: interaction_controller.raycast_target_device = val
var raycast_target_name: String:
	get: return interaction_controller.raycast_target_name if interaction_controller else ""
	set(val):
		if interaction_controller: interaction_controller.raycast_target_name = val
var nearby_device: Node3D:
	get: return interaction_controller.nearby_device if interaction_controller else null
	set(val):
		if interaction_controller: interaction_controller.nearby_device = val


var current_tier: int:
	get:
		return shop_ui.current_tier if shop_ui else 1
	set(val):
		if shop_ui:
			shop_ui.current_tier = val

var current_filter: String:
	get:
		return shop_ui.current_filter if shop_ui else "all"
	set(val):
		if shop_ui:
			shop_ui.current_filter = val

var tier_user_selected: bool:
	get:
		return shop_ui.tier_user_selected if shop_ui else false
	set(val):
		if shop_ui:
			shop_ui.tier_user_selected = val
var auto_save_timer: float = 0.0
var debug_panel: Control = null
var debug_tier_weights: Dictionary = {
	50: 0.05,
	10: 0.20,
	5: 0.40,
	1: 0.35
}
var is_loading_save: bool = false

var balloon_gravity_scales: Array[float]:
	get:
		return room_controller.balloon_gravity_scales if room_controller else [0.25, 0.80, 1.80, 3.50, 6.00]
var balloon_linear_damps: Array[float]:
	get:
		return room_controller.balloon_linear_damps if room_controller else [2.2, 1.4, 0.8, 0.35, 0.15]
var gravity_mode_names: Array[String]:
	get:
		return room_controller.gravity_mode_names if room_controller else [
			"0.25 G (Standart Süzülme)",
			"0.80 G (Ağır Döküm)",
			"1.80 G (Hızlı Şelale)",
			"3.50 G (Ağır Çöküş)",
			"6.00 G (Hiper Yerçekimi)"
		]

var current_gravity_idx: int:
	get:
		return room_controller.current_gravity_idx if room_controller else _current_gravity_idx
	set(val):
		_current_gravity_idx = val
		if room_controller:
			room_controller.current_gravity_idx = val
var _current_gravity_idx: int = 0

var max_unlocked_gravity_idx: int:
	get:
		return room_controller.max_unlocked_gravity_idx if room_controller else 0
	set(val):
		if room_controller:
			room_controller.max_unlocked_gravity_idx = val

func apply_gravity_to_active_balloons() -> void:
	if room_controller:
		room_controller.apply_gravity_to_active_balloons()

func update_gravity_terminal_display() -> void:
	if room_controller:
		room_controller.update_gravity_terminal_display()

func cycle_gravity_mode() -> void:
	if room_controller:
		room_controller.cycle_gravity_mode()

var factory: Node3D

func _ready() -> void:
	Engine.max_fps = 60
	Engine.physics_ticks_per_second = 60
	bonus_controller = preload("res://src/core/bonus_controller.gd").new()
	bonus_controller.name = "BonusController"
	add_child(bonus_controller)
	var legacy_fan = get_node_or_null("Environment/CornerFan")
	if legacy_fan: legacy_fan.queue_free()
	var legacy_fan_room = get_node_or_null("Environment/MainRoom/CornerFan")
	if legacy_fan_room: legacy_fan_room.queue_free()
	if corner_fan and is_instance_valid(corner_fan):
		corner_fan.queue_free()
		corner_fan = null

	quest_manager = preload("res://src/core/quest_manager.gd").new()
	quest_manager.name = "QuestManager"
	add_child(quest_manager)
	
	var canvas_layer = CanvasLayer.new()
	canvas_layer.name = "QuestCanvasLayer"
	canvas_layer.layer = 100 # Always on top
	add_child(canvas_layer)
	
	quest_ui = preload("res://src/ui/quest_ui.gd").new()
	quest_ui.name = "QuestUI"
	canvas_layer.add_child(quest_ui)
	quest_ui.setup(quest_manager)
	
	quest_manager.quest_completed.connect(func(_reward: int):
		if sound_manager and sound_manager.has_method("play_quest_complete"):
			sound_manager.play_quest_complete()
		if environment_controller and environment_controller.has_method("trigger_quest_celebration"):
			environment_controller.trigger_quest_celebration()
	)
	
	tablet_notification_manager = TabletNotificationManager.new()
	tablet_notification_manager.name = "TabletNotificationManager"
	add_child(tablet_notification_manager)
	tablet_notification_manager.setup(self)
		
	if game_manager:
		game_manager.pop_registered.connect(_on_pop_registered)
		game_manager.spawn_requested.connect(_on_spawn_requested)
		game_manager.active_count_changed.connect(_on_active_count_changed)
		
	if player:
		if player.has_signal("pop_triggered"):
			player.pop_triggered.connect(_on_player_pop_triggered)
		if player.has_signal("nudge_triggered"):
			player.nudge_triggered.connect(_on_player_nudge_triggered)
		if player.has_signal("energy_changed"):
			player.energy_changed.connect(_on_player_energy_changed)
		if player.has_signal("macro_toggled"):
			player.macro_toggled.connect(_on_player_macro_toggled)
		
	if shop_manager:
		shop_manager.coins_changed.connect(_on_coins_changed)
		shop_manager.purchase_failed.connect(func(_reason: String): _market_sound("denied"))
		shop_manager.device_purchased.connect(func(_id: String, _level: int): _market_sound("confirm"))
		shop_manager.room_transfer_requested.connect(func(_id: String): _market_sound("confirm"))
		shop_manager.upgrade_purchased.connect(_on_upgrade_purchased)
		shop_manager.room_switched.connect(_on_room_switched)
		if shop_manager.has_signal("device_unit_purchased"):
			shop_manager.device_unit_purchased.connect(_on_device_unit_purchased)
		shop_manager.device_purchased.connect(_on_device_tech_upgraded)
		
	process_mode = Node.PROCESS_MODE_ALWAYS
	var ui_node = get_node_or_null("UI")
	if ui_node:
		ui_node.process_mode = Node.PROCESS_MODE_ALWAYS

	# Strictly enforce PAUSABLE mode on all gameplay trees and managers so pause freezes them
	if game_manager: game_manager.process_mode = Node.PROCESS_MODE_PAUSABLE
	if player: player.process_mode = Node.PROCESS_MODE_PAUSABLE
	if balloon_container: balloon_container.process_mode = Node.PROCESS_MODE_PAUSABLE
	if coin_container: coin_container.process_mode = Node.PROCESS_MODE_PAUSABLE
	if sound_manager: sound_manager.process_mode = Node.PROCESS_MODE_PAUSABLE
	var env_node = get_node_or_null("Environment")
	if env_node: env_node.process_mode = Node.PROCESS_MODE_PAUSABLE

	if room_controller:
		room_controller.setup(self)
		room_controller.prompt_requested.connect(func(msg: String):
			if desk_prompt:
				desk_prompt.text = msg
				desk_prompt.visible = true
		)
		room_controller.save_requested.connect(save_current_data)

	if device_placement:
		device_placement.setup(self)
		device_placement.prompt_requested.connect(func(msg: String):
			if desk_prompt:
				desk_prompt.text = msg
				desk_prompt.visible = true
		)
		device_placement.save_requested.connect(save_current_data)
		device_placement.shop_refresh_requested.connect(func():
			if shop_modal and shop_modal.visible:
				update_all_shop_cards()
		)
		device_placement.close_shop_requested.connect(func():
			if shop_modal and shop_modal.visible:
				toggle_shop_modal()
		)

	factory = preload("res://src/controllers/factory_controller.gd").new()
	factory.name = "FactoryController"
	add_child(factory)
	factory.setup(self)

	if shop_ui:
		shop_ui.setup(self)
		shop_ui.save_requested.connect(save_current_data)

	if theme_controller:
		theme_controller.setup(self)

	hud_controller = HUDControllerClass.new()
	hud_controller.name = "HUDController"
	add_child(hud_controller)
	hud_controller.setup(self)
	hud_controller.overpressure_relieved.connect(_on_overpressure_relieved)

	modal_manager = ModalManagerClass.new()
	modal_manager.name = "ModalManager"
	add_child(modal_manager)
	modal_manager.setup(self)
	modal_manager.resume_requested.connect(toggle_pause_modal)
	modal_manager.restart_requested.connect(_on_pause_restart_pressed)
	modal_manager.quit_requested.connect(_on_pause_quit_pressed)
	modal_manager.continue_game_requested.connect(_on_continue_pressed)
	modal_manager.new_game_requested.connect(_on_new_game_pressed)
	modal_manager.prestige_requested.connect(_on_prestige_pressed)
	modal_manager.new_run_requested.connect(_on_new_run_from_victory)
	interaction_controller = InteractionControllerClass.new()
	interaction_controller.name = "InteractionController"
	add_child(interaction_controller)
	interaction_controller.setup(self)
	interaction_controller.prompt_text_updated.connect(func(text: String, is_vis: bool):
		if desk_prompt:
			desk_prompt.text = text
			desk_prompt.visible = is_vis
	)
	interaction_controller.start_carry_device_requested.connect(start_carrying_device)
	interaction_controller.upgrade_device_requested.connect(upgrade_specific_device)
	interaction_controller.restore_power_requested.connect(restore_power)

	environment_controller = EnvironmentControllerClass.new()
	environment_controller.name = "EnvironmentController"
	add_child(environment_controller)
	environment_controller.setup(self)
	spawner_controller = BalloonSpawnerControllerClass.new()
	spawner_controller.name = "BalloonSpawnerController"
	add_child(spawner_controller)
	spawner_controller.setup(self)

	game_state_controller = GameStateControllerClass.new()
	game_state_controller.name = "GameStateController"
	add_child(game_state_controller)
	game_state_controller.setup(self)

	god_mode_controller = GodModeControllerClass.new()
	god_mode_controller.name = "GodModeController"
	add_child(god_mode_controller)
	god_mode_controller.setup(self)

	update_ceiling_vents()
	if override_initial_room != "":
		if modal_manager: modal_manager.hide_startup_modal()
		game_state_controller.load_room_preset(override_initial_room)
	else:
		setup_startup_modal()
	
	# Setup In-Game Live Debug & Tuning Panel
	var debug_script = load("res://src/ui/debug_panel.gd")
	if debug_script:
		debug_panel = debug_script.new()
		if ui_node:
			ui_node.add_child(debug_panel)
		else:
			add_child(debug_panel)

func toggle_pause_modal() -> void:
	if not modal_manager: return
	var p_str = format_number(game_manager.total_pops) if game_manager else "0"
	var c_str = format_number(shop_manager.coins) if shop_manager else "0"
	var pps_str = "%.1f" % game_manager.current_pps if (game_manager and "current_pps" in game_manager) else "0.0"
	var stats_text = "Geçen Süre: %s  |  %s Pop  |  %s Coin  |  Hız: %s Pop/sn" % [format_time(playtime_seconds), p_str, c_str, pps_str]
	var is_paused = modal_manager.toggle_pause_modal(stats_text)
	if player and player.has_method("set_ui_open"):
		player.set_ui_open(is_paused)
	if not is_paused:
		save_current_data()

func _on_pause_resume_pressed() -> void:
	toggle_pause_modal()

func _on_pause_restart_pressed() -> void:
	if modal_manager:
		modal_manager.hide_pause_modal()
	start_new_game()

func _on_pause_quit_pressed() -> void:
	save_current_data()
	get_tree().quit()

func _on_new_run_from_victory() -> void:
	if modal_manager:
		modal_manager.hide_victory_modal()
	start_new_game()

func _on_prestige_pressed() -> void:
	if game_state_controller:
		game_state_controller.perform_prestige()

func format_time(seconds_val: float) -> String:
	var total_sec = int(seconds_val)
	var hrs = total_sec / 3600
	var mins = (total_sec % 3600) / 60
	var secs = total_sec % 60
	return "%02d:%02d:%02d" % [hrs, mins, secs]

func format_eta(seconds_val: float) -> String:
	if seconds_val < 0.0:
		return "--"
	if seconds_val <= 0.0:
		return "Tamamlandı"
	var total_sec = int(seconds_val)
	if total_sec < 60:
		return "~%d sn" % total_sec
	elif total_sec < 3600:
		var mins = int(total_sec / 60)
		return "~%d dk" % mins
	else:
		var hrs = int(total_sec / 3600)
		var mins = int((total_sec % 3600) / 60)
		if mins > 0:
			return "~%d sa %d dk" % [hrs, mins]
		else:
			return "~%d sa" % hrs

func show_victory_screen(restored_from_save: bool = false) -> void:
	is_victory_shown = true
	if room_controller and room_controller.has_method("open_exit_door"):
		room_controller.open_exit_door()
	var is_new_record = false
	if not restored_from_save and (best_speedrun_time <= 0.0 or playtime_seconds < best_speedrun_time):
		best_speedrun_time = playtime_seconds
		is_new_record = true
	var production_multiplier: int = game_manager.turbo_speed_multiplier if game_manager and game_manager.turbo_mode_enabled else 1
	var progress_multiplier: int = game_manager.turbo_pop_multiplier if game_manager and game_manager.turbo_mode_enabled else 1
	var coin_multiplier: int = game_manager.turbo_coin_multiplier if game_manager and game_manager.turbo_mode_enabled else 1
	var normalized_time := playtime_seconds * float(production_multiplier * progress_multiplier * coin_multiplier)
	var room_data: Dictionary = shop_manager.get_current_room_data() if shop_manager else {}
	var room_name := str(room_data.get("name", "Bilinmiyor")).split(" (")[0]
	var unlocked_room_count: int = shop_manager.unlocked_rooms.size() if shop_manager else 1
	var mode_name := "Üretim ×%d • İlerleme ×%d • Para ×%d" % [production_multiplier, progress_multiplier, coin_multiplier]
	var god_mode_name := "Açık" if god_mode_controller and god_mode_controller.enabled else "Kapalı"
	var run_stats := "İlerleme puanı: %s   •   Gerçek patlatma: %s\n" % [format_number(game_manager.total_pops if game_manager else 0), format_number(game_manager.actual_balloon_pops if game_manager else 0)]
	run_stats += "Üretilen balon: %s   •   Son oda: %s (%d / %d)   •   Coin: %s\n" % [format_number(game_manager.actual_spawn_total if game_manager else 0), room_name, unlocked_room_count, shop_manager.rooms.size() if shop_manager else 3, format_number(shop_manager.coins if shop_manager else 0)]
	run_stats += "En yüksek patlatma: %.1f / sn   •   Test: %s, God Mode %s" % [game_manager.peak_pps if game_manager else 0.0, mode_name, god_mode_name]
	if production_multiplier > 1 or progress_multiplier > 1 or coin_multiplier > 1:
		run_stats += "\n×1 test hızı tahmini: ~%s (yaklaşık; çarpanlar ayrı etkiler)" % format_time(normalized_time)
	
	if modal_manager:
		modal_manager.show_victory_modal(format_time(playtime_seconds), format_time(best_speedrun_time), is_new_record, run_stats)
	if player and player.has_method("set_ui_open"):
		player.set_ui_open(true)
	if not restored_from_save:
		if sound_manager and sound_manager.has_method("play_victory_fanfare"):
			sound_manager.play_victory_fanfare()
		elif sound_manager and sound_manager.has_method("play_gold_pop"):
			sound_manager.play_gold_pop()
		if environment_controller and environment_controller.has_method("trigger_quest_celebration"):
			environment_controller.trigger_quest_celebration()
		save_current_data()
	get_tree().paused = true

func trigger_blackout(cause_is_overpressure: bool = false) -> void:
	if environment_controller:
		environment_controller.trigger_blackout(cause_is_overpressure)

func restore_power() -> void:
	if environment_controller:
		environment_controller.restore_power()

func setup_startup_modal() -> void:
	if modal_manager:
		modal_manager.setup_startup_modal(save_manager, shop_manager)

func _on_continue_pressed() -> void:
	if modal_manager:
		modal_manager.hide_startup_modal()
		
	var target_room = "small_room"
	if save_manager:
		var state = save_manager.load_full_state()
		target_room = state.get("current_room", "small_room")
		
		# Legacy room name compatibility
		if target_room == "large_room": target_room = "medium_room"
		elif target_room == "warehouse": target_room = "hangar"
		if shop_manager and not shop_manager.rooms.has(target_room):
			target_room = "small_room"
		
	# 1. First resize the room so the floor and office are in their correct world positions
	apply_room_layout(target_room)
	# 2. Then load saved data and restore player onto the properly positioned floor
	load_saved_data()
	update_all_shop_cards()
	
	if player and player.has_method("set_ui_open"):
		player.set_ui_open(false)
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	
	if game_manager:
		game_manager.start_game()
		_on_active_count_changed(game_manager.active_balloons, game_manager.max_room_balloons)

func _on_new_game_pressed() -> void:
	if modal_manager:
		modal_manager.hide_startup_modal()
	start_new_game()

func start_new_game() -> void:
	if game_state_controller:
		game_state_controller.start_new_game()

func apply_room_layout(room_id: String) -> void:
	# Keep room-dependent controllers (factory, HUD and devices) in sync with
	# the layout being built. Continue can request a saved room before the
	# shop state has been restored, so relying on current_room here builds the
	# factory bay with stale dimensions.
	if shop_manager and shop_manager.rooms.has(room_id):
		shop_manager.current_room = room_id
	if room_controller:
		room_controller.apply_room_layout(room_id)
	if spawner_controller and is_instance_valid(spawner_controller):
		spawner_controller.normalize_live_balloon_tiers()
		
	# Update HUD Signboard
	if game_manager:
		_on_active_count_changed(game_manager.active_balloons, game_manager.max_room_balloons)

func update_ceiling_vents() -> void:
	if room_controller:
		room_controller.update_ceiling_vents()

func _on_room_switched(room_id: String) -> void:
	if device_placement and device_placement.is_carrying(): device_placement.cancel_carrying_device()
	apply_room_layout(room_id)
	update_all_shop_cards()
	if player and is_instance_valid(player):
		player.velocity = Vector3.ZERO
		var half_length: float = shop_manager.get_current_room_data().floor_size.y * 0.5
		player.global_position = Vector3(2.1, 0.6, half_length - 3.0)
		player.rotation.y = PI
		player.head.rotation.x = 0.0
	save_current_data()

func _on_device_unit_purchased(device_id: String, _new_count: int, level: int) -> void:
	if device_id == "gravity_regulator":
		max_unlocked_gravity_idx = room_controller.balloon_gravity_scales.size() - 1
		if current_gravity_idx > max_unlocked_gravity_idx:
			current_gravity_idx = max_unlocked_gravity_idx
		apply_gravity_to_active_balloons()
		update_all_shop_cards()
		save_current_data()
	elif factory:
		# A unit purchase always creates a delivery order. Placement starts only
		# when the player takes and unpacks that order at the service bay.
		factory.order(device_id, level)
		update_all_shop_cards()
		if shop_modal and shop_modal.visible:
			toggle_shop_modal()

func _on_device_tech_upgraded(device_id: String, level: int) -> void:
	if device_id == "gravity_regulator":
		max_unlocked_gravity_idx = room_controller.balloon_gravity_scales.size() - 1
		if current_gravity_idx > max_unlocked_gravity_idx:
			current_gravity_idx = max_unlocked_gravity_idx
		apply_gravity_to_active_balloons()
		update_all_shop_cards()
		save_current_data()
	elif device_placement:
		device_placement.on_device_tech_upgraded(device_id, level)

func _on_device_purchased(device_id: String, level: int, from_shop_ui: bool = false) -> void:
	_on_device_tech_upgraded(device_id, level)

func _on_active_count_changed(active: int, max_cap: int) -> void:
	if hud_controller and game_manager:
		hud_controller.update_pressure(game_manager.get_total_effective_balloons(), game_manager.max_room_balloons, game_manager.get_physical_balloon_count())

func _on_overpressure_relieved() -> void:
	var cap = game_manager.max_room_balloons if game_manager else 500
	var room_mult = 1.0
	if shop_manager and shop_manager.has_method("get_current_room_data"):
		room_mult = shop_manager.get_current_room_data().get("coin_multiplier", 1.0)
	
	# Dynamic reward: scales meaningfully with room tier and capacity (min 350, scales up to tens of thousands)
	var bonus_coin = maxi(350, int(round(float(cap) * 0.75 * room_mult)))
	
	if shop_manager and shop_manager.has_method("add_coins"):
		shop_manager.add_coins(bonus_coin)
	if sound_manager and sound_manager.has_method("play_gold_pop"):
		sound_manager.play_gold_pop()
	if hud_controller:
		hud_controller.show_prompt("+%d 🪙 Basınç Tahliyesi Başarılı!" % bonus_coin, 2.5)

func _process(delta: float) -> void:
	if (startup_modal and startup_modal.visible) or get_tree().paused:
		return
		
	# Playtime Timer Tracking (Clean, concise)
	playtime_seconds += delta
	if hud_controller:
		hud_controller.update_playtime(format_time(playtime_seconds))
		
	# Floor Level Guard: Player can never sink below floor y = 0.0
	if player and is_instance_valid(player) and player.global_position.y < -0.05:
		player.velocity.y = max(0.0, player.velocity.y)
		player.global_position.y = 0.05
		
	auto_save_timer += delta
	if auto_save_timer >= 30.0:
		auto_save_timer = 0.0
		save_current_data()
		
	# Overpressure Hazard & Blackout (Geçici olarak devre dışı bırakıldı)
	# if blackout_cooldown_timer > 0.0:
	# 	blackout_cooldown_timer = max(0.0, blackout_cooldown_timer - delta)
	# 	_overpressure_hazard_timer = 0.0
	# elif not is_blackout and game_manager:
	# 	var pressure_ratio: float = game_manager.get_pressure_ratio()
	# 	if pressure_ratio >= 0.90:
	# 		_overpressure_hazard_timer += delta
	# 		var remaining_sec = int(ceil(10.0 - _overpressure_hazard_timer))
	# 		if hud_controller and remaining_sec > 0:
	# 			hud_controller.show_prompt("⚠️ KRİTİK BASINÇ (%%%d)! Vana Patlamasına: %d sn (Balonları Patlat!)" % [int(pressure_ratio * 100), remaining_sec], 0.3)
	# 		if _overpressure_hazard_timer >= 10.0:
	# 			_overpressure_hazard_timer = 0.0
	# 			trigger_blackout(true)
	# 	else:
	# 		_overpressure_hazard_timer = max(0.0, _overpressure_hazard_timer - delta * 2.0)
	_overpressure_hazard_timer = 0.0
			
	if spawner_controller:
		spawner_controller.update_pile_optimization(delta)
		
	# 1. Carrying / Grid Placement Active (Delegated to DevicePlacementController)
	if device_placement and device_placement.update_placement_process(delta):
		return
		
	# 2. Precision Raycast Targeting (Aim directly with crosshair to interact from distance)
	if factory and factory.update_prompt():
		return
	update_raycast_interaction()

func update_raycast_interaction() -> void:
	if interaction_controller:
		interaction_controller.update_interaction()

func save_current_data() -> void:
	if game_state_controller:
		game_state_controller.save_current_data()

func load_saved_data() -> void:
	if game_state_controller:
		game_state_controller.load_saved_data()

func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_CLOSE_REQUEST:
		save_current_data()

func _on_spawn_requested(count: int) -> void:
	if get_tree().paused:
		return
	drop_balloons_from_vent(count)

func _input(event: InputEvent) -> void:
	if startup_modal and startup_modal.visible:
		return
	if event is InputEventKey and event.pressed and not event.is_echo() and event.keycode == KEY_G:
		if god_mode_controller:
			god_mode_controller.toggle_menu()
		get_viewport().set_input_as_handled()
		return
	if event is InputEventKey and event.pressed and not event.is_echo() and event.keycode == KEY_ESCAPE and god_mode_controller and god_mode_controller.menu_open:
		god_mode_controller.cancel_menu()
		get_viewport().set_input_as_handled()
		return
		
	# 1. When carrying a device (Delegated to DevicePlacementController)
	if device_placement and device_placement.handle_input(event):
		get_viewport().set_input_as_handled()
		return
				
	# 2. Normal Interactions (Raycast crosshair aiming & distance reach)
	if event is InputEventKey and event.pressed and not event.is_echo():
		if event.keycode == KEY_TAB:
			if get_tree().paused or (victory_modal and victory_modal.visible):
				return
			toggle_shop_modal()
			get_viewport().set_input_as_handled()
			return
		elif event.keycode == KEY_E:
			if player.is_ui_open:
				return
			if factory and factory.target != "":
				factory.interact(factory.target)
				get_viewport().set_input_as_handled()
				return
			if interaction_controller and interaction_controller.handle_key_action("interact"):
				get_viewport().set_input_as_handled()
				return
		elif event.keycode == KEY_F:
			if player.is_ui_open:
				return
			if interaction_controller and interaction_controller.handle_key_action("upgrade"):
				get_viewport().set_input_as_handled()
				return
		elif event.keycode == KEY_F1 or event.keycode == KEY_F2 or event.keycode == KEY_QUOTELEFT:
			toggle_debug_panel()
			get_viewport().set_input_as_handled()
		elif event.keycode == KEY_ESCAPE:
			if modal_manager and modal_manager.handle_escape_key():
				get_viewport().set_input_as_handled()

func toggle_theme_modal() -> void:
	if theme_controller:
		theme_controller.toggle_theme_modal()

func toggle_debug_panel() -> void:
	if not debug_panel: return
	debug_panel.toggle_panel()
	if player and player.has_method("set_ui_open"):
		player.set_ui_open(debug_panel.visible)

func upgrade_gravity_terminal() -> void:
	if room_controller:
		room_controller.upgrade_gravity_terminal()

func upgrade_specific_device(d_node: Node3D) -> void:
	if device_placement:
		device_placement.upgrade_specific_device(d_node)
	update_raycast_interaction()

func start_carrying_device(device_target: Variant, is_new: bool = false, purchase_cost: int = 0) -> void:
	if device_placement:
		device_placement.start_carrying_device(device_target, is_new, purchase_cost)

func place_carried_device() -> void:
	if device_placement:
		device_placement.place_carried_device()

func cancel_carrying_device() -> void:
	if device_placement:
		device_placement.cancel_carrying_device()

func toggle_shop_modal() -> void:
	if shop_ui:
		shop_ui.toggle_shop_modal()

func set_tier_filter(tier_num: int) -> void:
	if shop_ui:
		shop_ui.set_tier_filter(tier_num)

func set_category_filter(filter_name: String) -> void:
	if shop_ui:
		shop_ui.set_category_filter(filter_name)

func _on_coins_changed(total_coins: int) -> void:
	if hud_controller and game_manager and shop_manager:
		hud_controller.update_pop_counter(game_manager.total_pops, game_manager.pops_per_second, shop_manager.prestige_level, total_coins, game_manager.turbo_pop_multiplier if game_manager.turbo_mode_enabled else 1, game_manager.turbo_coin_multiplier if game_manager.turbo_mode_enabled else 1)
	if shop_coins_label:
		var coin_multiplier: int = game_manager.turbo_coin_multiplier if game_manager and game_manager.turbo_mode_enabled else 1
		shop_coins_label.text = "Coin: " + format_number(total_coins * maxi(1, coin_multiplier)) + " 🎈"
	update_all_shop_cards()

func _on_upgrade_purchased(upgrade_id: String, level: int) -> void:
	if player and is_instance_valid(player) and player.has_method("apply_upgrade"):
		player.apply_upgrade(upgrade_id, level)
	update_all_shop_cards()
	if upgrade_id == "pipe_count":
		update_ceiling_vents()
	elif upgrade_id == "companion_drone":
		_update_companion_drone_level(level)
	elif upgrade_id == "fan" and corner_fan:
		corner_fan.visible = true
		corner_fan.set("is_active", true)
	if not is_loading_save:
		save_current_data()

func _update_companion_drone_level(lvl: int) -> void:
	if lvl <= 0:
		if sentry_drone and is_instance_valid(sentry_drone):
			sentry_drone.queue_free()
			sentry_drone = null
		return
		
	if not sentry_drone or not is_instance_valid(sentry_drone):
		var drone_scene = DEVICE_SCENES.get("sentry_drone")
		if drone_scene:
			sentry_drone = drone_scene.instantiate()
			add_child(sentry_drone)
	if sentry_drone and is_instance_valid(sentry_drone):
		if sentry_drone.has_method("setup_level"):
			sentry_drone.setup_level(lvl)
		else:
			sentry_drone.set("level", lvl)

func update_all_shop_cards() -> void:
	if shop_ui:
		shop_ui.request_refresh()

func _on_player_pop_triggered(is_hit: bool) -> void:
	if hud_controller: hud_controller.pulse_crosshair(is_hit)

func _on_player_nudge_triggered() -> void:
	if hud_controller: hud_controller.pulse_crosshair_nudge()

func _on_player_energy_changed(current: float, max_energy: float, is_exhausted: bool) -> void:
	if hud_controller: hud_controller.update_stamina(current, max_energy, is_exhausted)

func _on_player_macro_toggled(is_active: bool) -> void:
	if hud_controller:
		hud_controller.update_macro_badge(is_active)
		hud_controller.show_prompt("Makro: " + ("Açık [Z]" if is_active else "Kapalı [Z]"), 2.0)

func format_number(val: int) -> String:
	return hud_controller.format_number(val) if hud_controller else str(val)

func update_pop_counter(pops: int) -> void:
	if hud_controller:
		var pps = game_manager.pops_per_second if (game_manager and "pops_per_second" in game_manager) else 0
		var prest = shop_manager.prestige_level if shop_manager else 0
		var coins = shop_manager.coins if shop_manager else 0
		hud_controller.update_pop_counter(pops, pps, prest, coins, game_manager.turbo_pop_multiplier if game_manager and game_manager.turbo_mode_enabled else 1, game_manager.turbo_coin_multiplier if game_manager and game_manager.turbo_mode_enabled else 1)
		
	if pops >= 1000000 and not is_victory_shown:
		show_victory_screen()

func drop_balloons_from_vent(count: int) -> void:
	if spawner_controller:
		spawner_controller.drop_balloons_from_vent(count)

func spawn_floor_coin(pop_pos: Vector3, val: int = 1, tier: int = 1) -> void:
	if spawner_controller:
		spawner_controller.spawn_floor_coin(pop_pos, val, tier)

func _on_pop_registered(total: int) -> void:
	update_pop_counter(total)

func _on_balloon_popped_visual(pos: Vector3, combo: int, b_type: int, spec_type: String = "normal") -> void:
	if spawner_controller:
		spawner_controller.show_pop_visual(pos, combo, b_type, spec_type)

func _device_save_position(dev: Node3D) -> Array:
	var pos: Vector3 = device_placement.carried_original_pos if dev == carried_device else dev.position
	return [pos.x, pos.y, pos.z]

func _market_sound(kind: String) -> void:
	if not is_loading_save and sound_manager and player:
		sound_manager.play_interaction(kind, player.global_position)
