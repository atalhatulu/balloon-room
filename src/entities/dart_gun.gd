extends Node3D

const Finish = preload("res://src/entities/weapon_finish.gd")
var muzzle_flash: MeshInstance3D
var flash_left := 0.0
var recoil_roll := 0.0
var motion_time := 0.0

# Fast dart flight is represented by an instantaneous hit plus a moving dart trail.
# The camera selects the aim point; a second trace from the muzzle prevents cover clipping.
var player: CharacterBody3D
var level := 0
var cooldown := 0.0
var interval := 0.25
var magazine_capacity := 10
var magazine_rounds := 0
var reload_duration := 1.4
var reload_left := 0.0
var pierce := 1
var ricochet_targets := 0
var ricochet_radius := 0.0
var reach := 24.0
var model: Node3D
var muzzle: Marker3D
var recoil := 0.0
var draw_weight := 0.0
var slide: Node3D
var badge: Label
var last_hit_count := 0
static var active_trails := 0

func setup(owner_player: CharacterBody3D) -> void:
	player = owner_player
	process_priority = 25
	model = Node3D.new()
	model.name = "DartPistolModel"
	player.hands.right_hand.add_child(model)
	box("Receiver", Vector3(0.105, 0.12, 0.26), Vector3(0, 0.045, -0.11), Color("283e49"))
	box("UpperRail", Vector3(0.065, 0.035, 0.30), Vector3(0, 0.12, -0.13), Color("d5dde0"))
	slide = model.get_node("UpperRail")
	box("Grip", Vector3(0.075, 0.14, 0.08), Vector3(0, -0.065, -0.015), Color("15232c"))
	box("Cartridge", Vector3(0.045, 0.07, 0.15), Vector3(0.072, 0.04, -0.075), Color("e7a33f"))
	box("Sight", Vector3(0.018, 0.03, 0.018), Vector3(0, 0.145, -0.24), Color("68ead4"))
	var barrel := MeshInstance3D.new()
	var cylinder := CylinderMesh.new()
	cylinder.top_radius = 0.025
	cylinder.bottom_radius = 0.032
	cylinder.height = 0.20
	cylinder.radial_segments = 12
	barrel.mesh = cylinder
	barrel.rotation.x = PI / 2
	barrel.position = Vector3(0, 0.05, -0.30)
	var metal := StandardMaterial3D.new()
	metal.albedo_color = Color("9db6bd")
	metal.metallic = 0.7
	barrel.material_override = metal
	model.add_child(barrel)
	muzzle = Marker3D.new()
	muzzle.position = Vector3(0, 0.05, -0.405)
	model.add_child(muzzle)
	var steel := Finish.material(Color("b4c4cd"))
	var rubber := Finish.material(Color("12232d"), 0.1)
	var teal := Finish.material(Color("55dfc1"), 0.3, true)
	Finish.tube(model, 0.041, 0.055, Vector3(0, 0.05, -0.36), steel, "MuzzleCollar")
	Finish.tube(model, 0.023, 0.006, Vector3(0, 0.05, -0.391), rubber, "Bore")
	for i in range(5):
		Finish.box(model, Vector3(0.079, 0.008, 0.084), Vector3(0, -0.12 + i * 0.021, -0.015), rubber, "GripRib%d" % i)
	for side in [-1, 1]:
		Finish.box(model, Vector3(0.012, 0.065, 0.15), Vector3(side * 0.058, 0.055, -0.115), steel, "SidePlate%d" % side)
		Finish.box(model, Vector3(0.014, 0.008, 0.09), Vector3(side * 0.066, 0.061, -0.12), teal, "ChargeStrip%d" % side)
	Finish.box(model, Vector3(0.085, 0.013, 0.07), Vector3(0, -0.04, -0.09), steel, "TriggerGuard")
	muzzle_flash = Finish.flash(muzzle, Color("88ffdf"), 0.015, 0.09)
	model.hide()
	badge = Label.new()
	badge.name = "WeaponBadge"
	badge.mouse_filter = Control.MOUSE_FILTER_IGNORE
	badge.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	badge.add_theme_color_override("font_color", Color("a6f1e4"))
	badge.add_theme_color_override("font_outline_color", Color("14232b"))
	badge.add_theme_constant_override("outline_size", 4)
	player.get_parent().get_node("UI").add_child(badge)
	badge.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_RIGHT)
	badge.offset_left = -370
	badge.offset_right = -24
	badge.offset_top = -62
	badge.offset_bottom = -24

