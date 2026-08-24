extends Node3D

@export var balloon_scene: PackedScene = preload("res://scenes/balloon.tscn")
@export var coin_scene: PackedScene = preload("res://scenes/coin.tscn")

const DEVICE_SCENES = {
	"spike_wall": preload("res://scenes/spike_wall.tscn"),
	"electric_wall": preload("res://scenes/electric_wall.tscn"),
	"magnet_pylon": preload("res://scenes/magnet_pylon.tscn"),
	"conveyor_crusher": preload("res://scenes/conveyor_crusher.tscn"),
	"sentry_drone": preload("res://scenes/sentry_drone.tscn"),
	"fan": preload("res://scenes/fan.tscn")
}

@onready var game_manager: Node = $GameManager
@onready var sound_manager: Node = $SoundManager
@onready var shop_manager: Node = $ShopManager
@onready var save_manager: Node = $SaveManager
@onready var player: CharacterBody3D = $Player
@onready var balloon_container: Node3D = $BalloonContainer
@onready var coin_container: Node3D = $CoinContainer

# Automation Devices (Instantiated dynamically in multiples)
var active_placed_devices: Array[Node3D] = []
var corner_fan: Node3D = null
var electric_wall: Node3D = null
var spike_wall: Node3D = null
var magnet_pylon: Node3D = null
var conveyor_crusher: Node3D = null
var sentry_drone: Node3D = null

var grid_ghost: MeshInstance3D = null
var carried_device: Node3D = null
var carried_original_pos: Vector3 = Vector3.ZERO
var carried_original_rot_y: float = 0.0
var carried_placement_pos: Vector3 = Vector3.ZERO
var carried_placement_rot_y: float = 0.0
var is_carrying_new_purchase: bool = false
var carried_device_cost: int = 0
var nearby_device: Node3D = null

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

@onready var wall_east_n_body: StaticBody3D = $Environment/MainRoom/WallEastNorth
@onready var wall_east_n_mesh: MeshInstance3D = $Environment/MainRoom/WallEastNorth/MeshInstance3D
@onready var wall_east_n_shape: CollisionShape3D = $Environment/MainRoom/WallEastNorth/CollisionShape3D

@onready var wall_east_s_body: StaticBody3D = $Environment/MainRoom/WallEastSouth
@onready var wall_east_s_mesh: MeshInstance3D = $Environment/MainRoom/WallEastSouth/MeshInstance3D
@onready var wall_east_s_shape: CollisionShape3D = $Environment/MainRoom/WallEastSouth/CollisionShape3D

@onready var door_lintel_body: StaticBody3D = $Environment/MainRoom/DoorLintel
@onready var door_lintel_mesh: MeshInstance3D = $Environment/MainRoom/DoorLintel/MeshInstance3D
@onready var door_lintel_shape: CollisionShape3D = $Environment/MainRoom/DoorLintel/CollisionShape3D

@onready var ceiling_vents_container: Node3D = $Environment/MainRoom/CeilingVents
@onready var doorway_sign: Node3D = $Environment/DoorwaySign
@onready var side_office: Node3D = $Environment/SideOffice
@onready var main_room_light: OmniLight3D = $MainRoomLight
@onready var office_light: OmniLight3D = $OfficeLight

# 3D Doorway Signboard
@onready var door_sign_main: Label3D = $Environment/DoorwaySign/SignLabelMain
@onready var door_sign_office: Label3D = $Environment/DoorwaySign/SignLabelOffice

# Minimal HUD Elements
@onready var pop_count_label: Label = $UI/HUD/TopLeft/Margin/VBox/PopCountLabel
@onready var grand_goal_bar: ProgressBar = get_node_or_null("UI/HUD/TopLeft/Margin/VBox/GrandGoalBar")
@onready var grand_goal_label: Label = get_node_or_null("UI/HUD/TopLeft/Margin/VBox/GrandGoalLabel")
@onready var playtime_label: Label = get_node_or_null("UI/HUD/TopLeft/Margin/VBox/PlaytimeLabel")
@onready var desk_prompt: Label = $UI/HUD/DeskPrompt
@onready var fps_label: Label = get_node_or_null("UI/HUD/FPSPanel/Margin/FPSLabel")
var fps_update_timer: float = 0.0

# Speedrun & Playtime Tracking
var playtime_seconds: float = 0.0
var best_speedrun_time: float = 0.0

# Crosshair UI & Context Reticle
@onready var crosshair_stamina_bar: ProgressBar = $UI/HUD/CrosshairContainer/VBox/StaminaBar
@onready var crosshair_container: Control = $UI/HUD/CrosshairContainer
@onready var crosshair_dot: ColorRect = $UI/HUD/CrosshairContainer/VBox/DotContainer/Dot
@onready var reticle_ring: Panel = $UI/HUD/CrosshairContainer/VBox/DotContainer/ReticleRing
var highlighted_balloon: Node = null

# Startup Dialog Modal
@onready var startup_modal: Control = $UI/StartupModal
@onready var btn_continue: Button = $UI/StartupModal/Panel/Margin/VBox/Buttons/BtnContinue
@onready var btn_new_game: Button = $UI/StartupModal/Panel/Margin/VBox/Buttons/BtnNewGame
@onready var save_info_label: Label = $UI/StartupModal/Panel/Margin/VBox/SaveInfoLabel

# Victory Dialog Modal
@onready var victory_modal: Control = get_node_or_null("UI/VictoryModal")
@onready var victory_time_stats_label: Label = get_node_or_null("UI/VictoryModal/Panel/Margin/VBox/TimeStatsLabel")
@onready var btn_close_victory: Button = get_node_or_null("UI/VictoryModal/Panel/Margin/VBox/Buttons/BtnCloseVictory")
@onready var btn_prestige: Button = get_node_or_null("UI/VictoryModal/Panel/Margin/VBox/Buttons/BtnPrestige")
var is_victory_shown: bool = false

# Shop UI Modal
@onready var shop_modal: Control = $UI/ShopModal
@onready var shop_coins_label: Label = $UI/ShopModal/Panel/Margin/VBox/Header/CoinsLabel
@onready var btn_close_shop: Button = $UI/ShopModal/Panel/Margin/VBox/Header/BtnClose
@onready var upgrades_container: GridContainer = $UI/ShopModal/Panel/Margin/VBox/Scroll/UpgradesGrid

# Filter Tabs (3 Primary Categories: Upgrades, Devices, Rooms)
@onready var btn_tab_upgrades: Button = $UI/ShopModal/Panel/Margin/VBox/CategoryTabs/BtnTabUpgrades
@onready var btn_tab_devices: Button = $UI/ShopModal/Panel/Margin/VBox/CategoryTabs/BtnTabDevices
@onready var btn_tab_rooms: Button = $UI/ShopModal/Panel/Margin/VBox/CategoryTabs/BtnTabRooms

# 3D Gravity Terminal
@onready var gravity_terminal: Node3D = $Environment/GravityTerminal
@onready var gravity_display_label: Label3D = $Environment/GravityTerminal/DisplayLabel
@onready var gravity_btn_mesh: MeshInstance3D = $Environment/GravityTerminal/ButtonMesh

var is_near_desk: bool = false
var is_near_grav_terminal: bool = false
var raycast_target_type: String = "" # "desk", "gravity_terminal", "device", ""
var raycast_target_device: Node3D = null
var raycast_target_name: String = ""
var current_filter: String = "upgrades"
var auto_save_timer: float = 0.0
var active_vent_positions: Array[Vector3] = []

var debug_panel: Control = null
var debug_tier_weights: Dictionary = {
	50: 0.05,
	10: 0.20,
	5: 0.40,
	1: 0.35
}
var vent_cycle_idx: int = 0
var is_loading_save: bool = false

var balloon_gravity_scales: Array[float] = [0.25, 0.80, 1.80, 3.50, 6.00]
var balloon_linear_damps: Array[float] = [2.2, 1.4, 0.8, 0.35, 0.15]
var gravity_mode_names: Array[String] = [
	"0.25 G (Standart Süzülme)",
	"0.80 G (Ağır Döküm)",
	"1.80 G (Hızlı Şelale)",
	"3.50 G (Ağır Çöküş)",
	"6.00 G (Hiper Yerçekimi)"
]
var current_gravity_idx: int = 0
var max_unlocked_gravity_idx: int = 0

func apply_gravity_to_active_balloons() -> void:
	if not balloon_container: return
	var idx = clamp(current_gravity_idx, 0, balloon_gravity_scales.size() - 1)
	var grav = balloon_gravity_scales[idx]
	var damp = balloon_linear_damps[idx]
	for child in balloon_container.get_children():
		if is_instance_valid(child) and child is RigidBody3D and not child.is_queued_for_deletion():
			child.gravity_scale = grav
			child.linear_damp = damp
	update_gravity_terminal_display()

func update_gravity_terminal_display() -> void:
	if gravity_display_label:
		var idx = clamp(current_gravity_idx, 0, balloon_gravity_scales.size() - 1)
		var g_val = balloon_gravity_scales[idx]
		var g_name = gravity_mode_names[idx]
		gravity_display_label.text = "YERÇEKİMİ KONTROLÜ\n[ " + str(g_val) + " G ]\n" + g_name.to_upper()

func cycle_gravity_mode() -> void:
	if shop_manager and shop_manager.devices.has("gravity_regulator"):
		max_unlocked_gravity_idx = shop_manager.devices["gravity_regulator"].get("level", 0)
		
	if max_unlocked_gravity_idx <= 0:
		if desk_prompt:
			desk_prompt.text = "Yerçekimi Regülatörü Kilitli! Marketteki Cihazlar sekmesinden satın alın."
			desk_prompt.visible = true
		return
		
	current_gravity_idx = (current_gravity_idx + 1) % (max_unlocked_gravity_idx + 1)
	apply_gravity_to_active_balloons()
	
	if gravity_btn_mesh:
		var tween = create_tween()
		tween.tween_property(gravity_btn_mesh, "position:x", -0.05, 0.05)
		tween.tween_property(gravity_btn_mesh, "position:x", -0.10, 0.08)
		
	if desk_prompt:
		desk_prompt.text = "Yerçekimi: [" + gravity_mode_names[current_gravity_idx] + "]"
		desk_prompt.visible = true
		
	save_current_data()

func _ready() -> void:
	if corner_fan:
		corner_fan.visible = false
		corner_fan.set("is_active", false)
		
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
		
	if shop_manager:
		shop_manager.coins_changed.connect(_on_coins_changed)
		shop_manager.upgrade_purchased.connect(_on_upgrade_purchased)
		shop_manager.room_switched.connect(_on_room_switched)
		if shop_manager.has_signal("device_unit_purchased"):
			shop_manager.device_unit_purchased.connect(_on_device_unit_purchased)
		shop_manager.device_purchased.connect(_on_device_tech_upgraded)
		
	update_ceiling_vents()
	setup_shop_ui_events()
	setup_startup_modal()
	setup_victory_modal()
	
	# Setup In-Game Live Debug & Tuning Panel
	var debug_script = load("res://scripts/debug_panel.gd")
	if debug_script:
		debug_panel = debug_script.new()
		var ui_node = get_node_or_null("UI")
		if ui_node:
			ui_node.add_child(debug_panel)
		else:
			add_child(debug_panel)

func setup_victory_modal() -> void:
	if btn_close_victory:
		btn_close_victory.pressed.connect(_on_close_victory_pressed)
	if btn_prestige:
		btn_prestige.pressed.connect(_on_prestige_pressed)

func _on_close_victory_pressed() -> void:
	if victory_modal:
		victory_modal.visible = false
	if player and player.has_method("set_ui_open"):
		player.set_ui_open(false)
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED

func _on_prestige_pressed() -> void:
	if not shop_manager: return
	var total = game_manager.total_pops if game_manager else 1000000
	var he_earned = shop_manager.perform_prestige(total)
	
	if victory_modal:
		victory_modal.visible = false
	if player and player.has_method("set_ui_open"):
		player.set_ui_open(false)
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	
	# Reset speedrun playtime for the next prestige lap
	playtime_seconds = 0.0
	is_victory_shown = false
	
	apply_room_layout("small_room")
	if player:
		player.global_position = Vector3(13.5, 0.6, 0.0)
		player.velocity = Vector3.ZERO
	if game_manager:
		game_manager.total_pops = 0
		game_manager.active_balloons = 0
		game_manager.current_vent_level = 0
		game_manager.current_cap_level = 0
		game_manager.recalculate_effective_stats()
		game_manager.start_game()
	if balloon_container:
		for b in balloon_container.get_children():
			b.queue_free()
			
	update_all_shop_cards()
	update_pop_counter(0)
	save_current_data()

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

