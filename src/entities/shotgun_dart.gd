extends Node3D

const Finish = preload("res://src/entities/weapon_finish.gd")
var muzzle_flash: MeshInstance3D
var flash_left := 0.0
var recoil_roll := 0.0
var motion_time := 0.0

var player: CharacterBody3D
var level := 0
var cooldown := 0.0
var interval := 0.65
var magazine_capacity := 6
var magazine_rounds := 0
var reload_duration := 1.8
var reload_left := 0.0
var pellets := 16
var pierce_per_pellet := 3
var spread_angle := 0.22 # Daha geniş konik saçılma açısı radyan
var reach := 14.0 # Yakın/orta mesafe süpürücü menzil
var model: Node3D
var muzzle: Marker3D
var recoil := 0.0
var draw_weight := 0.0
var pump_slide: Node3D
var badge: Label
var last_hit_count := 0
static var active_shotgun_trails := 0

func setup(owner_player: CharacterBody3D) -> void:
	player = owner_player
	process_priority = 25
	model = Node3D.new()
	model.name = "DartShotgunModel"
	player.hands.right_hand.add_child(model)
	
	# Gövde (Receiver)
	box("Receiver", Vector3(0.12, 0.14, 0.42), Vector3(0, 0.05, -0.15), Color("22333d"))
	# Ağır İkili Namlu (Double Barrel)
	var steel := Finish.material(Color("889ca6"), 0.7)
	var dark := Finish.material(Color("10161a"), 0.2)
	var orange := Finish.material(Color("ff8c2b"), 0.4, true)
	
	Finish.tube(model, 0.028, 0.38, Vector3(-0.025, 0.08, -0.42), steel, "BarrelLeft")
	Finish.tube(model, 0.028, 0.38, Vector3(0.025, 0.08, -0.42), steel, "BarrelRight")
	Finish.tube(model, 0.016, 0.008, Vector3(-0.025, 0.08, -0.612), dark, "BoreLeft")
	Finish.tube(model, 0.016, 0.008, Vector3(0.025, 0.08, -0.612), dark, "BoreRight")
	
	# Pompa / El Kundağı (Pump Grip)
	pump_slide = MeshInstance3D.new()
	pump_slide.name = "PumpSlide"
	var p_box = Finish.beveled_mesh(Vector3(0.11, 0.08, 0.22))
	pump_slide.mesh = p_box
	var pump_mat = Finish.material(Color("18242b"), 0.2)
	pump_slide.material_override = pump_mat
	pump_slide.position = Vector3(0, 0.02, -0.38)
	model.add_child(pump_slide)
	
	for i in range(6):
		Finish.box(pump_slide, Vector3(0.116, 0.009, 0.014), Vector3(0, 0.044, -0.085 + i * 0.032), steel, "PumpRib%d" % i)
	Finish.box(model, Vector3(0.05, 0.022, 0.16), Vector3(0, 0.135, -0.12), dark, "SightRail")
	Finish.box(model, Vector3(0.012, 0.016, 0.016), Vector3(0, 0.146, -0.47), orange, "FrontSight")
	# Kabza (Grip)
	box("Grip", Vector3(0.08, 0.16, 0.09), Vector3(0, -0.07, -0.02), Color("121b21"))
	box("HeatShield", Vector3(0.13, 0.03, 0.28), Vector3(0, 0.12, -0.36), Color("ff8c2b"))
	
	muzzle = Marker3D.new()
	muzzle.position = Vector3(0, 0.08, -0.62)
	model.add_child(muzzle)
	muzzle_flash = Finish.flash(muzzle, Color("ffb243"), 0.045, 0.18)
	model.hide()

func box(part_name: String, dimensions: Vector3, pos: Vector3, color: Color) -> void:
	Finish.box(model, dimensions, pos, Finish.material(color, 0.45), part_name)

func configure(new_level: int) -> void:
	var prev := level
	level = clampi(new_level, 0, 5)
	if level == 0: return
	
	var data: Dictionary = player.get_node("../ShopManager").upgrades.get("shotgun_dart", {})
	if data.is_empty():
		interval = 0.55
		magazine_capacity = 6
		reload_duration = 1.6
		pellets = 8
		pierce_per_pellet = 2
	else:
		interval = float(data.intervals[level - 1])
		magazine_capacity = int(data.magazine_sizes[level - 1])
		reload_duration = float(data.reload_seconds[level - 1])
		pellets = int(data.pellets[level - 1])
		pierce_per_pellet = int(data.pierce[level - 1])
		reach = float(data.get("range", 14.0))
		
	if prev == 0 or magazine_rounds == 0:
		magazine_rounds = magazine_capacity
	else:
		magazine_rounds = mini(magazine_rounds, magazine_capacity)

func equipped() -> bool:
	return level > 0 and player.current_weapon_slot == 3 and not player.is_minigun_frenzy

