extends Node3D

# Eight inexpensive indicator segments, owned by each device. No new lights.
var segments: Array[StandardMaterial3D] = []
var accent := Color.WHITE
var contact_label := "balon çekildi"
var flash: float = 0.0
var flow_ring: MeshInstance3D
var flow_material: StandardMaterial3D
var phase: float = 0.0
var focused := false
var display_charge := 0.0
var working_now := false
var visual_elapsed := 0.0
var moving_parts: Array[MeshInstance3D] = []
var machine_phase := 0.0
var discharge_ring: MeshInstance3D
var discharge_material: StandardMaterial3D

func configure(color: Color, width: float, front: float, magnetic: bool = false) -> void:
	accent = color
	var finish = preload("res://src/entities/weapon_finish.gd")
	var housing := finish.material(Color("182b35"), 0.65)
	finish.box(self, Vector3(width * 1.04, 0.12, 0.16), Vector3(0, 0.105, front), housing, "IndicatorHousing")
	for side in [-1, 1]:
		finish.box(self, Vector3(0.09, 0.14, 0.19), Vector3(side * width * 0.53, 0.12, front), finish.material(Color("8499a4")), "EndCap%d" % side)
	for i in range(8):
		var led := MeshInstance3D.new()
		var mesh := BoxMesh.new()
		mesh.size = Vector3(width / 10.0, 0.035, 0.065)
		led.mesh = mesh
		led.position = Vector3((i - 3.5) * width / 8.0, 0.17, front)
		var mat := StandardMaterial3D.new()
		mat.albedo_color = accent * 0.15
		mat.emission_enabled = true
		mat.emission = accent
		mat.emission_energy_multiplier = 0.12
		led.material_override = mat
		led.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		segments.append(mat)
		add_child(led)
	for side in [-1, 1]:
		var part := MeshInstance3D.new()
		var cylinder := CylinderMesh.new()
		cylinder.top_radius = 0.07
		cylinder.bottom_radius = 0.10
		cylinder.height = 0.32
		cylinder.radial_segments = 10
		part.mesh = cylinder
		part.material_override = segments[0]
		part.position = Vector3(side * width * 0.38, 0.32, -front)
		part.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(part)
		moving_parts.append(part)
	if not magnetic:
		discharge_ring = MeshInstance3D.new()
		var ring_mesh := TorusMesh.new()
		ring_mesh.inner_radius = 0.9
		ring_mesh.outer_radius = 1.0
		ring_mesh.rings = 24
		ring_mesh.ring_segments = 4
		discharge_ring.mesh = ring_mesh
		discharge_ring.position.y = 0.25
		discharge_ring.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		discharge_material = StandardMaterial3D.new()
		discharge_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		discharge_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		discharge_material.albedo_color = Color(accent, 0)
		discharge_ring.material_override = discharge_material
		add_child(discharge_ring)
	if magnetic:
		flow_ring = MeshInstance3D.new()
		var ring := TorusMesh.new()
		ring.inner_radius = 0.94
		ring.outer_radius = 1.0
		ring.rings = 32
		ring.ring_segments = 6
		flow_ring.mesh = ring
		flow_ring.position.y = 0.24
		flow_ring.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		flow_material = StandardMaterial3D.new()
		flow_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		flow_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		flow_material.albedo_color = Color(accent, 0.45)
		flow_ring.material_override = flow_material
		add_child(flow_ring)

func pulse() -> void:
	flash = 1.0

func update_state(delta: float, charge: float, working: bool = false) -> void:
	display_charge = clampf(charge, 0.0, 1.0)
	working_now = working
	flash = maxf(0.0, flash - delta * 4.5)
	visual_elapsed += delta
	if visual_elapsed < 1.0 / 30.0: return
	var visual_delta := visual_elapsed
	visual_elapsed = 0.0
	if discharge_ring:
		discharge_ring.visible = flash > 0.01
		discharge_ring.scale = Vector3.ONE * lerpf(1.7, 0.25, flash)
		discharge_material.albedo_color.a = flash * 0.65
	machine_phase += visual_delta * (5.0 if working else 1.0)
	for part in moving_parts:
		part.position.y = 0.32 + flash * 0.14
		part.scale.y = 0.65 + charge * 0.35 + flash * 0.5
		part.rotation.y = machine_phase
	for i in range(segments.size()):
		var lit := charge >= float(i + 1) / 8.0
		segments[i].albedo_color = accent.lerp(Color.WHITE, flash * 0.7) * (0.8 if lit else 0.12)
		segments[i].emission_energy_multiplier = (1.5 if lit else 0.08) + flash * 2.5
	if flow_ring:
		phase = fmod(phase + visual_delta * (1.6 if working else 0.45), 1.0)
		var radius := lerpf(1.6, 0.42, phase)
		flow_ring.scale = Vector3(radius, 1.0, radius)
		flow_material.albedo_color.a = sin(phase * PI) * (0.55 if working else 0.12)

var output_buckets: Array[int] = [0, 0, 0, 0, 0, 0, 0, 0, 0, 0]
var bucket_second: int = -1
var recent_contacts: Dictionary = {}
var stats_label: Label3D
var stats_timer := 0.0

func advance_window(second_override: int = -1) -> void:
	var second := int(Time.get_ticks_msec() / 1000) if second_override < 0 else second_override
	if bucket_second < 0: bucket_second = second
	if second - bucket_second >= 10: output_buckets.fill(0)
	else:
		for tick in range(bucket_second + 1, second + 1): output_buckets[tick % 10] = 0
	bucket_second = second

func record_output(count: int = 1) -> void:
	advance_window()
	output_buckets[bucket_second % 10] += count

func record_contact(body: Node) -> void:
	recent_contacts[body.get_instance_id()] = Time.get_ticks_msec()

func last_output() -> int:
	advance_window()
	var total := 0
	for value in output_buckets: total += value
	return total

func _process(delta: float) -> void:
	var facility = get_node_or_null("/root/Main")
	var powered: bool = not (facility and facility.is_blackout) and bool(get_parent().get("is_active"))
	if not powered:
		for mat in segments: mat.emission_energy_multiplier = 0.0
		if flow_ring: flow_ring.hide()
		if discharge_ring: discharge_ring.hide()
		if stats_label:
			stats_label.text = "BEKLEMEDE"
			stats_label.visible = focused
		return
	if flow_ring: flow_ring.show()
	stats_timer += delta
	if stats_timer < 0.25: return
	stats_timer = 0.0
	var now := Time.get_ticks_msec()
	for id in recent_contacts.keys():
		if now - int(recent_contacts[id]) >= 10000: recent_contacts.erase(id)
	if not stats_label:
		stats_label = Label3D.new()
		stats_label.font_size = 32
		stats_label.pixel_size = 0.003
		stats_label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		stats_label.no_depth_test = false
		get_parent().add_child(stats_label)
		stats_label.position.y = 1.15
	var camera := get_viewport().get_camera_3d()
	stats_label.visible = focused and camera != null and camera.global_position.distance_squared_to(global_position) < 144.0 and get_parent().process_mode != Node.PROCESS_MODE_DISABLED
	var level: int = get_parent().get("level")
	stats_label.text = "SV. %d • %s\n" % [level, ("ÇALIŞIYOR" if working_now or flash > 0.1 else ("HAZIR" if display_charge >= 0.95 else "DOLUM %%%d" % int(display_charge * 100.0)))] + ("%d %s" % [recent_contacts.size(), contact_label] if flow_ring else "%d patlatma" % last_output())
