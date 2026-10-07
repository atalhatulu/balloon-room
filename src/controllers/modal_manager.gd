class_name ModalManager
extends Node

signal resume_requested()
signal restart_requested()
signal quit_requested()
signal continue_game_requested()
signal new_game_requested()
signal prestige_requested()
signal new_run_requested()

var _main: Node3D = null

# Modals
var startup_modal: Control = null
var btn_continue: Button = null
var btn_new_game: Button = null
var save_info_label: Label = null

var pause_modal: Control = null
var pause_stats_label: Label = null
var btn_pause_resume: Button = null
var btn_pause_restart: Button = null
var btn_pause_quit: Button = null

var victory_modal: Control = null
var victory_time_stats_label: Label = null
var victory_run_stats_label: Label = null
var btn_close_victory: Button = null
var btn_prestige: Button = null

func setup(main_node: Node3D) -> void:
	_main = main_node
	
	# Startup Modal
	startup_modal = main_node.get_node_or_null("UI/StartupModal")
	btn_continue = main_node.get_node_or_null("UI/StartupModal/Panel/Margin/VBox/Buttons/BtnContinue")
	btn_new_game = main_node.get_node_or_null("UI/StartupModal/Panel/Margin/VBox/Buttons/BtnNewGame")
	save_info_label = main_node.get_node_or_null("UI/StartupModal/Panel/Margin/VBox/SaveInfoLabel")
	
	# Pause Modal
	pause_modal = main_node.get_node_or_null("UI/PauseModal")
	pause_stats_label = main_node.get_node_or_null("UI/PauseModal/Panel/Margin/VBox/StatsLabel")
	btn_pause_resume = main_node.get_node_or_null("UI/PauseModal/Panel/Margin/VBox/BtnResume")
	btn_pause_restart = main_node.get_node_or_null("UI/PauseModal/Panel/Margin/VBox/BtnRestart")
	btn_pause_quit = main_node.get_node_or_null("UI/PauseModal/Panel/Margin/VBox/BtnQuit")
	
	# Victory Modal
	victory_modal = main_node.get_node_or_null("UI/VictoryModal")
	victory_time_stats_label = main_node.get_node_or_null("UI/VictoryModal/Panel/Margin/VBox/TimeStatsLabel")
	victory_run_stats_label = main_node.get_node_or_null("UI/VictoryModal/Panel/Margin/VBox/RunStatsLabel")
	btn_close_victory = main_node.get_node_or_null("UI/VictoryModal/Panel/Margin/VBox/Buttons/BtnCloseVictory")
	btn_prestige = main_node.get_node_or_null("UI/VictoryModal/Panel/Margin/VBox/Buttons/BtnPrestige")
	if victory_modal:
		victory_modal.process_mode = Node.PROCESS_MODE_ALWAYS
	
	_connect_events()

func _connect_events() -> void:
	if btn_continue:
		btn_continue.pressed.connect(func(): continue_game_requested.emit())
	if btn_new_game:
		btn_new_game.pressed.connect(func(): new_game_requested.emit())
		
	if btn_pause_resume:
		btn_pause_resume.pressed.connect(func(): resume_requested.emit())
	if btn_pause_restart:
		btn_pause_restart.pressed.connect(func(): restart_requested.emit())
	if btn_pause_quit:
		btn_pause_quit.pressed.connect(func(): quit_requested.emit())
		
	if btn_close_victory:
		btn_close_victory.pressed.connect(func():
			new_run_requested.emit()
		)
	if btn_prestige:
		btn_prestige.pressed.connect(func(): prestige_requested.emit())

func show_startup_modal(save_info_text: String) -> void:
	if save_info_label:
		save_info_label.text = save_info_text
	if startup_modal:
		startup_modal.visible = true
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE

func hide_startup_modal() -> void:
	if startup_modal:
		startup_modal.visible = false

func toggle_pause_modal(stats_text: String = "") -> bool:
	if startup_modal and startup_modal.visible:
		return false
	if victory_modal and victory_modal.visible:
		return false
		
	var is_paused = not get_tree().paused
	get_tree().paused = is_paused
	
	if pause_modal:
		pause_modal.visible = is_paused
		if is_paused:
			if pause_stats_label and stats_text != "":
				pause_stats_label.text = stats_text
			Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
		else:
			Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
			
	return is_paused

func hide_pause_modal() -> void:
	if get_tree().paused:
		get_tree().paused = false
	if pause_modal:
		pause_modal.visible = false

func show_victory_modal(cur_time_str: String, best_time_str: String, is_new_record: bool, run_stats: String) -> void:
	if victory_time_stats_label:
		var rec_tag = " [★ YENİ REKOR!]" if is_new_record else ""
		victory_time_stats_label.text = "Tamamlama Süresi: %s%s  |  En İyi Rekor: %s" % [cur_time_str, rec_tag, best_time_str]
	if victory_run_stats_label:
		victory_run_stats_label.text = run_stats
	if victory_modal:
		victory_modal.visible = true
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE

func hide_victory_modal() -> void:
	if victory_modal:
		victory_modal.visible = false
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED

func setup_startup_modal(save_manager: Node, shop_manager: Node) -> void:
	if save_manager and save_manager.has_save():
		var data = save_manager.load_full_state()
		var pops = data.get("total_pops", 0)
		var coins = data.get("coins", 0)
		var room_id = data.get("current_room", "small_room")
		var room_title = "Küçük Salon"
		if shop_manager and shop_manager.rooms.has(room_id):
			room_title = shop_manager.rooms[room_id].get("name", "Salon")
			
		var info_text = "Kayıt Detayı: " + str(pops) + " Patlatma | " + str(coins) + " Coin | " + room_title
		show_startup_modal(info_text)
		if _main and _main.player and _main.player.has_method("set_ui_open"):
			_main.player.set_ui_open(true)
	else:
		hide_startup_modal()
		if _main and _main.has_method("start_new_game"):
			_main.start_new_game()

func is_any_blocking_modal_open() -> bool:
	return (startup_modal and startup_modal.visible) or (victory_modal and victory_modal.visible) or (pause_modal and pause_modal.visible)

func handle_escape_key() -> bool:
	if _main.debug_panel and _main.debug_panel.visible:
		_main.toggle_debug_panel()
		return true
	elif _main.theme_modal and _main.theme_modal.visible:
		_main.toggle_theme_modal()
		return true
	elif _main.shop_modal and _main.shop_modal.visible:
		if _main.shop_ui and _main.shop_ui.shop_is_open:
			_main.toggle_shop_modal()
		return true
	elif pause_modal and pause_modal.visible:
		_main.toggle_pause_modal()
		return true
	elif not (startup_modal and startup_modal.visible) and not (victory_modal and victory_modal.visible):
		_main.toggle_pause_modal()
		return true
	return false
