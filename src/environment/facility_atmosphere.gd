extends Node3D

# Wall-mounted machinery: visual only, never claims gameplay output.
var rotors: Array[Node3D] = []
var indicators: Array[MeshInstance3D] = []
var activity := 0.0
var phase := 0.0
var glow: StandardMaterial3D
var status: Label3D
var main: Node
var update_timer := 0.0

func setup(owner_main: Node, room_size: Vector2, height: float) -> void:
	main = owner_main
	var shell := material(Color("18303b"), 0.65)
	var metal := material(Color("7797a0"), 0.75)
	glow = material(Color("55dbca"), 0.1)
	glow.emission_enabled = true
	glow.emission = Color("31b5a7")
	glow.emission_energy_multiplier = 0.6
	for side in [-1, 1]:
		var module := Node3D.new()
		module.position = Vector3(side * (room_size.x * 0.5 - 0.43), height * 0.55, 0)
		module.rotation.y = -side * PI / 2
		add_child(module)
		for offset in [-2.2, 2.2]:
			box(module, Vector3(offset, 0, 0), Vector3(2.2, 2.2, 0.14), shell)
			var rotor := Node3D.new()
			rotor.position = Vector3(offset, 0, 0.20)
			module.add_child(rotor)
			rotors.append(rotor)
			for blade in range(6):
				var arm := Node3D.new()
				arm.rotation.z = blade * TAU / 6
				rotor.add_child(arm)
				box(arm, Vector3(0, 0.48, 0), Vector3(0.21, 0.74, 0.035), metal)
			box(module, Vector3(offset, 0, 0.28), Vector3(0.28, 0.28, 0.07), shell)
			for y in [-0.85, -0.42, 0.0, 0.42, 0.85]:
				box(module, Vector3(offset, y, 0.33), Vector3(2.02, 0.045, 0.035), shell)
		for i in range(8):
			indicators.append(box(module, Vector3(-3.5 + i, -1.38, 0.1), Vector3(0.60, 0.06, 0.035), glow))
	status = Label3D.new()
	status.position = Vector3(0, height - 2.1, -room_size.y * 0.5 + 0.55)
	status.font_size = 56
	status.pixel_size = 0.006
	status.modulate = Color("81e5d7")
	status.outline_size = 4
	add_child(status)

func material(color: Color, metallic: float) -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	mat.metallic = metallic
	mat.roughness = 0.5
	return mat

func box(parent: Node3D, pos: Vector3, size: Vector3, mat: Material) -> MeshInstance3D:
	var node := MeshInstance3D.new()
	var mesh := BoxMesh.new()
	mesh.size = size
	node.mesh = mesh
	node.material_override = mat
	node.position = pos
	node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(node)
	return node

func _process(delta: float) -> void:
	if not is_instance_valid(main) or not main.game_manager: return
	var running: bool = main.game_manager.production_enabled and not main.is_blackout
	activity = move_toward(activity, 1.0 if running else 0.0, delta * 0.65)
	phase += delta * activity
	for i in range(rotors.size()):
		rotors[i].rotation.z += delta * activity * (1.2 if i % 2 == 0 else -1.2)
	update_timer += delta
	if update_timer < 0.1: return
	update_timer = 0.0
	glow.emission_energy_multiplier = 0.15 + activity * (0.5 + sin(phase * 2.0) * 0.12)
	var transferring: bool = main.shop_manager.pending_room != ""
	glow.albedo_color = Color("ff983d") if transferring else Color("55dbca")
	glow.emission = Color("ff7a20") if transferring else Color("31b5a7")
	if transferring: glow.emission_energy_multiplier = 0.8
	for i in range(indicators.size()):
		indicators[i].visible = not running or (i % 8 <= int(phase * 3.0) % 8)
	status.text = "02 / ÜRETİM HATTI  •  %s\n%.1f BALON / SN" % ["AKTİF" if running else "BEKLEMEDE", main.game_manager.get_current_spawn_rate() if running else 0.0]

	if transferring: status.text = "GEÇİŞ HAZIRLIĞI • ÜRETİM DURDU"
