class_name EnvironmentController
extends Node

var _main: Node3D = null

var is_blackout: bool = false
var blackout_timer: float = 0.0
var next_blackout_time: float = 240.0
var original_main_light_energy: float = 1.4
var original_main_light_color: Color = Color(1.0, 1.0, 1.0)
var outage_rng := RandomNumberGenerator.new()
var blackout_lights: Dictionary = {}
var alarm_root: Node3D
var alarm_phase := 0.0
var lighting_tweens: Array[Tween] = []
var original_ambient_source: int
var blackout_environment: Environment
var original_ambient_energy := 0.35
var original_ambient_color := Color.WHITE
var original_background_energy := 1.0

func setup(main_node: Node3D) -> void:
	_main = main_node
	outage_rng.randomize()
	next_blackout_time = outage_rng.randf_range(360.0, 540.0)
	var main_room_light: OmniLight3D = _main.get_node_or_null("MainRoomLight")
	if main_room_light:
		original_main_light_energy = main_room_light.light_energy
		original_main_light_color = main_room_light.light_color

func _process(delta: float) -> void:
	_update_alarm(delta)
	# Rastgele elektrik kesintisi kaldırıldı. 
	# Kesinti ve vana patlaması yalnızca basınç %90 üzerinde uzun süre kaldığında tetiklenir.

func trigger_blackout(cause_is_overpressure: bool = false) -> void:
	# Kullanıcı isteği doğrultusunda geçici olarak devre dışı bırakıldı
	return
	if is_blackout:
		return
	is_blackout = true
	blackout_timer = 0.0
	_set_blackout_lighting(true)
		
	# A normal grid trip only needs the generator reset. Physical pipe damage is
	# reserved for a sustained overpressure event.
	if cause_is_overpressure and _main.room_controller and _main.room_controller.broken_pipe and is_instance_valid(_main.room_controller.broken_pipe):
		if _main.room_controller.broken_pipe.has_method("trigger_rupture"):
			_main.room_controller.broken_pipe.trigger_rupture()
			
	if _main.sound_manager:
		if cause_is_overpressure and _main.sound_manager.has_method("play_pipe_burst"):
			_main.sound_manager.play_pipe_burst()
		if _main.sound_manager.has_method("play_power_trip"):
			_main.sound_manager.play_power_trip()
		
	if _main.player and _main.player.has_method("set_flashlight"):
		_main.player.set_flashlight(true)
		
	if _main.room_controller and _main.room_controller.power_room and is_instance_valid(_main.room_controller.power_room):
		if _main.room_controller.power_room.has_method("set_blackout_state"):
			_main.room_controller.power_room.set_blackout_state(false)
			
	if _main.hud_controller:
		if cause_is_overpressure:
			_main.hud_controller.show_prompt("AŞIRI BASINÇ! Boru Patladı & Şebeke Çöktü! Duvardaki Boruyu Onar [E]", 5.0)
		else:
			_main.hud_controller.show_prompt("ELEKTRİK KESİNTİSİ! Jeneratör Odasındaki Panoyu Aç [E]", 5.0)

func repair_pipe() -> void:
	var damaged_pipe = _main.room_controller.broken_pipe if _main.room_controller else null
	if not is_instance_valid(damaged_pipe) or not damaged_pipe.is_ruptured:
		return
	if _main.room_controller and _main.room_controller.broken_pipe and is_instance_valid(_main.room_controller.broken_pipe):
		if _main.room_controller.broken_pipe.has_method("repair"):
			_main.room_controller.broken_pipe.repair()
			
	if _main.sound_manager and _main.sound_manager.has_method("play_pipe_repair"):
		_main.sound_manager.play_pipe_repair()
		
	if _main.shop_manager and _main.shop_manager.has_method("add_coins"):
		_main.shop_manager.add_coins(250)
		
	if _main.hud_controller:
		_main.hud_controller.show_prompt("BORU ONARILDI! Şimdi Jeneratör Şalterini Kaldır [E] (+250 Coin)", 4.0)

func restore_power() -> void:
	if not is_blackout:
		return
		
	# Check if pipe is still ruptured before allowing power restore
	var pipe = _main.room_controller.broken_pipe if (_main.room_controller and "broken_pipe" in _main.room_controller) else null
	if pipe and ("is_ruptured" in pipe) and pipe.is_ruptured:
		if _main.sound_manager:
			_main.sound_manager.play_interaction("denied", _main.room_controller.power_room.global_position)
		if _main.hud_controller:
			_main.hud_controller.show_prompt("GÜVENLİK KİLİDİ: Önce Duvardaki Patlak Boruyu Onar!", 3.0)
		return
		
	is_blackout = false
	blackout_timer = 0.0
	if _main:
		_main.blackout_cooldown_timer = 90.0
	_set_blackout_lighting(false)
		
	if _main.player and _main.player.has_method("set_flashlight"):
		_main.player.set_flashlight(false)
		
	if _main.sound_manager and _main.sound_manager.has_method("play_zap"):
		_main.sound_manager.play_zap()
		
	if _main.room_controller and _main.room_controller.power_room and is_instance_valid(_main.room_controller.power_room):
		if _main.room_controller.power_room.has_method("trigger_restore_switch"):
			_main.room_controller.power_room.trigger_restore_switch()
			
	if _main.shop_manager and _main.shop_manager.has_method("add_coins"):
		_main.shop_manager.add_coins(500)
				
	if _main.sound_manager and _main.sound_manager.has_method("play_gold_pop"):
		_main.sound_manager.play_gold_pop()
		
	if _main.hud_controller:
		_main.hud_controller.show_prompt("ELEKTRİK GELDİ! Borular Yeniden Çalışıyor (+500 Coin)", 3.0)