func show_victory_screen() -> void:
	is_victory_shown = true
	var is_new_record = false
	if best_speedrun_time <= 0.0 or playtime_seconds < best_speedrun_time:
		best_speedrun_time = playtime_seconds
		is_new_record = true
		
	if victory_time_stats_label:
		var cur_str = format_time(playtime_seconds)
		var best_str = format_time(best_speedrun_time)
		var rec_tag = " [★ YENİ REKOR!]" if is_new_record else ""
		victory_time_stats_label.text = "Tamamlama Süresi: %s%s  |  En İyi Rekor: %s" % [cur_str, rec_tag, best_str]
		
	if victory_modal:
		victory_modal.visible = true
	if player and player.has_method("set_ui_open"):
		player.set_ui_open(true)
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	if sound_manager and sound_manager.has_method("play_gold_pop"):
		sound_manager.play_gold_pop()

func setup_startup_modal() -> void:
	if btn_continue:
		btn_continue.pressed.connect(_on_continue_pressed)
	if btn_new_game:
		btn_new_game.pressed.connect(_on_new_game_pressed)
		
	if save_manager and save_manager.has_save():
		var data = save_manager.load_full_state()
		var pops = data.get("total_pops", 0)
		var coins = data.get("coins", 0)
		var room_id = data.get("current_room", "small_room")
		var room_title = "Küçük Salon"
		if shop_manager and shop_manager.rooms.has(room_id):
			room_title = shop_manager.rooms[room_id].get("name", "Salon")
			
		if save_info_label:
			save_info_label.text = "Kayıt Detayı: " + str(pops) + " Patlatma | " + str(coins) + " Coin | " + room_title
			
		if startup_modal:
			startup_modal.visible = true
		if player and player.has_method("set_ui_open"):
			player.set_ui_open(true)
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	else:
		if startup_modal:
			startup_modal.visible = false
		start_new_game()

func _on_continue_pressed() -> void:
	if startup_modal:
		startup_modal.visible = false
		
	var target_room = "small_room"
	if save_manager:
		var state = save_manager.load_full_state()
		target_room = state.get("current_room", "small_room")
		
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
	if startup_modal:
		startup_modal.visible = false
	start_new_game()

func start_new_game() -> void:
	if balloon_container:
		for c in balloon_container.get_children():
			c.queue_free()
			
	if game_manager:
		game_manager.total_pops = 0
		game_manager.active_balloons = 0
		game_manager.current_vent_level = 0
		game_manager.current_cap_level = 0
		
	if shop_manager:
		shop_manager.coins = 0
		shop_manager.current_room = "small_room"
		shop_manager.unlocked_rooms = ["small_room"]
		
		for up_id in shop_manager.upgrades.keys():
			shop_manager.upgrades[up_id]["level"] = 0
			shop_manager.upgrade_purchased.emit(up_id, 0)
			
		for dev_id in shop_manager.devices.keys():
			shop_manager.devices[dev_id]["level"] = 0
			_on_device_purchased(dev_id, 0)
			
	apply_room_layout("small_room")
	
	if player:
		player.global_position = Vector3(13.5, 0.6, 0.0)
		player.velocity = Vector3.ZERO
		player.rotation = Vector3.ZERO
		if player.head:
			player.head.rotation = Vector3.ZERO
		player.current_energy = player.max_energy
		player.is_exhausted = false
		player.energy_changed.emit(player.current_energy, player.max_energy, player.is_exhausted)
		if player.has_method("set_ui_open"):
			player.set_ui_open(false)
			
	update_all_shop_cards()
	update_pop_counter(0)
	
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	save_current_data()
	
	if game_manager:
		game_manager.recalculate_effective_stats()
		game_manager.start_game()
		_on_active_count_changed(game_manager.active_balloons, game_manager.max_room_balloons)

func apply_room_layout(room_id: String) -> void:
	if not shop_manager or not shop_manager.rooms.has(room_id):
		return
		
	var r_data = shop_manager.rooms[room_id]
	var W: float = r_data["floor_size"].x
	var L: float = r_data["floor_size"].y
	var H: float = r_data["ceiling_height"]
	var half_w = W / 2.0
	var half_l = L / 2.0
	
	# 1. Floor & Ceiling
	if floor_mesh and floor_mesh.mesh is BoxMesh:
		floor_mesh.mesh.size = Vector3(W, 0.5, L)
	if floor_shape and floor_shape.shape is BoxShape3D:
		# 4.0m deep bedrock with top surface aligned precisely at world y = 0.0
		floor_shape.shape.size = Vector3(W + 2.0, 4.0, L + 2.0)
		floor_shape.position = Vector3(0, -1.75, 0)
		
	if ceiling_body:
		ceiling_body.position.y = H + 0.25
	if ceiling_mesh and ceiling_mesh.mesh is BoxMesh:
		ceiling_mesh.mesh.size = Vector3(W, 0.5, L)
	if ceiling_shape and ceiling_shape.shape is BoxShape3D:
		ceiling_shape.shape.size = Vector3(W, 0.5, L)
		ceiling_shape.position = Vector3.ZERO
		
	# 2. North, South, West Walls
	if wall_north_body:
		wall_north_body.position = Vector3(0, H / 2.0, -half_l)
	if wall_north_mesh and wall_north_mesh.mesh is BoxMesh:
		wall_north_mesh.mesh.size = Vector3(W, H, 0.5)
	if wall_north_shape and wall_north_shape.shape is BoxShape3D:
		wall_north_shape.shape.size = Vector3(W, H, 0.5)
		
	if wall_south_body:
		wall_south_body.position = Vector3(0, H / 2.0, half_l)
	if wall_south_mesh and wall_south_mesh.mesh is BoxMesh:
		wall_south_mesh.mesh.size = Vector3(W, H, 0.5)
	if wall_south_shape and wall_south_shape.shape is BoxShape3D:
		wall_south_shape.shape.size = Vector3(W, H, 0.5)
		
	if wall_west_body:
		wall_west_body.position = Vector3(-half_w, H / 2.0, 0)
	if wall_west_mesh and wall_west_mesh.mesh is BoxMesh:
		wall_west_mesh.mesh.size = Vector3(0.5, H, L)
	if wall_west_shape and wall_west_shape.shape is BoxShape3D:
		wall_west_shape.shape.size = Vector3(0.5, H, L)
		
	# 3. East Doorway Wall
	var door_width = 4.0
	var door_height = 3.35
	var door_wall_len = max(1.0, (L - door_width) / 2.0)
	var lintel_h = max(0.5, H - door_height)
	var lintel_y = door_height + (lintel_h / 2.0)
	
	if wall_east_n_body:
		wall_east_n_body.position = Vector3(half_w, H / 2.0, -(door_width / 2.0 + door_wall_len / 2.0))
	if wall_east_n_mesh and wall_east_n_mesh.mesh is BoxMesh:
		wall_east_n_mesh.mesh.size = Vector3(0.5, H, door_wall_len)
	if wall_east_n_shape and wall_east_n_shape.shape is BoxShape3D:
		wall_east_n_shape.shape.size = Vector3(0.5, H, door_wall_len)
		
	if wall_east_s_body:
		wall_east_s_body.position = Vector3(half_w, H / 2.0, door_width / 2.0 + door_wall_len / 2.0)
	if wall_east_s_mesh and wall_east_s_mesh.mesh is BoxMesh:
		wall_east_s_mesh.mesh.size = Vector3(0.5, H, door_wall_len)
	if wall_east_s_shape and wall_east_s_shape.shape is BoxShape3D:
		wall_east_s_shape.shape.size = Vector3(0.5, H, door_wall_len)
		
	if door_lintel_body:
		door_lintel_body.position = Vector3(half_w, lintel_y, 0)
	if door_lintel_mesh and door_lintel_mesh.mesh is BoxMesh:
		door_lintel_mesh.mesh.size = Vector3(0.5, lintel_h, door_width)
	if door_lintel_shape and door_lintel_shape.shape is BoxShape3D:
		door_lintel_shape.shape.size = Vector3(0.5, lintel_h, door_width)
		
	# 4. Reposition Doorway Sign, SideOffice, Devices
	if doorway_sign:
		doorway_sign.position = Vector3(half_w, min(3.85, H - 0.4), 0)
		
	if side_office:
		side_office.position = Vector3(half_w + 5.5, 0, 0)
		
	if office_light:
		office_light.position = Vector3(half_w + 5.5, 3.6, 0)
		
	if corner_fan:
		corner_fan.position = Vector3(-half_w + 2.5, 0, -half_l + 2.5)
		
	if electric_wall:
		electric_wall.position = Vector3(-half_w + 0.15, H * 0.38, 0)
		
	if spike_wall:
		spike_wall.position = Vector3(0, H * 0.38, -half_l + 0.15)
		
	# 5. Room Lighting & Atmosphere
	if main_room_light:
		main_room_light.position = Vector3(0, H - 0.7, 0)
		main_room_light.omni_range = max(18.0, W * 0.9)
		
		match room_id:
			"small_room":
				main_room_light.light_color = Color(1.0, 0.92, 0.82)
				main_room_light.light_energy = 1.8
			"medium_room":
				main_room_light.light_color = Color(0.95, 0.95, 1.0)
				main_room_light.light_energy = 2.2
			"large_room":
				main_room_light.light_color = Color(0.85, 0.95, 1.0)
				main_room_light.light_energy = 2.6
			"warehouse":
				main_room_light.light_color = Color(1.0, 0.88, 0.70)
				main_room_light.light_energy = 3.0
			"hangar":
				main_room_light.light_color = Color(0.90, 0.98, 1.0)
				main_room_light.light_energy = 3.5
			"hyper_lab":
				main_room_light.light_color = Color(0.70, 0.90, 1.0)
				main_room_light.light_energy = 4.2
				
	# 6. Configure Progressive Ceiling Vents (Pipes Unlocked: 1 to 9)
	update_ceiling_vents()
		
	# Update HUD Signboard
	if game_manager:
		_on_active_count_changed(game_manager.active_balloons, game_manager.max_room_balloons)
		
	if spike_wall and spike_wall.has_method("update_position_for_room"):
		spike_wall.update_position_for_room()
		
	if electric_wall and electric_wall.has_method("update_position_for_room"):
		electric_wall.update_position_for_room()
		
	if magnet_pylon and magnet_pylon.has_method("update_position_for_room"):
		magnet_pylon.update_position_for_room()
		
	if conveyor_crusher and conveyor_crusher.has_method("update_position_for_room"):
		conveyor_crusher.update_position_for_room()
		
	if sentry_drone and sentry_drone.has_method("update_position_for_room"):
		sentry_drone.update_position_for_room()
		
	if gravity_terminal:
		gravity_terminal.position = Vector3(W * 0.5 - 0.65, 0.0, -2.4)
	update_gravity_terminal_display()
	
	# Clean up any balloons trapped outside new room bounds or under floor
	if balloon_container:
		for b in balloon_container.get_children():
			if b is RigidBody3D and is_instance_valid(b) and not b.is_queued_for_deletion():
				if abs(b.global_position.x) > (half_w + 1.0) or abs(b.global_position.z) > (half_l + 1.0) or b.global_position.y < -0.4:
					b.pop("room_resize")

