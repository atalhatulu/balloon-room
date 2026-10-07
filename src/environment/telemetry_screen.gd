class_name TelemetryScreen
extends Node3D

# Dynamic In-Game Laboratory Computer Screen
# Renders authentic real-time live telemetry into 3D world space:
# Screen 0: Production & PPS Telemetry (Hız, PPS, Dakikalık üretim)
# Screen 1: Pressure & Room Capacity (Basınç %, aktif balon, limit)
# Screen 2: Grand Goal ETA & Progress (1M hedefe kalan süre, tamamlanma %)
# Screen 3: Economy & Automation Status (Toplam coin, kurulu cihazlar, prestij)

var screen_mode: int = 0

var title_lbl: Label3D = null
var main_stat_lbl: Label3D = null
var sub_stat_lbl: Label3D = null
var graph_line_lbl: Label3D = null

var game_manager: Node = null
var shop_manager: Node = null
var main_node: Node = null

var _update_timer: float = 0.0

func _ready() -> void:
	_setup_labels()
	_fetch_managers()
	_update_display()
	_update_timer = -float(get_instance_id() % 7) * 0.07

func _setup_labels() -> void:
	# Clean terminal styling: cyan & amber retro-modern industrial look
	title_lbl = _create_label(Vector3(0, 0.22, 0.002), 26, Color(0.35, 0.85, 1.0))
	main_stat_lbl = _create_label(Vector3(0, 0.05, 0.002), 44, Color(0.95, 0.98, 1.0))
	sub_stat_lbl = _create_label(Vector3(0, -0.11, 0.002), 24, Color(0.68, 0.82, 0.90))
	graph_line_lbl = _create_label(Vector3(0, -0.23, 0.002), 20, Color(0.30, 0.75, 0.70))

func _create_label(pos: Vector3, font_size: int, color: Color) -> Label3D:
	var lbl = Label3D.new()
	lbl.position = pos
	lbl.font_size = font_size
	lbl.pixel_size = 0.0028
	lbl.modulate = color
	lbl.outline_size = 2
	lbl.outline_modulate = Color(0.02, 0.05, 0.08, 0.9)
	lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	add_child(lbl)
	return lbl

func _fetch_managers() -> void:
	main_node = get_node_or_null("/root/Main")
	if main_node:
		game_manager = main_node.get("game_manager")
		shop_manager = main_node.get("shop_manager")

func _process(delta: float) -> void:
	# Update 2 times per second (smooth enough, zero performance drag)
	_update_timer += delta
	if _update_timer < 0.50:
		return
	_update_timer = 0.0
	var camera := get_viewport().get_camera_3d()
	if camera:
		var to_camera := camera.global_position - global_position
		if to_camera.length_squared() > 900.0 or global_basis.z.dot(to_camera) <= 0.0 or camera.is_position_behind(global_position):
			return
	if not game_manager or not shop_manager:
		_fetch_managers()
		
	_update_display()