func box(part_name: String, dimensions: Vector3, pos: Vector3, color: Color) -> void:
	Finish.box(model, dimensions, pos, Finish.material(color, 0.45), part_name)

func configure(new_level: int) -> void:
	var previous_level := level
	level = clampi(new_level, 0, 5)
	if level == 0: return
	var data: Dictionary = player.get_node("../ShopManager").upgrades.dart_gun
	interval = float(data.intervals[level - 1])
	magazine_capacity = int(data.magazine_sizes[level - 1])
	reload_duration = float(data.reload_seconds[level - 1])
	if previous_level == 0 or magazine_rounds == 0:
		magazine_rounds = magazine_capacity
	else:
		magazine_rounds = mini(magazine_rounds, magazine_capacity)
	pierce = int(data.pierce[level - 1])
	ricochet_targets = int(data.ricochet_targets[level - 1])
	ricochet_radius = float(data.ricochet_radius[level - 1])
	reach = float(data.range)

func equipped() -> bool:
	return level > 0 and player.current_weapon_slot == 2 and not player.is_minigun_frenzy

func _process(delta: float) -> void:
	if not player: return
	cooldown = maxf(0.0, cooldown - delta)
	# Exponential recovery remains stable during long frames.
	recoil = lerpf(recoil, 0.0, 1.0 - exp(-18.0 * delta))
	recoil_roll = lerpf(recoil_roll, 0.0, 1.0 - exp(-16.0 * delta))
	motion_time += delta
	flash_left = maxf(0.0, flash_left - delta)
	var hands = player.hands
	var usable: bool = not player.is_ui_open and not hands._is_carrying and not hands._is_tablet_open
	draw_weight = 1.0 - hands.equipment_lower
	model.visible = hands.visual_equipment == 2 and usable
	muzzle_flash.visible = model.visible and flash_left > 0.0
	if model.visible:
		var lower: float = smoothstep(0.0, 1.0, hands.equipment_lower)
		model.global_basis = player.camera.global_basis * Basis.from_euler(Vector3(recoil * 2.0 - lower * 0.35, sin(motion_time * 1.7) * 0.004, recoil_roll - lower * 0.10))
		model.global_position = hands.right_hand.global_position + player.camera.global_basis * Vector3(0, 0.025, -0.03 + recoil)
		var cycle := 1.0 - clampf(cooldown / maxf(interval, 0.01), 0.0, 1.0)
		slide.position.z = -0.13 + sin(smoothstep(0.0, 0.65, cycle) * PI) * 0.042 if cooldown > 0.0 else -0.13
	badge.visible = usable and not player.is_flashlight_on and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED
	if player.is_minigun_frenzy or player.current_weapon_slot == 4:
		var mode_title = "MİNİGUN (FRENZY)" if player.is_minigun_frenzy else "[4] MİNİGUN"
		badge.text = "%s • SOĞUYOR %.1f sn" % [mode_title, player.minigun_cooldown_left] if player.minigun_overheated else "%s • ISI %.0f%%" % [mode_title, (player.minigun_heat * 100.0)]
	elif player.current_weapon_slot == 3 and player.shotgun_weapon:
		var sg = player.shotgun_weapon
		badge.text = "[3] POMPALI • SV.%d (Sonsuz)" % sg.level
	elif player.current_weapon_slot == 2 and level > 0:
		badge.text = "[2] DART • SV.%d (Sonsuz)" % level
	else:
		badge.text = "[1] İĞNE"
	if equipped() and usable and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED and Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT):
		fire()