func update_ceiling_vents() -> void:
	active_vent_positions.clear()
	if not shop_manager: return
	
	var r_data = shop_manager.get_current_room_data()
	var W: float = r_data["floor_size"].x
	var L: float = r_data["floor_size"].y
	var H: float = r_data["ceiling_height"]
	var vent_y = H - 0.85
	
	var xs = [-W * 0.28, 0.0, W * 0.28]
	var zs = [-L * 0.28, 0.0, L * 0.28]
	
	# All 9 theoretical grid positions
	var all_positions: Array[Vector3] = []
	for z_pos in zs:
		for x_pos in xs:
			all_positions.append(Vector3(x_pos, vent_y, z_pos))
			
	# Update physical node positions in 3D scene
	if ceiling_vents_container:
		for i in range(min(all_positions.size(), ceiling_vents_container.get_child_count())):
			var vent_node = ceiling_vents_container.get_child(i)
			if vent_node:
				vent_node.position = Vector3(all_positions[i].x, H - 0.35, all_positions[i].z)
				
	# Calculate which pipes are actively unlocked
	# Level 0 (1 pipe) -> Level 8 (9 pipes)
	var pipe_lvl = 0
	if shop_manager.upgrades.has("pipe_count"):
		pipe_lvl = clamp(shop_manager.upgrades["pipe_count"]["level"], 0, 8)
		
	# Progressive layout across 3x3 grid:
	var pipe_patterns = [
		[4],                         # 1 Pipe: Center
		[1, 7],                      # 2 Pipes: North + South
		[4, 1, 7],                   # 3 Pipes: Center + North + South
		[0, 2, 6, 8],                # 4 Pipes: 4 Corners
		[4, 0, 2, 6, 8],             # 5 Pipes: Center + 4 Corners (Plus)
		[0, 1, 2, 6, 7, 8],          # 6 Pipes: North 3 + South 3
		[4, 0, 1, 2, 6, 7, 8],       # 7 Pipes: North 3 + South 3 + Center
		[0, 1, 2, 3, 5, 6, 7, 8],    # 8 Pipes: Outer Ring of 8
		[0, 1, 2, 3, 4, 5, 6, 7, 8]  # 9 Pipes: Complete 3x3 Matrix
	]
	
	var active_indices = pipe_patterns[pipe_lvl]
	
	# Apply visibility to 3D meshes in ceiling
	if ceiling_vents_container:
		for i in range(ceiling_vents_container.get_child_count()):
			var vent_node = ceiling_vents_container.get_child(i)
			if vent_node:
				var is_active = (i in active_indices)
				vent_node.visible = is_active
				
	# Populate active drop points for balloon spawning
	for idx in active_indices:
		if idx < all_positions.size():
			active_vent_positions.append(all_positions[idx])

func _on_room_switched(room_id: String) -> void:
	apply_room_layout(room_id)
	update_all_shop_cards()
	if player and is_instance_valid(player):
		player.velocity = Vector3.ZERO
		player.global_position = Vector3(11.0, 0.2, 0.0)
	save_current_data()

func _on_device_unit_purchased(device_id: String, new_count: int, level: int) -> void:
	var dev_node: Node3D = null
	if device_id == "gravity_regulator":
		max_unlocked_gravity_idx = level
		if current_gravity_idx > max_unlocked_gravity_idx:
			current_gravity_idx = max_unlocked_gravity_idx
		apply_gravity_to_active_balloons()
	elif DEVICE_SCENES.has(device_id) and env_main_room:
		dev_node = DEVICE_SCENES[device_id].instantiate()
		dev_node.set_meta("device_type", device_id)
		dev_node.add_to_group("devices")
		env_main_room.add_child(dev_node)
		if dev_node.has_method("setup_level"):
			dev_node.setup_level(level)
		if device_id == "sentry_drone":
			dev_node.set("hover_angle", float(new_count) * (PI * 0.35))
		active_placed_devices.append(dev_node)
		
	update_all_shop_cards()
	save_current_data()
	
	# Flying companion drones deploy directly into the sky around the player, NOT placed on floor grid!
	if device_id != "sentry_drone" and dev_node and is_instance_valid(dev_node):
		if shop_modal and shop_modal.visible:
			toggle_shop_modal()
		var d_data = shop_manager.devices.get(device_id, {})
		var u_costs = d_data.get("unit_costs", d_data.get("costs", [500]))
		var purchase_cost = u_costs[clamp(new_count - 1, 0, u_costs.size() - 1)]
		start_carrying_device(dev_node, true, purchase_cost)
	elif device_id == "sentry_drone":
		if desk_prompt:
			desk_prompt.text = "Yeni Güvenlik Dronu (" + str(new_count) + "/6) filoya katıldı!"
			desk_prompt.visible = true

func _on_device_tech_upgraded(device_id: String, level: int) -> void:
	if device_id == "gravity_regulator":
		max_unlocked_gravity_idx = level
		if current_gravity_idx > max_unlocked_gravity_idx:
			current_gravity_idx = max_unlocked_gravity_idx
		apply_gravity_to_active_balloons()
	else:
		for dev in active_placed_devices:
			if is_instance_valid(dev) and dev.has_meta("device_type") and dev.get_meta("device_type") == device_id:
				if dev.has_method("setup_level"):
					dev.setup_level(level)
	update_all_shop_cards()
	save_current_data()

func _on_device_purchased(device_id: String, level: int, from_shop_ui: bool = false) -> void:
	_on_device_tech_upgraded(device_id, level)

func _on_active_count_changed(active: int, max_cap: int) -> void:
	var room_name = "ODA"
	if shop_manager and shop_manager.has_method("get_current_room_data"):
		room_name = shop_manager.get_current_room_data().get("name", "ODA").split(" ")[0]
		
	var display_text = room_name.to_upper() + " BALON: " + str(active) + " / " + str(max_cap)
	if door_sign_main:
		door_sign_main.text = display_text
	if door_sign_office:
		door_sign_office.text = display_text

func _process(delta: float) -> void:
	# FPS Counter Update (Always active even in modals)
	fps_update_timer += delta
	if fps_update_timer >= 0.2:
		fps_update_timer = 0.0
		if fps_label:
			var cur_fps = Engine.get_frames_per_second()
			fps_label.text = "FPS: %d" % cur_fps
			if cur_fps >= 55:
				fps_label.add_theme_color_override("font_color", Color("#2ecc71"))
			elif cur_fps >= 30:
				fps_label.add_theme_color_override("font_color", Color("#f1c40f"))
			else:
				fps_label.add_theme_color_override("font_color", Color("#e74c3c"))
				
	if startup_modal and startup_modal.visible:
		return
		
	# Playtime & Speedrun Timer Tracking with Total Coins & Real-time PPS
	playtime_seconds += delta
	if playtime_label:
		var c_str = format_number(shop_manager.coins) if shop_manager else "0"
		var eta_str = format_eta(game_manager.get_eta_to_target(1000000)) if (game_manager and game_manager.has_method("get_eta_to_target")) else "--"
		playtime_label.text = "Süre: %s  |  Kasa: %s Coin  |  1M Tahmini: %s" % [format_time(playtime_seconds), c_str, eta_str]
	if game_manager:
		update_pop_counter(game_manager.total_pops)
		
	# Floor Level Guard: Player can never sink below floor y = 0.0
	if player and is_instance_valid(player) and player.global_position.y < -0.05:
		player.velocity.y = max(0.0, player.velocity.y)
		player.global_position.y = 0.05
		
	auto_save_timer += delta
	if auto_save_timer >= 4.0:
		auto_save_timer = 0.0
		save_current_data()
		
	# 1. Carrying / Grid Placement Active (First-Person Held in Hands + Holographic Floor/Wall Grid Ghost)
	if carried_device and player and is_instance_valid(player):
		var cam = player.get_node_or_null("Head/Camera3D")
		if cam:
			var ray_orig = cam.global_position
			var ray_dir = -cam.global_transform.basis.z
			var dev_type = carried_device.get_meta("device_type") if carried_device.has_meta("device_type") else ""
			
			var room_w = 16.0
			var room_l = 16.0
			var ceiling_h = 6.0
			if shop_manager and shop_manager.has_method("get_current_room_data"):
				var r_data = shop_manager.get_current_room_data()
				room_w = r_data.get("floor_size", Vector2(16, 16)).x
				room_l = r_data.get("floor_size", Vector2(16, 16)).y
				ceiling_h = r_data.get("ceiling_height", 6.0)
				
			var half_w = room_w / 2.0
			var half_l = room_l / 2.0
			
			# Check wall planes for wall mounting (Wall Spikes & Wall Fan)
			var is_wall_mounted = false
			var best_hit_dist = 999.0
			var best_wall_pos = Vector3.ZERO
			var best_wall_rot = 0.0
			
			var wall_planes = [
				{"p": Plane(Vector3.BACK, -half_l), "rot": 0.0, "axis": "z"},
				{"p": Plane(Vector3.FORWARD, -half_l), "rot": PI, "axis": "z"},
				{"p": Plane(Vector3.RIGHT, -half_w), "rot": -PI * 0.5, "axis": "x"},
				{"p": Plane(Vector3.LEFT, -half_w), "rot": PI * 0.5, "axis": "x"}
			]
			
			for wp in wall_planes:
				var inter = wp["p"].intersects_ray(ray_orig, ray_dir)
				if inter != null:
					var d = ray_orig.distance_to(inter)
					if d > 0.5 and d < 35.0 and inter.y >= 0.2 and inter.y <= (ceiling_h - 0.2):
						if abs(inter.x) <= (half_w + 0.15) and abs(inter.z) <= (half_l + 0.15):
							if d < best_hit_dist:
								best_hit_dist = d
								best_wall_pos = inter
								best_wall_rot = wp["rot"]
								is_wall_mounted = true
								
			if is_wall_mounted and dev_type == "fan" and best_hit_dist < 18.0:
				var snap_y = clamp(round(best_wall_pos.y / 0.8) * 0.8, 0.8, ceiling_h - 1.4)
				if abs(best_wall_pos.z) >= (half_l - 0.6):
					var snap_x = clamp(round(best_wall_pos.x / 1.5) * 1.5, -half_w + 1.5, half_w - 1.5)
					var z_sign = -1.0 if best_wall_pos.z < 0 else 1.0
					carried_placement_pos = Vector3(snap_x, snap_y, (half_l - 0.08) * z_sign)
				else:
					var snap_z = clamp(round(best_wall_pos.z / 1.5) * 1.5, -half_l + 1.5, half_l - 1.5)
					var x_sign = -1.0 if best_wall_pos.x < 0 else 1.0
					carried_placement_pos = Vector3((half_w - 0.08) * x_sign, snap_y, snap_z)
				carried_placement_rot_y = best_wall_rot
			else:
				# Floor Placement
				var floor_plane = Plane(Vector3.UP, 0.05)
				var intersect = floor_plane.intersects_ray(ray_orig, ray_dir)
				var hit_pos = player.global_position + ray_dir * 3.5
				if intersect != null:
					var dist = ray_orig.distance_to(intersect)
					if dist < 45.0 and intersect.y <= (ray_orig.y + 0.5):
						hit_pos = intersect
						
				var max_x = half_w - 1.5
				var max_z = half_l - 1.5
				var clamped_x = clamp(hit_pos.x, -max_x, max_x)
				var clamped_z = clamp(hit_pos.z, -max_z, max_z)
				
				# Snap to 1.5m floor grid
				var snap_x = round(clamped_x / 1.5) * 1.5
				var snap_z = round(clamped_z / 1.5) * 1.5
				carried_placement_pos = Vector3(snap_x, 0.05, snap_z)
			
			# Update Holographic Grid Ghost
			var g = _get_or_create_grid_ghost()
			if g:
				g.global_position = carried_placement_pos
				g.rotation.y = carried_placement_rot_y
				
			# Hold the Physical Device in Front of the Camera (Held in Hands)
			var bob = sin(Time.get_ticks_msec() * 0.0045) * 0.012
			var hand_offset = (-cam.global_transform.basis.z * 0.90) + (cam.global_transform.basis.y * (-0.28 + bob)) + (cam.global_transform.basis.x * 0.24)
			var target_hand_pos = cam.global_position + hand_offset
			carried_device.global_position = carried_device.global_position.lerp(target_hand_pos, delta * 22.0)
			
			# Align device orientation with camera + custom placement rotation
			var target_rot_y = cam.global_rotation.y + carried_placement_rot_y
			carried_device.global_rotation.y = lerp_angle(carried_device.global_rotation.y, target_rot_y, delta * 18.0)
			carried_device.global_rotation.x = lerp_angle(carried_device.global_rotation.x, cam.global_rotation.x * 0.3, delta * 18.0)
			carried_device.global_rotation.z = lerp_angle(carried_device.global_rotation.z, 0.0, delta * 18.0)
			
			if desk_prompt:
				var target_surface = "Duvara" if is_wall_mounted else "Zemine"
				desk_prompt.text = "[Sol Tık / E] " + target_surface + " Yerleştir  |  [R] 45° Döndür  |  [Q / Sağ Tık] İptal"
				desk_prompt.visible = true
		return
		
	# 2. Precision Raycast Targeting (Aim directly with crosshair to interact from distance)
	update_raycast_interaction()