func _update_display() -> void:
	if not game_manager or not shop_manager:
		if title_lbl: title_lbl.text = "SİSTEM BAŞLATILIYOR..."
		return

	var pops: int = game_manager.get("total_pops") if ("total_pops" in game_manager) else 0
	var pps: float = game_manager.get("smooth_pps") if ("smooth_pps" in game_manager) else 0.0
	var active_b: int = game_manager.get_physical_balloon_count() if game_manager.has_method("get_physical_balloon_count") else int(game_manager.get("active_balloons"))
	var max_b: int = max(1, game_manager.get_physics_budget() if game_manager.has_method("get_physics_budget") else int(game_manager.get("max_room_balloons")))
	var pressure_pct = clamp(int((float(active_b) / float(max_b)) * 100.0), 0, 100)
	var coins: int = shop_manager.coins if shop_manager else 0
	var current_room = shop_manager.current_room if shop_manager else "small_room"
	
	match screen_mode:
		0:
			# Screen 0: PATLAYAN BALON / SÜRE (CANLI DALGA GRAFİĞİ + SEANS HAFIZASI)
			var inactivity: float = game_manager.get("pop_inactivity_timer") if ("pop_inactivity_timer" in game_manager) else 0.0
			var is_holding = (pps < 1.0 and inactivity >= 3.0)
			
			var pps_hist: Array = []
			var display_pps: float = pps
			
			if is_holding:
				title_lbl.text = "GRAFİK: SON SEANS RAPORU"
				title_lbl.modulate = Color(0.95, 0.75, 0.25)
				pps_hist = game_manager.get("last_active_pps_history") if ("last_active_pps_history" in game_manager) else []
				display_pps = game_manager.get("last_active_pps") if ("last_active_pps" in game_manager) else 0.0
			else:
				title_lbl.text = "GRAFİK: PATLATMA / SÜRE"
				title_lbl.modulate = Color(0.30, 0.85, 1.0)
				pps_hist = game_manager.get("pps_history") if ("pps_history" in game_manager) else []
				
			var wave_chart: String = _build_waveform_graph(pps_hist, display_pps)
			
			main_stat_lbl.text = wave_chart
			main_stat_lbl.modulate = Color(0.95, 0.80, 0.25) if is_holding else (Color(0.20, 0.95, 0.70) if pps > 5.0 else Color(0.40, 0.80, 0.95))
			
			var last_min = game_manager.get("last_minute_pops") if ("last_minute_pops" in game_manager) else 0
			if is_holding:
				sub_stat_lbl.text = "Seans Hızı: %.1f Pop/sn  |  Zirve: %.1f" % [display_pps, game_manager.get("peak_pps") if ("peak_pps" in game_manager) else 0.0]
				graph_line_lbl.text = "Son 1 Dk: %s Balon  |  [BEKLEMEDE]" % _format_num(last_min)
			else:
				sub_stat_lbl.text = "Anlık Akış: %.1f Pop/sn  |  Zirve: %.1f" % [pps, game_manager.get("peak_pps") if ("peak_pps" in game_manager) else 0.0]
				graph_line_lbl.text = "Son 1 Dk: %s Balon  |  Toplam: %s" % [_format_num(last_min), _format_num(pops)]
			
		1:
			# Screen 1: ODA BASINÇ & DOLULUK SEVİYESİ
			title_lbl.text = "BASINÇ & DOLULUK İZLEME"
			var overload_time: float = 4.5
			if main_node and "_overpressure_hazard_timer" in main_node:
				overload_time = maxf(0.0, 4.5 - float(main_node.get("_overpressure_hazard_timer")))
			var is_critical = pressure_pct >= 85
			title_lbl.modulate = Color(1.0, 0.35, 0.35) if is_critical else Color(0.35, 0.85, 1.0)
			main_stat_lbl.text = "%%%d DOLULUK" % pressure_pct
			main_stat_lbl.modulate = Color(1.0, 0.30, 0.30) if is_critical else (Color(1.0, 0.78, 0.20) if pressure_pct >= 65 else Color(0.35, 0.90, 1.0))
			sub_stat_lbl.text = "%d / %d Balon Sınırı" % [active_b, max_b]
			if main_node and bool(main_node.get("is_blackout")):
				graph_line_lbl.text = "ARIZA: ELEKTRİK KESİK • JENERATÖRÜ ONAR"
			elif is_critical:
				graph_line_lbl.text = "BORU ARIZASI RİSKİ • %.1f sn" % overload_time
			else:
				graph_line_lbl.text = "DURUM: " + ("YÜKSEK DOLULUK" if pressure_pct >= 65 else "OPTİMAL AKIŞ")
			
		2:
			# Screen 2: 1M HEDEFİ & TAHMİNİ SÜRE (ETA)
			title_lbl.text = "HEDEF: 1.000.000 BALON"
			title_lbl.modulate = Color(0.95, 0.75, 0.25)
			var target = 1000000
			var progress_pct = (float(pops) / float(target)) * 100.0
			main_stat_lbl.text = "%%%0.2f" % progress_pct
			main_stat_lbl.modulate = Color(0.98, 0.85, 0.25)
			
			var eta_sec = game_manager.get_eta_to_target(target) if game_manager.has_method("get_eta_to_target") else -1.0
			# If user stopped walking to screen, compute ETA using last_minute_pops rate instead of 0
			if eta_sec < 0.0:
				var last_min_rate = float(game_manager.get("last_minute_pops")) / 60.0 if ("last_minute_pops" in game_manager) else 0.0
				if last_min_rate > 0.5:
					eta_sec = float(target - pops) / last_min_rate
					
			var eta_str = _format_eta(eta_sec)
			sub_stat_lbl.text = "Kalan Süre (ETA): %s" % eta_str
			graph_line_lbl.text = "Hedefe Kalan: %s Balon" % _format_num(maxi(0, target - pops))
			
		3:
			# Screen 3: EKONOMİ & TESİS OTOMASYONU
			title_lbl.text = "TESİS DURUMU & OTOMASYON"
			title_lbl.modulate = Color(0.40, 0.85, 0.95)
			main_stat_lbl.text = "%s COIN" % _format_num(coins)
			main_stat_lbl.modulate = Color(0.98, 0.82, 0.20)
			var dev_count = shop_manager.get_total_placed_devices() if shop_manager.has_method("get_total_placed_devices") else 0
			var max_dev = shop_manager.get_current_room_max_devices() if shop_manager.has_method("get_current_room_max_devices") else 4
			sub_stat_lbl.text = "Cihazlar: %d / %d Aktif" % [dev_count, max_dev]
			var prest: int = shop_manager.prestige_level if ("prestige_level" in shop_manager) else 0
			var power_status := "ŞEBEKE: KESİK" if main_node and bool(main_node.get("is_blackout")) else "ŞEBEKE: AKTİF"
			graph_line_lbl.text = "%s  |  %s  |  Prestij: Lvl %d" % [current_room.capitalize(), power_status, prest]

		4:
			var elapsed: float = game_manager.session_elapsed_time
			var rate: float = float(game_manager.last_minute_pops) / maxf(1.0, game_manager.minute_measured_seconds)
			var remaining: int = maxi(0, 1000000 - pops)
			var eta := "Ölçülüyor" if rate < 0.5 else _format_eta(float(remaining) / rate)
			if remaining == 0: eta = "Tamamlandı"
			var state := "ÜRETİM AÇIK" if game_manager.production_enabled else "ÜRETİM DURDU"
			var pipe = main_node.room_controller.broken_pipe
			if main_node.is_blackout:
				state = "BORU KAÇAĞI • VANAYI ONAR" if is_instance_valid(pipe) and pipe.is_ruptured else "ELEKTRİK KESİK • PANOYU AÇ"
			elif shop_manager.pending_room != "":
				state = "PORTAL HAZIR" if active_b == 0 else "GEÇİŞ • %d BALON KALDI" % active_b
			title_lbl.text = state + " • BASINÇ %" + str(pressure_pct)
			title_lbl.modulate = Color("ff7655") if main_node.is_blackout else Color("66ded5")
			# The percentage sign is literal; format the numeric percentage separately.
			main_stat_lbl.text = "%s / 1.000.000 • " % _format_num(pops) + "%.1f%%" % minf(100.0, pops / 10000.0)
			sub_stat_lbl.text = "Anlık %.1f/sn • Ort. %.1f/sn (son 60 sn)" % [pps, rate]
			graph_line_lbl.text = "1M tahmini: %s • Süre: %s" % [eta, game_manager.format_time(elapsed)]
	# Keep all telemetry inside the existing small PC bezels too.
	var labels := [title_lbl, main_stat_lbl, sub_stat_lbl, graph_line_lbl]
	for i in range(labels.size()):
		var max_font: int = [26, 44, 24, 20][i]
		var wanted_font := mini(max_font, maxi(12, int(360.0 / maxf(1.0, labels[i].text.length() * 0.62))))
		if labels[i].font_size != wanted_font: labels[i].font_size = wanted_font