func _process(delta: float) -> void:
	if not player: return
	cooldown = maxf(0.0, cooldown - delta)
	recoil = lerpf(recoil, 0.0, 1.0 - exp(-16.0 * delta))
	recoil_roll = lerpf(recoil_roll, 0.0, 1.0 - exp(-14.0 * delta))
	motion_time += delta
	flash_left = maxf(0.0, flash_left - delta)
	var hands = player.hands
	var usable: bool = not player.is_ui_open and not hands._is_carrying and not hands._is_tablet_open
	draw_weight = 1.0 - hands.equipment_lower
	model.visible = hands.visual_equipment == 5 and usable
	muzzle_flash.visible = model.visible and flash_left > 0.0
	
	if model.visible:
		var lower: float = smoothstep(0.0, 1.0, hands.equipment_lower)
		model.global_basis = player.camera.global_basis * Basis.from_euler(Vector3(recoil * 3.2 - lower * 0.4, sin(motion_time * 1.5) * 0.003, recoil_roll - lower * 0.12))
		model.global_position = hands.right_hand.global_position + player.camera.global_basis * Vector3(0, 0.02, -0.06 + recoil * 1.5)
		var cycle := 1.0 - clampf(cooldown / maxf(interval, 0.01), 0.0, 1.0)
		var pump := sin(smoothstep(0.12, 0.92, cycle) * PI) if cooldown > 0.0 else 0.0
		pump_slide.position.z = -0.38 + pump * 0.095
		hands.left_hand.global_position = model.to_global(Vector3(0, -0.055, pump_slide.position.z + 0.04))
		hands.left_hand.global_basis = model.global_basis * Basis.from_euler(Vector3(0.35, 0.0, -0.4))
		
	if equipped() and usable and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED and Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT):
		fire()

func fire() -> bool:
	if player.hands.equipment_busy() or player.is_flashlight_on or not equipped() or cooldown > 0.0 or player.is_ui_open or player.hands._is_carrying or player.hands._is_tablet_open:
		return false
		
	cooldown = interval
	recoil = minf(recoil + 0.09, 0.14)
	recoil_roll = randf_range(-0.04, 0.04)
	flash_left = 0.045
	last_hit_count = 0
	
	var space := get_world_3d().direct_space_state
	var origin: Vector3 = player.camera.global_position
	var base_direction: Vector3 = -player.camera.global_basis.z
	var muzzle_pos: Vector3 = muzzle.global_position
	
	# Yatay ağırlıklı eliptik/fan saçılma (Geniş koridor süpürme)
	var spread_h = spread_angle * 1.55
	var spread_v = spread_angle * 0.75
	var impact_points: Array[Vector3] = []
	
	for p in range(pellets):
		var angle := randf_range(0.0, TAU)
		var rad := sqrt(randf())
		var offset_x = cos(angle) * rad * spread_h
		var offset_y = sin(angle) * rad * spread_v
		var pellet_dir: Vector3 = (base_direction + player.camera.global_basis.x * offset_x + player.camera.global_basis.y * offset_y).normalized()
		var end: Vector3 = origin + pellet_dir * reach
		var excluded: Array[RID] = [player.get_rid()]
		
		var wall := space.intersect_ray(PhysicsRayQueryParameters3D.create(origin, end, 1, excluded))
		if not wall.is_empty():
			end = wall.position
			impact_points.append(end)
		
		for hit_idx in range(pierce_per_pellet):
			var hit := space.intersect_ray(PhysicsRayQueryParameters3D.create(origin, end, 2, excluded))
			if hit.is_empty(): break
			var target: Object = hit.collider
			if not target.is_in_group("balloons"): break
			excluded.append(hit.rid)
			if target.has_method("can_pop") and not target.can_pop("shotgun_dart"):
				end = hit.position
				break
			if target.has_method("take_hit"):
				target.take_hit(1, "shotgun_dart")
			elif target.has_method("pop"):
				target.pop("shotgun_dart")
			last_hit_count += 1
			if hit_idx == pierce_per_pellet - 1:
				end = hit.position
				impact_points.append(end)
			
		trail(muzzle_pos, end)
		
	# Ağır patlama şoku (Namlunun önündeki balonları iten ve sarsan hava dalgası)
	if last_hit_count > 0 or not impact_points.is_empty():
		var blast_center = origin + base_direction * 2.5
		if player.has_method("spawn_shockwave_vfx"):
			player.spawn_shockwave_vfx(blast_center, 1.8, Color("ff8c2b"))
		
	player.pop_triggered.emit(last_hit_count > 0)
	var gm = player.get_node_or_null("../GameManager")
	if gm and gm.has_method("record_dart_shot"): gm.record_dart_shot(last_hit_count)
	var sound = player.get_node_or_null("../SoundManager")
	if sound:
		if sound.has_method("play_shotgun_shot"): sound.play_shotgun_shot()
		elif sound.has_method("play_dart_shot"): sound.play_dart_shot()
		
	return true

func trail(start: Vector3, end: Vector3) -> void:
	if active_shotgun_trails >= 36 or start.distance_to(end) < 0.05: return
	active_shotgun_trails += 1
	var dart := MeshInstance3D.new()
	var mesh := BoxMesh.new()
	mesh.size = Vector3(0.035, 0.035, 0.45)
	dart.mesh = mesh
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color("ffb243")
	mat.emission_enabled = true
	mat.emission = Color("ff8c2b")
	mat.emission_energy_multiplier = 2.0
	dart.material_override = mat
	get_tree().current_scene.add_child(dart) if get_tree().current_scene else player.get_parent().add_child(dart)
	dart.global_position = start
	dart.look_at(end)
	dart.tree_exiting.connect(func(): active_shotgun_trails = maxi(0, active_shotgun_trails - 1))
	var tween := dart.create_tween()
	tween.tween_property(dart, "global_position", end, clampf(start.distance_to(end) / 100.0, 0.025, 0.12))
	tween.tween_callback(dart.queue_free)