func update_raycast_interaction() -> void:
	raycast_target_type = ""
	raycast_target_device = null
	raycast_target_name = ""
	nearby_device = null
	
	if not player or not is_instance_valid(player):
		_clear_balloon_highlight()
		_reset_crosshair_style()
		if desk_prompt: desk_prompt.visible = false
		return
		
	var cam: Camera3D = player.get_node_or_null("Head/Camera3D")
	if not cam:
		_clear_balloon_highlight()
		_reset_crosshair_style()
		if desk_prompt: desk_prompt.visible = false
		return
		
	var cam_pos = cam.global_position
	var look_dir = -cam.global_transform.basis.z.normalized()
	
	# -------------------------------------------------------------
	# 1. X-Ray Device & Interactable Scan (Penetrates through balloons!)
	# -------------------------------------------------------------
	var best_target_type = ""
	var best_target_dev: Node3D = null
	var best_target_name = ""
	var best_dot = 0.88 # ~30 degree cone
	var best_dist = 6.5
	
	# Check Computer Desk in Office
	var desk_node = get_node_or_null("Environment/SideOffice/ComputerDesk")
	if desk_node and is_instance_valid(desk_node):
		var to_desk = (desk_node.global_position + Vector3(0, 0.7, 0)) - cam_pos
		var d_dist = to_desk.length()
		if d_dist <= 7.0 and d_dist > 0.2:
			var dot = look_dir.dot(to_desk / d_dist)
			if dot > 0.70 and dot > best_dot:
				best_target_type = "desk"
				best_target_name = "Bilgisayar Masası"
				best_dot = dot
				best_dist = d_dist
				
	# Check Gravity Terminal
	if gravity_terminal and is_instance_valid(gravity_terminal):
		var to_gt = (gravity_terminal.global_position + Vector3(0, 1.2, 0)) - cam_pos
		var g_dist = to_gt.length()
		if g_dist <= 6.5 and g_dist > 0.2:
			var dot = look_dir.dot(to_gt / g_dist)
			if dot > 0.70 and dot > best_dot:
				best_target_type = "gravity_terminal"
				best_target_name = "Yerçekimi Terminali"
				best_dot = dot
				best_dist = g_dist
				
	# Check All Placed Devices on Floor / Flying in Room
	for d_node in active_placed_devices:
		if d_node and is_instance_valid(d_node) and d_node.visible:
			var d_pos = d_node.global_position + Vector3(0, 0.35, 0)
			var to_d = d_pos - cam_pos
			var dist = to_d.length()
			if dist <= 6.5 and dist > 0.3:
				var dot = look_dir.dot(to_d / dist)
				if dot > best_dot:
					var d_type = d_node.get_meta("device_type") if d_node.has_meta("device_type") else ""
					var d_name = _get_device_display_name(d_type)
					best_target_type = "device"
					best_target_dev = d_node
					best_target_name = d_name
					best_dot = dot
					best_dist = dist
					
	if best_target_type != "":
		raycast_target_type = best_target_type
		raycast_target_device = best_target_dev
		raycast_target_name = best_target_name
		nearby_device = best_target_dev
		
		if desk_prompt:
			if raycast_target_type == "desk":
				desk_prompt.text = "[E] Bilgisayarı Aç / Dükkana Gir"
			elif raycast_target_type == "gravity_terminal":
				var g_mode = gravity_mode_names[clamp(current_gravity_idx, 0, gravity_mode_names.size() - 1)]
				var d_data = shop_manager.devices.get("gravity_regulator", {}) if shop_manager else {}
				var cur_lvl = d_data.get("level", 0)
				var max_lvl = d_data.get("max_level", 4)
				var costs = d_data.get("costs", [400, 1800, 8500, 35000])
				if cur_lvl < max_lvl:
					var next_cost = costs[cur_lvl]
					var next_mode = gravity_mode_names[cur_lvl + 1]
					desk_prompt.text = "[E] Yerçekimi: [" + g_mode + "]   |   [F] Seviye Yükselt [" + next_mode + "] : " + str(next_cost) + " Coin"
				else:
					desk_prompt.text = "[E] Yerçekimi: [" + g_mode + "]   |   [MAX SEVİYE (6.00 G)]"
			elif raycast_target_type == "device" and best_target_dev:
				desk_prompt.text = _get_device_interaction_prompt(best_target_dev, best_target_name)
			desk_prompt.visible = true
	else:
		if desk_prompt:
			desk_prompt.visible = false

	# -------------------------------------------------------------
	# 2. Balloon Target Check (For needle popping & pink reticle highlight)
	# -------------------------------------------------------------
	var world = get_world_3d()
	if not world: return
	var space_state = world.direct_space_state
	if not space_state: return
	
	var from = cam.global_position
	var to = from + (look_dir * 5.2)
	var exclude_rids = [player.get_rid()]
	var nudge_cone = player.get_node_or_null("Head/Camera3D/WindCone")
	if nudge_cone:
		exclude_rids.append(nudge_cone.get_rid())
		
	var query = PhysicsRayQueryParameters3D.create(from, to)
	query.collide_with_areas = true
	query.collide_with_bodies = true
	query.exclude = exclude_rids
	
	var result = space_state.intersect_ray(query)
	var col = result.collider if result else null
	var hit_balloon = null
	
	if col and is_instance_valid(col) and col.is_in_group("balloons"):
		hit_balloon = col
	else:
		# Fast C++ physics broadphase query for forgiving needle aim (Zero CPU overhead)
		var shape_query = PhysicsShapeQueryParameters3D.new()
		var sphere = SphereShape3D.new()
		sphere.radius = 0.45
		shape_query.shape = sphere
		shape_query.transform = Transform3D(Basis(), from + (look_dir * 2.6))
		shape_query.collision_mask = 2 # Balloons layer
		shape_query.collide_with_bodies = true
		shape_query.collide_with_areas = false
		shape_query.exclude = exclude_rids
		var hits = space_state.intersect_shape(shape_query, 1)
		if not hits.is_empty():
			var h_col = hits[0].collider
			if h_col is RigidBody3D and is_instance_valid(h_col) and not h_col.get("is_popped"):
				hit_balloon = h_col
						
	if hit_balloon and is_instance_valid(hit_balloon):
		if highlighted_balloon != hit_balloon:
			_clear_balloon_highlight()
			highlighted_balloon = hit_balloon
			if highlighted_balloon.has_method("set_highlight"):
				highlighted_balloon.set_highlight(true)
		if reticle_ring: reticle_ring.modulate = Color(1.0, 0.3, 0.5, 0.9)
		if crosshair_dot: crosshair_dot.color = Color(1.0, 0.4, 0.6, 1.0)
	else:
		_clear_balloon_highlight()
		if raycast_target_type != "":
			if reticle_ring: reticle_ring.modulate = Color(0.3, 0.8, 1.0, 0.95)
			if crosshair_dot: crosshair_dot.color = Color(0.3, 0.8, 1.0, 1.0)
		else:
			_reset_crosshair_style()

func _get_device_interaction_prompt(d_node: Node3D, d_name: String) -> String:
	if not d_node or not is_instance_valid(d_node): return ""
	var d_type = d_node.get_meta("device_type") if d_node.has_meta("device_type") else ""
	var cur_lvl = d_node.get("level") if ("level" in d_node) else 1
	if cur_lvl <= 0: cur_lvl = 1
	var max_lvl = 6
	if shop_manager and shop_manager.devices.has(d_type):
		max_lvl = shop_manager.devices[d_type].get("max_level", 6)
		
	var prompt = "[E] " + d_name + " Taşı (Sv. " + str(cur_lvl) + ")"
	if cur_lvl >= max_lvl:
		prompt += "  |  [MAX SEVİYE " + str(max_lvl) + "]"
	else:
		var cost = 500
		if shop_manager and shop_manager.devices.has(d_type):
			var costs_arr = shop_manager.devices[d_type].get("costs", [500])
			var c_idx = clamp(cur_lvl - 1, 0, costs_arr.size() - 1)
			cost = costs_arr[c_idx]
			
		var needed_pops = shop_manager.get_device_tech_req_pops(d_type, cur_lvl) if shop_manager else 0
		var total_pops = game_manager.total_pops if game_manager else 0
		if total_pops < needed_pops:
			prompt += "  |  [🔒 Kilitli: " + str(needed_pops) + " Pop Gerekli]"
		else:
			prompt += "  |  [F] Seviye Yükselt (Sv. " + str(cur_lvl) + " ➔ " + str(cur_lvl + 1) + ") : " + str(cost) + " Coin"
	return prompt

func _clear_balloon_highlight() -> void:
	if highlighted_balloon and is_instance_valid(highlighted_balloon):
		if highlighted_balloon.has_method("set_highlight"):
			highlighted_balloon.set_highlight(false)
	highlighted_balloon = null

func _reset_crosshair_style() -> void:
	if reticle_ring: reticle_ring.modulate = Color(1, 1, 1, 0)
	if crosshair_dot: crosshair_dot.color = Color(1, 1, 1, 0.85)

func _is_desk(col: Object) -> bool:
	if not col: return false
	var n: Node = col as Node
	while n and n != self and n != get_tree().root:
		if n.name == "ComputerDesk" or n.name == "DeskArea" or n.name == "MonitorMesh" or n.name == "TableMesh" or n.is_in_group("computer_desk"):
			return true
		n = n.get_parent()
	return false

func _is_gravity_terminal(col: Object) -> bool:
	if not col: return false
	var n: Node = col as Node
	while n and n != self and n != get_tree().root:
		if n.name == "GravityTerminal" or n.name == "TerminalArea" or n.name == "TerminalBody" or n.name == "ButtonMesh" or n.name == "ScreenMesh" or n.is_in_group("gravity_terminal"):
			return true
		n = n.get_parent()
	return false

func _get_device_display_name(d_type: String) -> String:
	match d_type:
		"spike_wall": return "Dikenli Zemin"
		"electric_wall": return "Elektrikli Zemin Izgarası"
		"magnet_pylon": return "Manyetik Çekim Kulesi"
		"conveyor_crusher": return "Makaralı Balon Öğütücü"
		"sentry_drone": return "Otomatik Lazer Dronu"
		"fan": return "Köşe Fanı"
		_: return "Cihaz"

func _get_device_from_collider(col: Object) -> Dictionary:
	if not col: return {}
	var n: Node = col as Node
	while n and n != self and n != get_tree().root:
		for dev in active_placed_devices:
			if dev and is_instance_valid(dev) and (dev == n or dev.is_ancestor_of(n)):
				var d_type = dev.get_meta("device_type") if dev.has_meta("device_type") else ""
				return {"node": dev, "name": _get_device_display_name(d_type)}
		n = n.get_parent()
	return {}