func _build_waveform_graph(history: Array, current_pps: float) -> String:
	# Sparkline characters representing levels from lowest to highest
	var blocks = [" ", " ", "▂", "▃", "▄", "▅", "▆", "▇", "█"]
	var pts: Array = []
	for v in history:
		pts.append(float(v))
	if pts.is_empty():
		pts.append(current_pps)
		
	# Find max value in history to normalize wave peaks
	var max_v: float = 1.0
	for v in pts:
		if v > max_v:
			max_v = v
			
	# Pad to 20 columns if history is just starting
	var wave_str = ""
	var start_idx = maxi(0, pts.size() - 20)
	var visible_pts = pts.slice(start_idx)
	while visible_pts.size() < 20:
		visible_pts.push_front(0.0)
		
	for val in visible_pts:
		var ratio = clamp(val / max_v, 0.0, 1.0)
		var idx = int(round(ratio * 8.0))
		wave_str += blocks[idx]
		
	return wave_str

func _format_num(val: int) -> String:
	var s = str(val)
	var res = ""
	var cnt = 0
	for i in range(s.length() - 1, -1, -1):
		res = s[i] + res
		cnt += 1
		if cnt % 3 == 0 and i > 0:
			res = "." + res
	return res

func _format_eta(seconds_val: float) -> String:
	if seconds_val < 0.0:
		return "--"
	if seconds_val <= 0.0:
		return "Tamamlandı"
	var total_sec = int(seconds_val)
	if total_sec < 60:
		return "~%d sn" % total_sec
	elif total_sec < 3600:
		return "~%d dk" % int(total_sec / 60)
	else:
		var hrs = int(total_sec / 3600)
		var mins = int((total_sec % 3600) / 60)
		return "~%d sa %d dk" % [hrs, mins]
