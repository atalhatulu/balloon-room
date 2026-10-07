extends Control

var title_label: Label
var desc_label: Label
var timer_label: Label
var progress_label: Label
var panel: PanelContainer
var fps_label: Label

var quest_manager: Node

func _ready() -> void:
	mouse_filter = MOUSE_FILTER_IGNORE
	anchor_left = 0.0
	anchor_top = 0.0
	anchor_right = 1.0
	anchor_bottom = 1.0
	offset_left = 0
	offset_top = 0
	offset_right = 0
	offset_bottom = 0
	
	# Hide the legacy FPS panel from main.tscn if it exists
	var legacy_fps = get_tree().root.get_node_or_null("Main/UI/HUD/FPSPanel")
	if legacy_fps: legacy_fps.hide()

	# 1. Clean FPS Counter - Absolute top right
	var fps_panel = PanelContainer.new()
	fps_panel.name = "FPSPanelContainer"
	fps_panel.mouse_filter = MOUSE_FILTER_IGNORE
	fps_panel.custom_minimum_size = Vector2(90, 32)
	var fps_style = StyleBoxFlat.new()
	fps_style.bg_color = Color(0.05, 0.08, 0.12, 0.9)
	fps_style.border_color = Color(0.2, 0.8, 0.4, 0.8)
	fps_style.set_border_width_all(2)
	fps_style.set_corner_radius_all(6)
	fps_style.content_margin_left = 8
	fps_style.content_margin_right = 8
	fps_style.content_margin_top = 4
	fps_style.content_margin_bottom = 4
	fps_panel.add_theme_stylebox_override("panel", fps_style)
	add_child(fps_panel)
	
	fps_panel.anchor_left = 1.0
	fps_panel.anchor_top = 0.0
	fps_panel.anchor_right = 1.0
	fps_panel.anchor_bottom = 0.0
	fps_panel.offset_left = -110
	fps_panel.offset_top = 20
	fps_panel.offset_right = -20
	fps_panel.offset_bottom = 52

	fps_label = Label.new()
	fps_label.name = "FPSLabel"
	fps_label.mouse_filter = MOUSE_FILTER_IGNORE
	fps_label.text = "60 FPS"
	fps_label.add_theme_font_size_override("font_size", 14)
	fps_label.add_theme_color_override("font_color", Color("00ff66"))
	fps_label.add_theme_color_override("font_outline_color", Color.BLACK)
	fps_label.add_theme_constant_override("outline_size", 2)
	fps_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	fps_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	fps_panel.add_child(fps_label)

	# 2. Quest Panel - Bottom left
	panel = PanelContainer.new()
	panel.name = "QuestPanel"
	panel.mouse_filter = MOUSE_FILTER_IGNORE
	var style = StyleBoxFlat.new()
	style.bg_color = Color(0.06, 0.11, 0.15, 0.85)
	style.border_color = Color(0.16, 0.26, 0.31, 0.6)
	style.set_border_width_all(1)
	style.set_corner_radius_all(8)
	style.shadow_color = Color(0, 0, 0, 0.3)
	style.shadow_size = 6
	panel.add_theme_stylebox_override("panel", style)
	add_child(panel)

	panel.anchor_left = 0.0
	panel.anchor_top = 1.0
	panel.anchor_right = 0.0
	panel.anchor_bottom = 1.0
	panel.offset_left = 20
	panel.offset_top = -120
	panel.offset_right = 280
	panel.offset_bottom = -20

	var margin = MarginContainer.new()
	margin.mouse_filter = MOUSE_FILTER_IGNORE
	margin.add_theme_constant_override("margin_left", 14)
	margin.add_theme_constant_override("margin_right", 14)
	margin.add_theme_constant_override("margin_top", 10)
	margin.add_theme_constant_override("margin_bottom", 10)
	panel.add_child(margin)

	var vbox = VBoxContainer.new()
	vbox.mouse_filter = MOUSE_FILTER_IGNORE
	vbox.add_theme_constant_override("separation", 4)
	margin.add_child(vbox)

	title_label = Label.new()
	title_label.mouse_filter = MOUSE_FILTER_IGNORE
	title_label.add_theme_font_size_override("font_size", 14)
	title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(title_label)

	desc_label = Label.new()
	desc_label.mouse_filter = MOUSE_FILTER_IGNORE
	desc_label.add_theme_font_size_override("font_size", 12)
	desc_label.add_theme_color_override("font_color", Color("e6eff4"))
	desc_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	desc_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	desc_label.custom_minimum_size = Vector2(220, 0)
	vbox.add_child(desc_label)

	var hbox = HBoxContainer.new()
	hbox.mouse_filter = MOUSE_FILTER_IGNORE
	hbox.alignment = BoxContainer.ALIGNMENT_CENTER
	hbox.add_theme_constant_override("separation", 12)
	vbox.add_child(hbox)

	timer_label = Label.new()
	timer_label.mouse_filter = MOUSE_FILTER_IGNORE
	timer_label.add_theme_font_size_override("font_size", 13)
	hbox.add_child(timer_label)

	progress_label = Label.new()
	progress_label.mouse_filter = MOUSE_FILTER_IGNORE
	progress_label.add_theme_font_size_override("font_size", 13)
	progress_label.add_theme_color_override("font_color", Color("90a8b8"))
	hbox.add_child(progress_label)

	_update_idle_state()