func _set_blackout_lighting(enabled: bool) -> void:
	var modes = _main.get_node_or_null("LightingModes")
	if modes:
		modes.apply_state()
		return
	for active_tween in lighting_tweens:
		if active_tween.is_valid(): active_tween.kill()
	lighting_tweens.clear()
	if enabled:
		blackout_lights.clear()
		var pipe = _main.room_controller.broken_pipe if _main.room_controller else null
		var power = _main.room_controller.power_room if _main.room_controller else null
		for node in _main.find_children("*", "Light3D", true, false):
			var light := node as Light3D
			if not light or light == _main.player.flashlight or light.is_in_group("emergency_beacon"):
				continue
			if pipe and "warning_light" in pipe and light == pipe.warning_light:
				continue # Keep the emergency pipe beacon visible.
			if power and "emergency_light" in power and light == power.emergency_light:
				continue # Keep the generator room's emergency beacon visible.
			blackout_lights[light] = {"energy": light.light_energy, "color": light.light_color}
			var tween := _main.create_tween()
			lighting_tweens.append(tween)
			tween.tween_property(light, "light_energy", 0.0, 0.45).set_trans(Tween.TRANS_QUAD)
			tween.parallel().tween_property(light, "light_color", Color("34415d"), 0.45)
		var main_light: Light3D = _main.get_node_or_null("MainRoomLight")
		if main_light:
			original_main_light_energy = main_light.light_energy
			original_main_light_color = main_light.light_color
		blackout_environment = _main.get_node_or_null("WorldEnvironment").environment if _main.get_node_or_null("WorldEnvironment") else null
		if blackout_environment:
			original_ambient_source = blackout_environment.ambient_light_source
			blackout_environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
			original_ambient_energy = blackout_environment.ambient_light_energy
			original_ambient_color = blackout_environment.ambient_light_color
			original_background_energy = blackout_environment.background_energy_multiplier
			var env_tween := _main.create_tween()
			lighting_tweens.append(env_tween)
			env_tween.tween_property(blackout_environment, "ambient_light_energy", 0.012, 0.55)
			env_tween.parallel().tween_property(blackout_environment, "ambient_light_color", Color("263047"), 0.55)
			env_tween.parallel().tween_property(blackout_environment, "background_energy_multiplier", 0.015, 0.55)
	else:
		for light in blackout_lights:
			if not is_instance_valid(light):
				continue
			var state: Dictionary = blackout_lights[light]
			var tween := _main.create_tween()
			lighting_tweens.append(tween)
			tween.tween_property(light, "light_energy", float(state.energy), 0.65).set_trans(Tween.TRANS_SINE)
			tween.parallel().tween_property(light, "light_color", state.color, 0.65)
		blackout_lights.clear()
		if blackout_environment:
			var env_tween := _main.create_tween()
			lighting_tweens.append(env_tween)
			env_tween.tween_property(blackout_environment, "ambient_light_energy", original_ambient_energy, 0.65)
			env_tween.parallel().tween_property(blackout_environment, "ambient_light_color", original_ambient_color, 0.65)
			env_tween.parallel().tween_property(blackout_environment, "background_energy_multiplier", original_background_energy, 0.65)
			blackout_environment.ambient_light_source = original_ambient_source
		blackout_environment = null

func trigger_quest_celebration() -> void:
	if not _main: return
	var main_room_light: OmniLight3D = _main.get_node_or_null("MainRoomLight")
	if not main_room_light or is_blackout: return
	
	# Warm celebration light pulse (Golden / Cyan surge then smooth return)
	var orig_energy = original_main_light_energy
	var orig_color = original_main_light_color
	var tw = _main.create_tween()
	tw.tween_property(main_room_light, "light_energy", orig_energy * 1.85, 0.18).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tw.parallel().tween_property(main_room_light, "light_color", Color.WHITE, 0.18)
	tw.tween_property(main_room_light, "light_energy", orig_energy * 0.90, 0.22)
	tw.parallel().tween_property(main_room_light, "light_color", Color.WHITE, 0.22)
	tw.tween_property(main_room_light, "light_energy", orig_energy * 1.40, 0.15)
	tw.tween_property(main_room_light, "light_energy", orig_energy, 0.35).set_trans(Tween.TRANS_SINE)
	tw.parallel().tween_property(main_room_light, "light_color", orig_color, 0.35)

func _update_alarm(_delta: float) -> void:
	# RoomStatusRig owns the four permanent ceiling beacons in every room.
	if is_instance_valid(alarm_root):
		alarm_root.queue_free()
		alarm_root = null