func fire() -> bool:
	if player.hands.equipment_busy() or player.is_flashlight_on or not equipped() or cooldown > 0.0 or player.is_ui_open or player.hands._is_carrying or player.hands._is_tablet_open:
		return false
	cooldown = interval
	recoil = minf(recoil + 0.055, 0.085)
	recoil_roll = randf_range(-0.022, 0.022)
	flash_left = 0.035
	last_hit_count = 0
	var space := get_world_3d().direct_space_state
	var origin: Vector3 = player.camera.global_position
	var direction: Vector3 = -player.camera.global_basis.z
	var end := origin + direction * reach
	var excluded: Array[RID] = [player.get_rid()]
	var wall := space.intersect_ray(PhysicsRayQueryParameters3D.create(origin, end, 1, excluded))
	if not wall.is_empty(): end = wall.position
	var first_hit := Vector3.ZERO
	# Inspect the full path repeatedly, excluding each previous balloon.
	for index in range(pierce):
		var hit := space.intersect_ray(PhysicsRayQueryParameters3D.create(origin, end, 3, excluded))
		if hit.is_empty(): break
		var target: Object = hit.collider
		if not target.is_in_group("balloons"): break
		var muzzle_wall := space.intersect_ray(PhysicsRayQueryParameters3D.create(muzzle.global_position, hit.position, 1, excluded))
		if not muzzle_wall.is_empty():
			end = muzzle_wall.position
			break
		excluded.append(hit.rid)
		if target.has_method("can_pop") and not target.can_pop("dart"):
			end = hit.position
			break
		target.pop("dart")
		last_hit_count += 1
		if last_hit_count == 1: first_hit = hit.position
		if index == pierce - 1: end = hit.position
	if last_hit_count > 0 and ricochet_targets > 0:
		pop_nearby_targets(space, first_hit)
	player.pop_triggered.emit(last_hit_count > 0)
	var gm = player.get_node_or_null("../GameManager")
	if gm and gm.has_method("record_dart_shot"): gm.record_dart_shot(last_hit_count)
	var sound = player.get_node_or_null("../SoundManager")
	if sound and sound.has_method("play_dart_shot"): sound.play_dart_shot()
	trail(muzzle.global_position, end)
	return true

func pop_nearby_targets(space: PhysicsDirectSpaceState3D, impact: Vector3) -> void:
	var sphere := SphereShape3D.new()
	sphere.radius = ricochet_radius
	var query := PhysicsShapeQueryParameters3D.new()
	query.shape = sphere
	query.transform = Transform3D(Basis(), impact)
	query.collision_mask = 2
	var candidates := space.intersect_shape(query, 64)
	candidates.sort_custom(func(a, b): return impact.distance_squared_to(a.collider.global_position) < impact.distance_squared_to(b.collider.global_position))
	var extra := 0
	for candidate in candidates:
		if extra >= ricochet_targets: break
		var target: Object = candidate.collider
		if not target.is_in_group("balloons") or target.is_queued_for_deletion() or target.get("is_popped") or not target.can_pop("dart"): continue
		var target_position: Vector3 = target.global_position
		var cover := space.intersect_ray(PhysicsRayQueryParameters3D.create(impact, target_position, 1, [player.get_rid()]))
		if not cover.is_empty(): continue
		target.pop("dart")
		last_hit_count += 1
		extra += 1
		trail(impact, target_position)

func trail(start: Vector3, end: Vector3) -> void:
	if active_trails >= 12 or start.distance_to(end) < 0.01: return
	active_trails += 1
	var dart := MeshInstance3D.new()
	var mesh := BoxMesh.new()
	mesh.size = Vector3(0.018, 0.018, 0.20)
	dart.mesh = mesh
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color("75ffe1")
	mat.emission_enabled = true
	mat.emission = Color("43bb9d")
	dart.material_override = mat
	get_tree().current_scene.add_child(dart) if get_tree().current_scene else player.get_parent().add_child(dart)
	dart.global_position = start
	dart.look_at(end)
	dart.tree_exiting.connect(func(): active_trails = maxi(0, active_trails - 1))
	var tween := dart.create_tween()
	tween.tween_property(dart, "global_position", end, clampf(start.distance_to(end) / 100.0, 0.035, 0.18))
	tween.tween_callback(dart.queue_free)