func setup(qm: Node) -> void:
	quest_manager = qm
	quest_manager.quest_started.connect(_on_quest_started)
	quest_manager.quest_progress_updated.connect(_on_quest_progress)
	quest_manager.quest_completed.connect(_on_quest_completed)
	quest_manager.quest_failed.connect(_on_quest_failed)
	quest_manager.state_reset.connect(_reset_state)

	_update_idle_state()

var _ui_throttle_timer: float = 0.0
var _last_rendered_sec: int = -1
var _result_time_left := 0.0
var _result_tween: Tween

func _process(delta: float) -> void:
	_result_time_left = maxf(0.0, _result_time_left - delta)
	_ui_throttle_timer += delta
	if _ui_throttle_timer < 0.20:
		return
	_ui_throttle_timer = 0.0
	
	if is_instance_valid(fps_label):
		fps_label.text = "%d FPS" % Engine.get_frames_per_second()
		
	if not quest_manager or _result_time_left > 0:
		return
	if quest_manager.is_active and quest_manager.is_suspended():
		timer_label.text = "Üretim durdu • Görev bekliyor"
		_last_rendered_sec = -1
		return
	if quest_manager.is_active:
		var t = int(ceil(quest_manager.time_left))
		if t != _last_rendered_sec:
			_last_rendered_sec = t
			var mins = t / 60
			var secs = t % 60
			timer_label.text = "⏱ %02d:%02d" % [mins, secs]
			if t <= 10:
				timer_label.add_theme_color_override("font_color", Color.RED)
			else:
				timer_label.add_theme_color_override("font_color", Color("efc379")) # GOLD
	else:
		var t = max(0, int(ceil(quest_manager.cooldown_timer)))
		if t != _last_rendered_sec:
			_last_rendered_sec = t
			var mins = t / 60
			var secs = t % 60
			timer_label.text = "Sıradaki: %02d:%02d" % [mins, secs]
			timer_label.add_theme_color_override("font_color", Color("90a8b8"))

func _update_idle_state() -> void:
	if quest_manager and quest_manager.is_active: return
	title_label.text = "GÖREV BEKLENİYOR"
	title_label.add_theme_color_override("font_color", Color(0.6, 0.7, 0.8, 0.6))
	desc_label.text = ""
	progress_label.text = ""
	desc_label.hide()
	progress_label.hide()

func _on_quest_started(title: String, desc: String, target: int, duration: float, reward: int) -> void:
	_reset_state()
	title_label.text = title
	title_label.add_theme_color_override("font_color", Color("5bdec2")) # ACCENT
	desc_label.text = desc
	desc_label.show()
	progress_label.text = "0 / " + str(target)
	progress_label.show()
	timer_label.add_theme_color_override("font_color", Color("efc379"))

func _on_quest_progress(current: int, target: int) -> void:
	progress_label.text = str(current) + " / " + str(target)

func _on_quest_completed(reward: int) -> void:
	_reset_state()
	_result_time_left = 3.0
	title_label.text = "★ GÖREV TAMAMLANDI! ★"
	title_label.add_theme_color_override("font_color", Color("ffd700"))
	desc_label.text = "+%d Altın Hesabına Yattı!" % reward
	desc_label.show()
	progress_label.hide()
	timer_label.text = "✔ TEBRİKLER"
	timer_label.add_theme_color_override("font_color", Color("2ed573"))
	
	if panel:
		panel.pivot_offset = panel.size / 2.0
		var tw = create_tween()
		_result_tween = tw
		tw.tween_property(panel, "scale", Vector2(1.08, 1.08), 0.15).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		tw.tween_property(panel, "scale", Vector2(1.0, 1.0), 0.25).set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)
		tw.tween_interval(2.6)
		tw.tween_callback(_update_idle_state)
	else:
		var tw = create_tween()
		_result_tween = tw
		tw.tween_interval(2.6)
		tw.tween_callback(_update_idle_state)

func _on_quest_failed() -> void:
	_reset_state()
	_result_time_left = 2.0
	title_label.text = "SÜRE BİTTİ"
	title_label.add_theme_color_override("font_color", Color.RED)
	desc_label.text = "Görevi başaramadın."
	
	var tw = create_tween()
	_result_tween = tw
	tw.tween_interval(2.0)
	tw.tween_callback(_update_idle_state)

func _reset_state() -> void:
	_result_time_left = 0.0
	if _result_tween: _result_tween.kill()
	_result_tween = null
	_last_rendered_sec = -1
	if panel: panel.scale = Vector2.ONE
	_update_idle_state()