func save_current_data() -> void:
	if is_loading_save:
		return
	if not is_inside_tree():
		return
	if not save_manager or not game_manager or not shop_manager or not player:
		return
	if not is_instance_valid(player) or not player.is_inside_tree():
		return
		
	var balloons_data: Array = []
	if balloon_container and is_instance_valid(balloon_container) and balloon_container.is_inside_tree():
		for child in balloon_container.get_children():
			if is_instance_valid(child) and child.is_inside_tree() and child is RigidBody3D and not child.is_queued_for_deletion():
				var color_hex = "#ff4757"
				if "balloon_color" in child:
					color_hex = child.balloon_color.to_html(false)
				balloons_data.append({
					"pos": [child.global_position.x, child.global_position.y, child.global_position.z],
					"vel": [child.linear_velocity.x, child.linear_velocity.y, child.linear_velocity.z],
					"color": color_hex
				})
				
	var player_data = {
		"pos": [player.global_position.x, player.global_position.y, player.global_position.z],
		"rot_y": player.rotation.y,
		"head_pitch": player.head.rotation.x if player.head else 0.0,
		"energy": player.current_energy
	}
	
	var upgrades_data = {}
	for up_id in shop_manager.upgrades.keys():
		upgrades_data[up_id] = shop_manager.upgrades[up_id].get("level", 0)
		
	var devices_data = {}
	for dev_id in shop_manager.devices.keys():
		devices_data[dev_id] = {
			"level": shop_manager.devices[dev_id].get("level", 0),
			"count": shop_manager.devices[dev_id].get("count", 0)
		}
	devices_data["gravity_mode"] = current_gravity_idx
	
	var placed_devices_data: Array = []
	for dev in active_placed_devices:
		if is_instance_valid(dev) and dev.visible:
			var d_type = dev.get_meta("device_type") if dev.has_meta("device_type") else ""
			if d_type != "":
				var d_lvl = dev.get("level") if ("level" in dev) else 1
				if d_lvl <= 0: d_lvl = 1
				placed_devices_data.append({
					"type": d_type,
					"pos": [dev.position.x, dev.position.y, dev.position.z],
					"rot_y": dev.rotation.y,
					"level": d_lvl
				})
		
	var coins_data: Array = []
	if coin_container and is_instance_valid(coin_container) and coin_container.is_inside_tree():
		for c in coin_container.get_children():
			if is_instance_valid(c) and not c.is_queued_for_deletion():
				coins_data.append({
					"pos": [c.global_position.x, c.global_position.y, c.global_position.z],
					"val": c.get("coin_value") if ("coin_value" in c) else 1,
					"grounded": c.get("is_grounded") if ("is_grounded" in c) else true
				})
		
	var full_state = {
		"version": 5,
		"current_room": shop_manager.current_room,
		"unlocked_rooms": shop_manager.unlocked_rooms,
		"prestige_level": shop_manager.prestige_level,
		"helium_atoms": shop_manager.helium_atoms,
		"devices": devices_data,
		"placed_devices": placed_devices_data,
		"total_pops": game_manager.total_pops,
		"coins": shop_manager.coins,
		"is_victory_shown": is_victory_shown,
		"playtime_seconds": playtime_seconds,
		"best_speedrun_time": best_speedrun_time,
		"upgrades": upgrades_data,
		"player": player_data,
		"balloons": balloons_data,
		"floor_coins": coins_data
	}
	
	save_manager.save_full_state(full_state)

func load_saved_data() -> void:
	if not save_manager: return
	var data = save_manager.load_full_state()
	if data.is_empty():
		update_pop_counter(0)
		return
		
	is_loading_save = true
	
	is_victory_shown = data.get("is_victory_shown", false)
	playtime_seconds = float(data.get("playtime_seconds", 0.0))
	best_speedrun_time = float(data.get("best_speedrun_time", 0.0))
	var loaded_pops = int(data.get("total_pops", 0))
	var loaded_coins = int(data.get("coins", 0))
	var loaded_upgrades = data.get("upgrades", {})
	var loaded_devices = data.get("devices", {})
	var loaded_player = data.get("player", {})
	var loaded_balloons = data.get("balloons", [])
	var loaded_room = data.get("current_room", "small_room")
	var loaded_unlocked_rooms = data.get("unlocked_rooms", ["small_room"])
	var loaded_prestige = int(data.get("prestige_level", 0))
	var loaded_helium = int(data.get("helium_atoms", 0))
	
	# 1. Restore Rooms & Devices
	if shop_manager:
		shop_manager.unlocked_rooms = loaded_unlocked_rooms
		shop_manager.current_room = loaded_room
		shop_manager.coins = loaded_coins
		shop_manager.prestige_level = loaded_prestige
		shop_manager.helium_atoms = loaded_helium
		if shop_coins_label:
			shop_coins_label.text = "Coin: " + str(loaded_coins) + " 🎈"
			
		for up_id in loaded_upgrades.keys():
			if shop_manager.upgrades.has(up_id):
				var lvl = int(loaded_upgrades[up_id])
				shop_manager.upgrades[up_id]["level"] = lvl
				if player and player.has_method("apply_upgrade"):
					player.apply_upgrade(up_id, lvl)
					
		# Backwards compatibility migration for athlete_training
		if not loaded_upgrades.has("athlete_training") and shop_manager.upgrades.has("athlete_training"):
			var legacy_lvl = max(int(loaded_upgrades.get("energy_cap", 0)), int(loaded_upgrades.get("speed", 0)))
			if legacy_lvl > 0:
				shop_manager.upgrades["athlete_training"]["level"] = legacy_lvl
				if player and player.has_method("apply_upgrade"):
					player.apply_upgrade("athlete_training", legacy_lvl)
				
		for dev_id in loaded_devices.keys():
			if dev_id == "gravity_mode":
				current_gravity_idx = int(loaded_devices[dev_id])
				continue
			if shop_manager.devices.has(dev_id):
				var d_info = loaded_devices[dev_id]
				if d_info is Dictionary:
					shop_manager.devices[dev_id]["level"] = int(d_info.get("level", 0))
					shop_manager.devices[dev_id]["count"] = int(d_info.get("count", 0))
				elif d_info is int or d_info is float:
					shop_manager.devices[dev_id]["level"] = int(d_info)
					shop_manager.devices[dev_id]["count"] = 1 if int(d_info) > 0 else 0
					
				if dev_id == "gravity_regulator":
					max_unlocked_gravity_idx = shop_manager.devices["gravity_regulator"].get("level", 0)
					apply_gravity_to_active_balloons()
					
		# Clear existing placed devices
		for dev in active_placed_devices:
			if is_instance_valid(dev):
				dev.queue_free()
		active_placed_devices.clear()
		
		# Restore exact placed device instances at their exact coordinates
		var loaded_placed = data.get("placed_devices", [])
		for p_data in loaded_placed:
			var d_type = p_data.get("type", "")
			if DEVICE_SCENES.has(d_type) and env_main_room:
				var dev = DEVICE_SCENES[d_type].instantiate()
				dev.set_meta("device_type", d_type)
				dev.add_to_group("devices")
				env_main_room.add_child(dev)
				var pos_arr = p_data.get("pos", [0, 0.05, 0])
				dev.position = Vector3(pos_arr[0], pos_arr[1], pos_arr[2])
				dev.rotation.y = float(p_data.get("rot_y", 0.0))
				var d_lvl = int(p_data.get("level", 1))
				if d_lvl <= 0: d_lvl = 1
				if dev.has_method("setup_level"):
					dev.setup_level(d_lvl)
				else:
					dev.set("level", d_lvl)
				active_placed_devices.append(dev)
				
	# 2. Restore Progress & Stats in Game Manager
	if game_manager:
		game_manager.total_pops = loaded_pops
		game_manager.current_vent_level = int(loaded_upgrades.get("vent_rate", 0))
		game_manager.recalculate_effective_stats()
		
	# 3. Restore Player Transform & Stats (Always safely placed above the floor)
	if player and not loaded_player.is_empty():
		var pos_arr = loaded_player.get("pos", [13.5, 0.6, 0.0])
		var target_pos = Vector3(pos_arr[0], max(float(pos_arr[1]), 0.6), pos_arr[2])
		
		var room_w = 16.0
		var room_l = 16.0
		if shop_manager and shop_manager.has_method("get_current_room_data"):
			var r_data = shop_manager.get_current_room_data()
			if r_data.has("floor_size"):
				room_w = r_data["floor_size"].x
				room_l = r_data["floor_size"].y
			
		var half_w = room_w / 2.0
		var office_center_x = half_w + 5.5
		var in_main_room = abs(target_pos.x) < (half_w - 0.5) and abs(target_pos.z) < (room_l * 0.45)
		var in_office = target_pos.x >= half_w and target_pos.x <= (half_w + 11.0) and abs(target_pos.z) <= 5.5
		
		if not in_main_room and not in_office:
			target_pos = Vector3(office_center_x, 0.6, 0.0)
			
		target_pos.y = max(target_pos.y, 0.6)
		player.global_position = target_pos
		player.velocity = Vector3.ZERO
		player.rotation.y = loaded_player.get("rot_y", 0.0)
		if player.head:
			player.head.rotation.x = loaded_player.get("head_pitch", 0.0)
		player.current_energy = loaded_player.get("energy", player.max_energy)
		player.energy_changed.emit(player.current_energy, player.max_energy, player.is_exhausted)
		
	# 4. Restore Exact Active Balloons in Room
	if balloon_container and balloon_scene:
		for c in balloon_container.get_children():
			c.queue_free()
			
		var safe_balloons = loaded_balloons.slice(0, min(loaded_balloons.size(), 250))
		for b_data in safe_balloons:
			var balloon = balloon_scene.instantiate()
			var pos_arr = b_data.get("pos", [0, 2, 0])
			var vel_arr = b_data.get("vel", [0, 0, 0])
			var col_str = b_data.get("color", "ff4757")
			
			balloon.position = Vector3(pos_arr[0], pos_arr[1], pos_arr[2])
			balloon_container.add_child(balloon)
			
			if balloon is RigidBody3D:
				var idx = clamp(current_gravity_idx, 0, balloon_gravity_scales.size() - 1)
				balloon.linear_velocity = Vector3(vel_arr[0], vel_arr[1], vel_arr[2])
				balloon.gravity_scale = balloon_gravity_scales[idx]
				balloon.linear_damp = balloon_linear_damps[idx]
				
			if balloon.has_method("set_balloon_color"):
				balloon.set_balloon_color(Color.from_string(col_str, Color("#ff4757")))
				
			if balloon.has_signal("popped"):
				balloon.popped.connect(func(_b, pos, col, combo = 0, b_type = 0): 
					if game_manager: 
						game_manager.on_balloon_popped(pos, col, combo, b_type)
				)
				
		if game_manager:
			game_manager.active_balloons = safe_balloons.size()
			
	# 5. Restore Active Floor Coins
	var loaded_floor_coins = data.get("floor_coins", [])
	if coin_container and is_instance_valid(coin_container):
		for c in coin_container.get_children():
			c.queue_free()
		for cd in loaded_floor_coins:
			if coin_scene:
				var coin = coin_scene.instantiate()
				coin_container.add_child(coin)
				var pos_arr = cd.get("pos", [0, 0.08, 0])
				var pos = Vector3(pos_arr[0], pos_arr[1], pos_arr[2])
				var val = int(cd.get("val", 1))
				coin.global_position = pos
				coin.set("coin_value", val)
				coin.set("is_grounded", cd.get("grounded", true))
				coin.set("is_settled", true)
			
	update_pop_counter(loaded_pops)
	update_ceiling_vents()
	update_all_shop_cards()
	
	is_loading_save = false
	
	if game_manager:
		game_manager.start_game()

func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_CLOSE_REQUEST:
		save_current_data()

func _on_spawn_requested(count: int) -> void:
	drop_balloons_from_vent(count)

func _input(event: InputEvent) -> void:
	if startup_modal and startup_modal.visible:
		return
		
	# 1. When carrying a device (Grid Placement Mode)
	if carried_device != null:
		if event is InputEventMouseButton and event.pressed:
			if event.button_index == MOUSE_BUTTON_LEFT:
				place_carried_device()
				get_viewport().set_input_as_handled()
				return
			elif event.button_index == MOUSE_BUTTON_RIGHT:
				cancel_carrying_device()
				get_viewport().set_input_as_handled()
				return
		elif event is InputEventKey and event.pressed and not event.is_echo():
			if event.keycode == KEY_E:
				place_carried_device()
				get_viewport().set_input_as_handled()
				return
			elif event.keycode == KEY_Q or event.keycode == KEY_ESCAPE:
				cancel_carrying_device()
				get_viewport().set_input_as_handled()
				return
			elif event.keycode == KEY_R:
				carried_placement_rot_y += PI * 0.25
				get_viewport().set_input_as_handled()
				return
				
	# 2. Normal Interactions (Raycast crosshair aiming & distance reach)
	if event is InputEventKey and event.pressed and not event.is_echo():
		if event.keycode == KEY_E:
			if raycast_target_type == "desk" or is_near_desk:
				toggle_shop_modal()
			elif raycast_target_type == "device" and raycast_target_device != null and is_instance_valid(raycast_target_device):
				start_carrying_device(raycast_target_device)
			elif raycast_target_type == "gravity_terminal" or is_near_grav_terminal:
				cycle_gravity_mode()
			elif nearby_device != null and is_instance_valid(nearby_device):
				start_carrying_device(nearby_device)
		elif event.keycode == KEY_F:
			if raycast_target_type == "gravity_terminal" or is_near_grav_terminal:
				upgrade_gravity_terminal()
			elif raycast_target_type == "device" and raycast_target_device != null and is_instance_valid(raycast_target_device):
				upgrade_specific_device(raycast_target_device)
			elif nearby_device != null and is_instance_valid(nearby_device):
				upgrade_specific_device(nearby_device)
		elif event.keycode == KEY_G:
			cycle_gravity_mode()
		elif event.keycode == KEY_F1 or event.keycode == KEY_F2 or event.keycode == KEY_QUOTELEFT:
			toggle_debug_panel()
		elif event.keycode == KEY_ESCAPE:
			if debug_panel and debug_panel.visible:
				toggle_debug_panel()
			elif shop_modal and shop_modal.visible:
				toggle_shop_modal()

func toggle_debug_panel() -> void:
	if not debug_panel: return
	debug_panel.toggle_panel()

func upgrade_gravity_terminal() -> void:
	if not shop_manager or not game_manager: return
	var d_data = shop_manager.devices.get("gravity_regulator", {})
	var cur_lvl = d_data.get("level", 0)
	var max_lvl = d_data.get("max_level", 4)
	if cur_lvl >= max_lvl:
		if desk_prompt:
			desk_prompt.text = "Yerçekimi Regülatörü maksimum kademede! (6.00 G)"
			desk_prompt.visible = true
		return
	var costs = d_data.get("costs", [400, 1800, 8500, 35000])
	var cost = costs[cur_lvl]
	if shop_manager.coins < cost:
		if desk_prompt:
			desk_prompt.text = "Yetersiz Coin! Yeni Yerçekimi Modu için " + str(cost) + " Coin gerekli."
			desk_prompt.visible = true
		return
	if shop_manager.buy_device_upgrade("gravity_regulator", game_manager.total_pops):
		if sound_manager and sound_manager.has_method("play_buy"):
			sound_manager.play_buy()
		update_gravity_terminal_display()
		if desk_prompt:
			var new_lvl = shop_manager.devices["gravity_regulator"].get("level", 0)
			var new_mode = gravity_mode_names[new_lvl]
			desk_prompt.text = "Yerçekimi Regülatörü Yükseltildi! Yeni Kademe: [" + new_mode + "]"
			desk_prompt.visible = true

func upgrade_specific_device(d_node: Node3D) -> void:
	if not d_node or not is_instance_valid(d_node) or not shop_manager: return
	var d_type = d_node.get_meta("device_type") if d_node.has_meta("device_type") else ""
	if not shop_manager.devices.has(d_type): return
	
	var d_data = shop_manager.devices[d_type]
	var cur_lvl = d_node.get("level") if ("level" in d_node) else 1
	if cur_lvl <= 0: cur_lvl = 1
	var max_lvl = d_data.get("max_level", 6)
	
	if cur_lvl >= max_lvl:
		if desk_prompt:
			desk_prompt.text = "Bu cihaz zaten maksimum teknoloji seviyesinde! (Sv. " + str(max_lvl) + ")"
			desk_prompt.visible = true
		return
		
	var costs_arr = d_data.get("costs", [500])
	var c_idx = clamp(cur_lvl - 1, 0, costs_arr.size() - 1)
	var cost = costs_arr[c_idx]
	
	var needed_pops = shop_manager.get_device_tech_req_pops(d_type, cur_lvl)
	var total_pops = game_manager.total_pops if game_manager else 0
	if total_pops < needed_pops:
		if desk_prompt:
			desk_prompt.text = "Kilitli! Bu cihazı Sv. " + str(cur_lvl + 1) + " yapmak için " + str(needed_pops) + " Pop gerekli! (İlerleme: " + str(total_pops) + "/" + str(needed_pops) + ")"
			desk_prompt.visible = true
		return
		
	if shop_manager.coins < cost:
		if desk_prompt:
			desk_prompt.text = "Yetersiz Coin! Bu cihazı Sv. " + str(cur_lvl + 1) + " yapmak için " + str(cost) + " Coin gerekli."
			desk_prompt.visible = true
		return
		
	shop_manager.coins -= cost
	shop_manager.coins_changed.emit(shop_manager.coins)
	
	var next_lvl = cur_lvl + 1
	if d_node.has_method("setup_level"):
		d_node.setup_level(next_lvl)
	else:
		d_node.set("level", next_lvl)
		
	# Play upgrade sound & punchy visual scale pulse
	if sound_manager and sound_manager.has_method("play_pop"):
		sound_manager.play_pop(6)
		
	if game_manager and game_manager.has_method("log_timeline_event"):
		game_manager.log_timeline_event("device_tech_inworld", d_type, d_data.get("name", d_type), next_lvl, cost)
		
	var tw = create_tween()
	tw.tween_property(d_node, "scale", Vector3(1.22, 1.22, 1.22), 0.08).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_property(d_node, "scale", Vector3.ONE, 0.12)
	
	save_current_data()
	update_raycast_interaction()

func start_carrying_device(device_node: Node3D, is_new: bool = false, purchase_cost: int = 0) -> void:
	if not device_node or not is_instance_valid(device_node): return
	carried_device = device_node
	is_carrying_new_purchase = is_new
	carried_device_cost = purchase_cost
	carried_original_pos = device_node.position
	carried_original_rot_y = device_node.rotation.y
	carried_placement_rot_y = device_node.rotation.y
	carried_placement_pos = device_node.position
	var g = _get_or_create_grid_ghost()
	if g:
		g.global_position = device_node.position
		g.rotation.y = carried_placement_rot_y
		
func place_carried_device() -> void:
	if not carried_device: return
	_destroy_grid_ghost()
	if sound_manager and sound_manager.has_method("play_pop"):
		sound_manager.play_pop(3)
		
	var dev_to_drop = carried_device
	var target_p = carried_placement_pos
	var target_r_y = carried_placement_rot_y
	carried_device = null
	is_carrying_new_purchase = false
	carried_device_cost = 0
	
	var tw = create_tween()
	tw.set_parallel(true)
	tw.tween_property(dev_to_drop, "position", target_p, 0.12).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tw.tween_property(dev_to_drop, "rotation:y", target_r_y, 0.12)
	tw.tween_property(dev_to_drop, "rotation:x", 0.0, 0.12)
	tw.tween_property(dev_to_drop, "rotation:z", 0.0, 0.12)
	
	save_current_data()
	
func cancel_carrying_device() -> void:
	if not carried_device: return
	_destroy_grid_ghost()
	
	if is_carrying_new_purchase:
		# Refund the player and destroy unplaced instance
		var d_id = carried_device.get_meta("device_type") if carried_device.has_meta("device_type") else ""
		if shop_manager and shop_manager.devices.has(d_id):
			var d_data = shop_manager.devices[d_id]
			d_data["count"] = max(0, d_data.get("count", 1) - 1)
			if carried_device_cost > 0:
				shop_manager.coins += carried_device_cost
				shop_manager.coins_changed.emit(shop_manager.coins)
				
		active_placed_devices.erase(carried_device)
		carried_device.queue_free()
		carried_device = null
		
		if desk_prompt:
			desk_prompt.text = "Satın alma iptal edildi! " + str(carried_device_cost) + " Coin iade edildi."
			desk_prompt.visible = true
			
		is_carrying_new_purchase = false
		carried_device_cost = 0
		update_all_shop_cards()
		save_current_data()
	else:
		# Return existing moved device to its original position
		carried_device.position = carried_original_pos
		carried_device.rotation.y = carried_original_rot_y
		carried_device.rotation.x = 0.0
		carried_device.rotation.z = 0.0
		carried_device = null
		is_carrying_new_purchase = false
		carried_device_cost = 0
		if desk_prompt:
			desk_prompt.text = "Taşıma iptal edildi, cihaz eski yerine bırakıldı."
			desk_prompt.visible = true

func _get_or_create_grid_ghost() -> MeshInstance3D:
	if grid_ghost and is_instance_valid(grid_ghost):
		return grid_ghost
	grid_ghost = MeshInstance3D.new()
	var mesh = BoxMesh.new()
	mesh.size = Vector3(1.48, 0.08, 1.48)
	grid_ghost.mesh = mesh
	var mat = StandardMaterial3D.new()
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.albedo_color = Color(0.1, 0.85, 1.0, 0.45)
	mat.emission_enabled = true
	mat.emission = Color(0.1, 0.85, 1.0)
	mat.emission_energy_multiplier = 1.2
	grid_ghost.material_override = mat
	if env_main_room:
		env_main_room.add_child(grid_ghost)
	return grid_ghost

func _destroy_grid_ghost() -> void:
	if grid_ghost and is_instance_valid(grid_ghost):
		grid_ghost.queue_free()
		grid_ghost = null

func toggle_shop_modal() -> void:
	if not shop_modal: return
	var will_open = not shop_modal.visible
	shop_modal.visible = will_open
	
	if player and player.has_method("set_ui_open"):
		player.set_ui_open(will_open)
	
	if will_open:
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
		update_all_shop_cards()
	else:
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
		save_current_data()

func setup_shop_ui_events() -> void:
	if btn_close_shop:
		btn_close_shop.pressed.connect(func(): toggle_shop_modal())
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

func set_category_filter(filter_name: String) -> void:
	current_filter = filter_name
	
	if btn_tab_upgrades: btn_tab_upgrades.modulate = Color(0.2, 0.9, 1.2) if filter_name == "upgrades" else Color(0.7, 0.7, 0.7)
	if btn_tab_devices: btn_tab_devices.modulate = Color(0.3, 1.2, 0.6) if filter_name == "devices" else Color(0.7, 0.7, 0.7)
	if btn_tab_rooms: btn_tab_rooms.modulate = Color(1.1, 0.4, 1.1) if filter_name == "rooms" else Color(0.7, 0.7, 0.7)
	
	update_all_shop_cards()

func _on_desk_area_entered(body: Node3D) -> void:
	if body.is_in_group("player"):
		is_near_desk = true
		if desk_prompt and not (shop_modal and shop_modal.visible):
			desk_prompt.text = "[E] Bilgisayarı Aç / Dükkana Gir"
			desk_prompt.visible = true

func _on_desk_area_exited(body: Node3D) -> void:
	if body.is_in_group("player"):
		is_near_desk = false
		if desk_prompt: desk_prompt.visible = false
		if shop_modal and shop_modal.visible:
			toggle_shop_modal()

func _on_coins_changed(total_coins: int) -> void:
	if shop_coins_label:
		shop_coins_label.text = "Coin: " + str(total_coins) + " 🎈"
	update_all_shop_cards()

func _on_upgrade_purchased(upgrade_id: String, _level: int) -> void:
	update_all_shop_cards()
	if upgrade_id == "pipe_count":
		update_ceiling_vents()
	if upgrade_id == "fan" and corner_fan:
		corner_fan.visible = true
		corner_fan.set("is_active", true)
	if not is_loading_save:
		save_current_data()

func format_level_pips(level: int, max_level: int) -> String:
	var s = ""
	for i in range(max_level):
		if i < level:
			s += "■ "
		else:
			s += "□ "
	return s.strip_edges()

func update_all_shop_cards() -> void:
	if not upgrades_container or not shop_manager: return
	
	var total_pops = game_manager.total_pops if game_manager else 0
	var card_sort_list: Array = []
	
	for child in upgrades_container.get_children():
		var sort_priority: int = 0
		
		# 1. Device Equipment Cards (Tab: "devices")
		if child.has_meta("device_id"):
			var d_id = child.get_meta("device_id")
			var d_data = shop_manager.devices.get(d_id)
			var matches_filter = (current_filter == "devices")
			child.visible = matches_filter
			
			if not matches_filter or not d_data:
				continue
				
			var title_lbl = child.get_node_or_null("Margin/VBox/Title")
			var desc_lbl = child.get_node_or_null("Margin/VBox/Desc")
			var cost_btn: Button = child.get_node_or_null("Margin/VBox/BtnBuy")
			
			var unlock_req = d_data.get("unlock_pops", 0)
			var is_unlocked = total_pops >= unlock_req
			var cur_count = d_data.get("count", 0)
			var max_count = d_data.get("max_count", 6)
			
			if not is_unlocked and cur_count == 0:
				sort_priority = 1000 + unlock_req
				if title_lbl:
					title_lbl.text = "🔒 " + d_data["name"].to_upper()
					title_lbl.modulate = Color(0.65, 0.68, 0.72)
				if desc_lbl:
					var pct = int(clamp(float(total_pops) / float(max(1, unlock_req)), 0.0, 1.0) * 100)
					desc_lbl.text = "🔒 KİLİTLİ — " + str(unlock_req) + " POP GEREKLİ\nİlerleme: " + str(total_pops) + " / " + str(unlock_req) + " (% " + str(pct) + ")"
					desc_lbl.modulate = Color(1.0, 0.62, 0.25)
				if cost_btn:
					cost_btn.text = "KİLİTLİ"
					cost_btn.disabled = true
			else:
				if d_id == "gravity_regulator":
					var lvl = d_data.get("level", 0)
					var max_lvl = d_data.get("max_level", 4)
					var costs = d_data.get("costs", [400, 1800, 8500, 35000])
					var modes = d_data.get("modes", ["0.25 G (Standart)", "0.80 G (Ağır Döküm)", "1.80 G (Hızlı Şelale)", "3.50 G (Ağır Çöküş)", "6.00 G (Hiper Yerçekimi)"])
					
					if title_lbl:
						title_lbl.text = "Yerçekimi & Gaz Regülatörü  [" + format_level_pips(lvl, max_lvl) + "] (Sv. " + str(lvl) + "/" + str(max_lvl) + ")"
						title_lbl.modulate = Color(0.35, 0.9, 1.0) if lvl > 0 else Color(1, 1, 1)
					if desc_lbl:
						var curr_mode = modes[clamp(lvl, 0, modes.size() - 1)]
						if lvl >= max_lvl:
							desc_lbl.text = "Maksimum Kademe: " + curr_mode + " (Tüm Yerçekimi Kademeleri Açık! [G] ile Değiştir)"
						else:
							var next_mode = modes[lvl + 1]
							desc_lbl.text = "Mevcut: " + curr_mode + " ➔ Yükseltme: [" + next_mode + "]\n[G] tuşu veya duvardaki [E] butonuyla yerçekimini anında değiştirin."
						desc_lbl.modulate = Color(0.85, 0.88, 0.95)
					if cost_btn:
						if lvl >= max_lvl:
							sort_priority = 500
							cost_btn.text = "MAKSİMUM SEVİYE (6.00 G)"
							cost_btn.disabled = true
						else:
							sort_priority = 100
							var next_cost = costs[lvl]
							cost_btn.text = "SEVİYE " + str(lvl + 1) + " AÇ [" + modes[lvl + 1] + "] : " + str(next_cost) + " Coin"
							cost_btn.disabled = (shop_manager.coins < next_cost)
				else:
					if title_lbl:
						title_lbl.text = d_data["name"] + "  |  Sahada: " + str(cur_count) + " / " + str(max_count) + " Adet"
						title_lbl.modulate = Color(0.3, 0.95, 0.6) if cur_count > 0 else Color(1, 1, 1)
					if desc_lbl:
						if d_id == "sentry_drone":
							desc_lbl.text = "Uçan Güvenlik Dronu. Satın alınınca doğrudan yanınıza katılır ve havada süzülür.\nSahadaki filo: " + str(cur_count) + " / " + str(max_count) + " aktif.\n[F] tuşuyla baktığınız dronun seviyesini yükseltebilirsiniz."
						else:
							desc_lbl.text = d_data.get("desc", "") + "\nSatın aldığınızda elinize gelir; [Sol Tık / E] ile ızgaraya yerleştirebilir, [F] ile seviyesini yükseltebilirsiniz."
						desc_lbl.modulate = Color(0.85, 0.88, 0.95)
						
					if cost_btn:
						if cur_count >= max_count:
							sort_priority = 500
							cost_btn.text = "MAX KAPASİTE (" + str(max_count) + "/" + str(max_count) + ")"
							cost_btn.disabled = true
						else:
							var needed_unit_pops = shop_manager.get_device_unit_req_pops(d_id, cur_count) if shop_manager else 0
							var u_costs = d_data.get("unit_costs", d_data.get("costs", [500]))
							var u_cost = u_costs[clamp(cur_count, 0, u_costs.size() - 1)]
							if total_pops < needed_unit_pops:
								sort_priority = 1000 + needed_unit_pops
								cost_btn.text = "🔒 " + str(needed_unit_pops) + " POP GEREKLİ"
								cost_btn.disabled = true
								if desc_lbl:
									desc_lbl.text += "\n🔒 Yeni adet için " + str(needed_unit_pops) + " Pop gerekli! (İlerleme: " + str(total_pops) + "/" + str(needed_unit_pops) + ")"
							else:
								sort_priority = 100
								if cur_count == 0:
									cost_btn.text = "SATIN AL & YERLEŞTİR (1. Adet) : " + str(u_cost) + " Coin"
								else:
									cost_btn.text = "YENİ ADET AL (" + str(cur_count + 1) + "/" + str(max_count) + ") : " + str(u_cost) + " Coin"
								cost_btn.disabled = shop_manager.coins < u_cost

		# 2. Room Expansion Cards (Tab: "rooms")
		elif child.has_meta("room_id"):
			var r_id = child.get_meta("room_id")
			var r_data = shop_manager.rooms.get(r_id)
			var matches_filter = (current_filter == "rooms")
			child.visible = matches_filter
			
			if not matches_filter or not r_data:
				continue
				
			var title_lbl = child.get_node_or_null("Margin/VBox/Title")
			var desc_lbl = child.get_node_or_null("Margin/VBox/Desc")
			var cost_btn: Button = child.get_node_or_null("Margin/VBox/BtnBuy")
			
			var unlock_req = r_data.get("unlock_pops", 0)
			var is_unlocked = total_pops >= unlock_req
			var is_owned = shop_manager.is_room_unlocked(r_id)
			var is_current = (shop_manager.current_room == r_id)
			
			if not is_unlocked and not is_owned:
				sort_priority = 1000 + unlock_req
				if title_lbl:
					title_lbl.text = "🔒 " + r_data["name"].to_upper()
					title_lbl.modulate = Color(0.65, 0.68, 0.72)
				if desc_lbl:
					var pct = int(clamp(float(total_pops) / float(max(1, unlock_req)), 0.0, 1.0) * 100)
					desc_lbl.text = "🔒 KİLİTLİ — " + str(unlock_req) + " POP GEREKLİ\nİlerleme: " + str(total_pops) + " / " + str(unlock_req) + " (% " + str(pct) + ")"
					desc_lbl.modulate = Color(1.0, 0.62, 0.25)
				if cost_btn:
					cost_btn.text = "KİLİTLİ"
					cost_btn.disabled = true
			else:
				if title_lbl:
					if is_current:
						title_lbl.text = r_data["name"] + "  [AKTİF KULLANIMDA]"
						title_lbl.modulate = Color(0.3, 1.0, 0.6)
					elif is_owned:
						title_lbl.text = r_data["name"] + "  [AÇIK / SAHİPSİN]"
						title_lbl.modulate = Color(0.5, 0.85, 1.0)
					else:
						title_lbl.text = r_data["name"]
						title_lbl.modulate = Color(1, 1, 1)
						
				if desc_lbl:
					desc_lbl.text = r_data["desc"]
					desc_lbl.modulate = Color(0.85, 0.88, 0.95)
					
				if cost_btn:
					if is_current:
						sort_priority = 600
						cost_btn.text = "KULLANILIYOR"
						cost_btn.disabled = true
					elif is_owned:
						sort_priority = 120
						cost_btn.text = "ODAYA GEÇİŞ YAP"
						cost_btn.disabled = false
						if not cost_btn.is_connected("pressed", Callable(self, "_on_buy_room_pressed")):
							cost_btn.pressed.connect(Callable(self, "_on_buy_room_pressed").bind(r_id))
					else:
						sort_priority = 100
						var cost = r_data["cost"]
						cost_btn.text = "SATIN AL : " + str(cost) + " Coin"
						cost_btn.disabled = shop_manager.coins < cost
						if not cost_btn.is_connected("pressed", Callable(self, "_on_buy_room_pressed")):
							cost_btn.pressed.connect(Callable(self, "_on_buy_room_pressed").bind(r_id))

		# 3. Standard Upgrade Cards (Tab: "upgrades")
		elif child.has_meta("upgrade_id"):
			var u_id = child.get_meta("upgrade_id")
			var up_data = shop_manager.upgrades.get(u_id)
			if up_data == null:
				child.visible = false
				continue
				
			var matches_filter = (current_filter == "upgrades")
			child.visible = matches_filter
			
			if not matches_filter:
				continue
				
			var title_lbl = child.get_node_or_null("Margin/VBox/Title")
			var desc_lbl = child.get_node_or_null("Margin/VBox/Desc")
			var cost_btn: Button = child.get_node_or_null("Margin/VBox/BtnBuy")
				
			var unlock_req = up_data.get("unlock_pops", 0)
			var is_unlocked = total_pops >= unlock_req
			var lvl = up_data["level"]
			var max_lvl = up_data["max_level"]
			
			if not is_unlocked and lvl == 0:
				sort_priority = 1000 + unlock_req
				if title_lbl:
					title_lbl.text = "🔒 " + up_data["title"].to_upper()
					title_lbl.modulate = Color(0.65, 0.68, 0.72)
				if desc_lbl:
					var pct = int(clamp(float(total_pops) / float(max(1, unlock_req)), 0.0, 1.0) * 100)
					desc_lbl.text = "🔒 KİLİTLİ — " + str(unlock_req) + " POP GEREKLİ\nİlerleme: " + str(total_pops) + " / " + str(unlock_req) + " (% " + str(pct) + ")"
					desc_lbl.modulate = Color(1.0, 0.62, 0.25)
				if cost_btn:
					cost_btn.text = "KİLİTLİ"
					cost_btn.disabled = true
			else:
				if title_lbl:
					title_lbl.text = up_data["title"] + "  [" + format_level_pips(lvl, max_lvl) + "] (Sv. " + str(lvl) + "/" + str(max_lvl) + ")"
					title_lbl.modulate = Color(0.35, 0.9, 1.0) if lvl > 0 else Color(1, 1, 1)
				if desc_lbl:
					if u_id == "pipe_count" and up_data.has("pipes"):
						var curr_p = up_data["pipes"][lvl]
						if lvl >= max_lvl:
							desc_lbl.text = "Maksimum Hat: " + str(curr_p) + " (Tüm 3x3 Izgara Açık!)"
						else:
							var next_p = up_data["pipes"][lvl + 1]
							desc_lbl.text = "Mevcut: " + str(curr_p) + " ➔ Yükseltme: " + str(next_p) + " (Tavana Yeni Boru)"
					elif u_id == "vent_rate" and up_data.has("rates"):
						var curr_r = up_data["rates"][lvl]
						if lvl >= max_lvl:
							desc_lbl.text = "Maksimum Hız: Saniyede " + str(curr_r) + " Balon!"
						else:
							var next_r = up_data["rates"][lvl + 1]
							desc_lbl.text = "Mevcut: " + str(curr_r) + "/sn ➔ Yükseltme: " + str(next_r) + "/sn (Tavandan Akış)"
					elif u_id == "auto_pop" and up_data.has("speeds"):
						var curr_s = up_data["speeds"][lvl]
						if lvl >= max_lvl:
							desc_lbl.text = "Maksimum Seri Hız: " + str(curr_s) + "!"
						else:
							var next_s = up_data["speeds"][lvl + 1]
							desc_lbl.text = "Mevcut: " + str(curr_s) + " ➔ Yükseltme: " + str(next_s) + " (Sol Tıka Basılı Tut)"
					elif u_id == "splash_pop":
						var targets_arr = up_data.get("targets", ["Kapalı", "2 Balon (1.8m)", "3 Balon (2.4m)", "5 Balon (3.0m)", "8 Balon (3.8m)", "12 Balon (4.6m)", "18 Balon (5.5m)", "25 Balon (6.8m)"])
						var curr_t = targets_arr[clamp(lvl, 0, targets_arr.size() - 1)]
						if lvl >= max_lvl:
							desc_lbl.text = "Maksimum Hedef: " + str(curr_t) + " (Aynı Renk Zincirleme)"
						else:
							var next_t = targets_arr[lvl + 1]
							desc_lbl.text = "Mevcut: " + str(curr_t) + " ➔ Yükseltme: " + str(next_t) + " (Aynı Renk Zincirleme)"
					elif u_id == "athlete_training":
						var cur_stamina = 100 + (lvl * 25)
						var cur_spd = lvl * 6
						if lvl >= max_lvl:
							desc_lbl.text = "Maksimum Kondisyon: %d Enerji, +%%%d Hız!" % [cur_stamina, cur_spd]
						else:
							var next_stamina = 100 + ((lvl + 1) * 25)
							var next_spd = (lvl + 1) * 6
							desc_lbl.text = "Mevcut: %d Enerji (+%%%d Hız)\nSonraki: %d Enerji (+%%%d Hız, Hızlı Dolum)" % [cur_stamina, cur_spd, next_stamina, next_spd]
					elif u_id == "coin_magnet" and up_data.has("ranges"):
						var ranges = up_data.get("ranges", ["3.5m", "5.5m", "8.0m", "12.0m", "17.0m", "24.0m", "32.0m", "45.0m"])
						var curr_m = ranges[clamp(lvl, 0, ranges.size() - 1)]
						if lvl >= max_lvl:
							desc_lbl.text = "Maksimum Çekim: " + str(curr_m)
						else:
							var next_m = ranges[clamp(lvl + 1, 0, ranges.size() - 1)]
							desc_lbl.text = "Mevcut: " + str(curr_m) + " ➔ Yükseltme: " + str(next_m) + " Manyetik Vakum"
					else:
						desc_lbl.text = up_data["desc"]
					desc_lbl.modulate = Color(0.85, 0.88, 0.95)
					
				if cost_btn:
					if lvl >= max_lvl:
						sort_priority = 500
						cost_btn.text = "MAX SEVİYE"
						cost_btn.disabled = true
					else:
						var needed_pops = shop_manager.get_upgrade_req_pops(u_id, lvl) if shop_manager else 0
						var cost = up_data["costs"][lvl]
						if total_pops < needed_pops:
							sort_priority = 1000 + needed_pops
							cost_btn.text = "🔒 " + str(needed_pops) + " POP GEREKLİ"
							cost_btn.disabled = true
							if desc_lbl:
								desc_lbl.text += "\n🔒 Seviye " + str(lvl + 1) + " için " + str(needed_pops) + " Pop gerekli! (İlerleme: " + str(total_pops) + "/" + str(needed_pops) + ")"
						else:
							sort_priority = 100
							cost_btn.text = ("SATIN AL : " if lvl == 0 else "GELİŞTİR : ") + str(cost) + " Coin"
							cost_btn.disabled = shop_manager.coins < cost
							if not cost_btn.is_connected("pressed", Callable(self, "_on_buy_button_pressed")):
								cost_btn.pressed.connect(Callable(self, "_on_buy_button_pressed").bind(u_id))
		
		card_sort_list.append({"node": child, "priority": sort_priority})
		
	# Sort cards: available/active at top, locked cards (🔒) at bottom
	card_sort_list.sort_custom(func(a, b): return a["priority"] < b["priority"])
	for i in range(card_sort_list.size()):
		upgrades_container.move_child(card_sort_list[i]["node"], i)

func _on_buy_button_pressed(upgrade_id: String) -> void:
	if shop_manager and game_manager:
		shop_manager.buy_upgrade(upgrade_id, game_manager.total_pops)

func _on_buy_room_pressed(room_id: String) -> void:
	if shop_manager and game_manager:
		shop_manager.buy_room(room_id, game_manager.total_pops)

func _on_buy_device_pressed(device_id: String) -> void:
	if not shop_manager or not game_manager: return
	if device_id == "gravity_regulator":
		if shop_manager.buy_device_upgrade("gravity_regulator", game_manager.total_pops):
			if sound_manager and sound_manager.has_method("play_buy"):
				sound_manager.play_buy()
			update_gravity_terminal_display()
	else:
		shop_manager.buy_device_unit(device_id, game_manager.total_pops)

func _on_buy_tech_pressed(tech_id: String) -> void:
	if not shop_manager or not game_manager: return
	shop_manager.buy_device_upgrade(tech_id, game_manager.total_pops)

func _on_player_pop_triggered(is_hit: bool) -> void:
	pulse_crosshair(is_hit)

func _on_player_nudge_triggered() -> void:
	pulse_crosshair_nudge()

func pulse_crosshair(is_hit: bool) -> void:
	if not crosshair_dot: return
	var tween = create_tween()
	tween.set_parallel(true)
	if is_hit:
		crosshair_dot.scale = Vector2(2.6, 2.6)
		crosshair_dot.color = Color(0.2, 1.0, 0.7, 1.0) # Vibrant lime/cyan hit flash
		tween.tween_property(crosshair_dot, "scale", Vector2.ONE, 0.09).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		tween.tween_property(crosshair_dot, "color", Color(1, 1, 1, 0.85), 0.09)
	else:
		crosshair_dot.scale = Vector2(1.5, 1.5)
		crosshair_dot.color = Color(1.0, 0.8, 0.3, 0.9) # Amber click flash
		tween.tween_property(crosshair_dot, "scale", Vector2.ONE, 0.06).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		tween.tween_property(crosshair_dot, "color", Color(1, 1, 1, 0.85), 0.06)

func pulse_crosshair_nudge() -> void:
	if not crosshair_dot: return
	var tween = create_tween()
	tween.set_parallel(true)
	crosshair_dot.scale = Vector2(1.9, 1.9)
	crosshair_dot.color = Color(0.3, 0.75, 1.0, 0.95) # Cyan breeze flash
	tween.tween_property(crosshair_dot, "scale", Vector2.ONE, 0.12).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween.tween_property(crosshair_dot, "color", Color(1, 1, 1, 0.85), 0.12)

func _on_player_energy_changed(current: float, max_energy: float, is_exhausted: bool) -> void:
	if crosshair_stamina_bar:
		crosshair_stamina_bar.max_value = max_energy
		crosshair_stamina_bar.value = current
		
		var is_full = is_equal_approx(current, max_energy)
		var target_alpha = 0.0 if is_full else 1.0
		
		var tween = create_tween()
		tween.tween_property(crosshair_stamina_bar, "modulate:a", target_alpha, 0.15)
		
		var style = crosshair_stamina_bar.get_theme_stylebox("fill")
		if style is StyleBoxFlat:
			if is_exhausted:
				style.bg_color = Color("#ff4757")
			elif current < (max_energy * 0.35):
				style.bg_color = Color("#ffa502")
			else:
				style.bg_color = Color("#2ed573")

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

func update_pop_counter(pops: int) -> void:
	if pop_count_label:
		var prefix = ""
		if shop_manager and shop_manager.prestige_level > 0:
			prefix = "[★ Prestige %d] " % shop_manager.prestige_level
		var pps = game_manager.pops_per_second if (game_manager and "pops_per_second" in game_manager) else 0
		var pps_str = "  |  " + str(pps) + "/s" if pps > 0 else ""
		pop_count_label.text = prefix + format_number(pops) + " Patlatma" + pps_str
		
	if grand_goal_bar:
		grand_goal_bar.value = min(float(pops), 1000000.0)
		
	if grand_goal_label:
		var target = 1000000
		var remaining = max(0, target - pops)
		var pct = (float(pops) / float(target)) * 100.0
		var eta_str = format_eta(game_manager.get_eta_to_target(target)) if (game_manager and game_manager.has_method("get_eta_to_target")) else "--"
		if pops >= target:
			grand_goal_label.text = "1.000.000 HEDEFİ TAMAMLANDI! (%100)"
			grand_goal_label.add_theme_color_override("font_color", Color("#2ecc71"))
		else:
			grand_goal_label.text = "Hedef: 1.000.000 (%%%0.1f) | Kalan: %s | Tahmini: %s" % [pct, format_number(remaining), eta_str]
			
	if pops >= 1000000 and not is_victory_shown:
		show_victory_screen()

func drop_balloons_from_vent(count: int) -> void:
	if not balloon_scene or not balloon_container:
		return
		
	if active_vent_positions.is_empty():
		update_ceiling_vents()
		
	var idx = clamp(current_gravity_idx, 0, balloon_gravity_scales.size() - 1)
	var grav = balloon_gravity_scales[idx]
	var damp = balloon_linear_damps[idx]
	
	var default_vent_y = 4.0
	if shop_manager and shop_manager.has_method("get_current_room_data"):
		default_vent_y = shop_manager.get_current_room_data().get("ceiling_height", 4.8) - 0.85
		
	for i in range(count):
		var chosen_vent = Vector3(0, default_vent_y, 0)
		if not active_vent_positions.is_empty():
			var v_idx = (vent_cycle_idx + i) % active_vent_positions.size()
			chosen_vent = active_vent_positions[v_idx]
			
		var offset = Vector3(randf_range(-0.35, 0.35), randf_range(-0.1, 0.1), randf_range(-0.35, 0.35))
		var spawn_pos = chosen_vent + offset
		
		# Dynamic Room Tier Distribution (Small room starts at 92% 1x, 8% 5x, 0% 10x/50x!)
		var roll = randf()
		var b_tier = 1
		var room_tw = {1: 0.92, 5: 0.08, 10: 0.0, 50: 0.0}
		if shop_manager and shop_manager.has_method("get_current_room_data"):
			var r_data = shop_manager.get_current_room_data()
			if r_data.has("tier_weights"):
				room_tw = r_data["tier_weights"]
				
		var w50 = room_tw.get(50, 0.0)
		var w10 = room_tw.get(10, 0.0)
		var w5 = room_tw.get(5, 0.08)
		
		if roll < w50:
			b_tier = 50
		elif roll < (w50 + w10):
			b_tier = 10
		elif roll < (w50 + w10 + w5):
			b_tier = 5
		else:
			b_tier = 1

		var balloon = balloon_scene.instantiate()
		balloon.position = spawn_pos
		balloon_container.add_child(balloon)
		if balloon.has_method("setup_tier"):
			balloon.setup_tier(b_tier)
		
		if balloon is RigidBody3D:
			balloon.gravity_scale = grav
			balloon.linear_damp = damp
			var downward_kick = -2.2 * (1.0 + grav * 0.45)
			var spread = Vector3(randf_range(-1.4, 1.4), downward_kick, randf_range(-1.4, 1.4))
			balloon.linear_velocity = spread
			balloon.angular_velocity = Vector3(randf_range(-2, 2), randf_range(-2, 2), randf_range(-2, 2))
			
		if balloon.has_signal("popped"):
			balloon.popped.connect(func(_b, pos, col, combo = 0, b_type = 1): 
				if game_manager: 
					game_manager.on_balloon_popped(pos, col, combo, b_type)
			)
			
		if game_manager and game_manager.has_method("on_balloon_spawned"):
			game_manager.on_balloon_spawned(b_tier)
			
	vent_cycle_idx = (vent_cycle_idx + count) % max(1, active_vent_positions.size())

func spawn_floor_coin(pop_pos: Vector3, val: int = 1, tier: int = 1) -> void:
	if not coin_scene or not coin_container: return
	
	# If floor has too many coins, auto-collect the oldest coin to keep performance crisp
	if coin_container.get_child_count() >= 120:
		var old_coin = coin_container.get_child(0)
		if old_coin and is_instance_valid(old_coin) and old_coin.has_method("collect_coin"):
			old_coin.collect_coin()
			
	var coin = coin_scene.instantiate()
	coin_container.add_child(coin)
	if coin.has_method("init"):
		coin.init(pop_pos, val, tier)

func _on_pop_registered(total: int) -> void:
	update_pop_counter(total)
