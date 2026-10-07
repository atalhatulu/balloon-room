extends Node3D

# Perimeter-only modules leave the central automation area available.
var _shell: StandardMaterial3D
var _dark: StandardMaterial3D
var _metal: StandardMaterial3D
var _accent: StandardMaterial3D
var _screen: StandardMaterial3D
var _warm: StandardMaterial3D

func _mat(color: Color, metal: float = 0.0, glow: float = 0.0) -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	mat.metallic = metal
	mat.roughness = 0.38 if metal > 0.0 else 0.65
	mat.emission_enabled = glow > 0.0
	mat.emission = color
	mat.emission_energy_multiplier = glow
	return mat

func box(parent: Node3D, pos: Vector3, size: Vector3, mat: Material) -> MeshInstance3D:
	var node := MeshInstance3D.new()
	var shape := BoxMesh.new()
	shape.size = size
	node.mesh = shape
	node.material_override = mat
	node.position = pos
	parent.add_child(node)
	return node

func label(parent: Node3D, text: String, pos: Vector3, font_size: int = 48, pixel: float = 0.005) -> Label3D:
	var node := Label3D.new()
	node.text = text
	node.position = pos
	node.font_size = font_size
	node.pixel_size = pixel
	node.modulate = Color(0.78, 0.94, 0.96)
	node.outline_size = 0
	parent.add_child(node)
	return node

func solid(parent: Node3D, pos: Vector3, size: Vector3) -> void:
	var body := StaticBody3D.new()
	body.collision_layer = 1
	body.collision_mask = 3
	body.position = pos
	var collider := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = size
	collider.shape = shape
	body.add_child(collider)
	parent.add_child(body)

func build(size: Vector2, height: float) -> void:
	_shell = _mat(Color(0.65, 0.73, 0.73), 0.2)
	_dark = _mat(Color(0.055, 0.10, 0.14), 0.25)
	_metal = _mat(Color(0.33, 0.43, 0.47), 0.75)
	_accent = _mat(Color(0.06, 0.38, 0.43) if size.x < 42 else Color(0.20, 0.24, 0.46), 0.3)
	_screen = _mat(Color(0.12, 0.70, 0.78), 0.0, 0.55)
	_warm = _mat(Color(0.93, 0.58, 0.17), 0.2)
	var stage := 1 if size.x <= 18 else (2 if size.x <= 26 else (3 if size.x <= 42 else 4))
	var palettes := [Color("b7773d"), Color("257e86"), Color("c49b28"), Color("7159bb")]
	_accent.albedo_color = palettes[stage - 1]
	if stage == 1: _shell.albedo_color = Color("a4957e")
	if stage == 3: _shell.albedo_color = Color("626e76")
	if stage == 4:
		_shell.albedo_color = Color("dce3ee")
		_screen.albedo_color = Color("74dcff")
		_screen.emission = _screen.albedo_color
	var names := ["ATÖLYE", "ÜRETİM TESİSİ", "MEGA HANGAR", "HİPER LABORATUVAR"]
	for side in range(4):
		var wall := Node3D.new()
		wall.name = "FurnishedWall%d" % side
		wall.rotation.y = side * PI / 2.0
		var span := size.x if side % 2 == 0 else size.y
		var depth := size.y if side % 2 == 0 else size.x
		wall.position = wall.basis * Vector3(0, 0, -depth * 0.5 + 0.30)
		add_child(wall)
		# Architectural layers at human scale, no blank floor-to-ceiling plaster.
		if side not in [2, 3]:
			box(wall, Vector3(0, 0.68, 0), Vector3(span - 0.7, 1.1, 0.07), _accent)
			box(wall, Vector3(0, 1.28, 0.03), Vector3(span - 0.7, 0.055, 0.09), _metal)
		else:
			for sign_x in [-1, 1]:
				box(wall, Vector3(sign_x * (span / 4.0 + 0.9), 0.68, 0), Vector3(span / 2.0 - 2.2, 1.1, 0.07), _accent)
		box(wall, Vector3(0, 3.15, 0.02), Vector3(span - 0.7, 0.10, 0.08), _accent)
		var bays := clampi(int(ceil(span / 9.0)), 2, 10)
		for i in range(bays):
			var x := (float(i) + 0.5) * (span - 4.0) / bays - (span - 4.0) * 0.5
			if side in [2, 3] and absf(x) < 6.8: continue
			var module := Node3D.new()
			module.position.x = x
			wall.add_child(module)
			if i % 2 == 0:
				_identity_module(module, stage)
			elif (i + side) % 3 == 0:
				_console(module, (i + side))
			elif (i + side) % 3 == 1:
				_storage(module)
			else:
				_window(module)
			box(wall, Vector3(x - 1.75, height * 0.5, 0.09), Vector3(0.16, height - 0.35, 0.16), _metal)
		# Large wall identity panel remains readable from the centre.
		box(wall, Vector3(0, 4.25, 0.08), Vector3(5.8, 1.30, 0.10), _dark)
		label(wall, "%02d / %s" % [stage, names[stage - 1]], Vector3(0, 4.48, 0.15), 64, 0.005)
		label(wall, ["BALON TEST HATTI", "GAZ / BASINÇ KONTROLÜ", "KARGO / SERVİS", "NUMUNE DEPOSU"][side], Vector3(0, 4.02, 0.15), 36, 0.004)
		# Flush markings define a service lane, without physical obstacles.
		box(wall, Vector3(0, 0.012, 1.35), Vector3(span - 1.0, 0.012, 0.055), _warm)
		for j in range(clampi(int(span / 3.0), 4, 24)):
			box(wall, Vector3(-span * 0.5 + 1.5 + j * (span - 3.0) / maxi(1, clampi(int(span / 3.0), 4, 24) - 1), 0.014, 1.52), Vector3(0.24, 0.014, 0.20), _warm)
	# Roof structure expresses the larger industrial rooms.
	if stage >= 2:
		for i in range(1, 4):
			box(self, Vector3(0, height - 0.45, -size.y * 0.5 + size.y * i / 4.0), Vector3(size.x - 0.6, 0.3, 0.22), _metal)
	if stage == 2:
		# Flush bay outlines and suspended lights make the floor readable at scale.
		for side in [-1, 1]:
			var x: float = side * size.x * 0.24
			for z_side in [-1, 1]:
				var z: float = z_side * size.y * 0.22
				for edge in [-1, 1]:
					box(self, Vector3(x + edge * 5.0, 0.018, z), Vector3(0.07, 0.012, 8.5), _accent)
					box(self, Vector3(x, 0.018, z + edge * 4.25), Vector3(10.0, 0.012, 0.07), _accent)
				var marking := label(self, "HAT %02d" % ((1 if side < 0 else 3) + (1 if z_side > 0 else 0)), Vector3(x, 0.03, z + 3.4), 64, 0.008)
				marking.rotation.x = -PI / 2
			box(self, Vector3(x, height - 0.7, 0), Vector3(0.24, 0.12, size.y * 0.7), _dark)
			box(self, Vector3(x, height - 0.78, 0), Vector3(0.11, 0.04, size.y * 0.7), _screen)
	if stage == 3:
		# Overhead crane stays beside the production floor, clear of pipe outlets.
		var crane := Node3D.new()
		crane.name = "HangarCrane"
		add_child(crane)
		var x := -size.x * 0.38
		box(crane, Vector3(x, height - 1.2, 0), Vector3(0.5, 0.7, size.y - 3), _warm)
		box(crane, Vector3(x, height - 1.8, 0), Vector3(1.5, 0.8, 2.0), _dark)
		box(crane, Vector3(x, height - 3.0, 0), Vector3(0.05, 2, 0.05), _metal)
		box(crane, Vector3(x + 0.18, height - 4.0, 0), Vector3(0.4, 0.12, 0.15), _warm)
	if stage == 4:
		for side in [-1, 1]:
			box(self, Vector3(side * size.x * 0.42, height - 0.6, 0), Vector3(0.12, 0.12, size.y - 2), _screen)

func _identity_module(parent: Node3D, stage: int) -> void:
	parent.name = "RoomIdentity%d" % stage
	match stage:
		1:
			# Timber bench, pegboard, tools and spare parts.
			box(parent, Vector3(0, 1.0, 0.55), Vector3(3, 0.18, 1), _accent)
			for x in [-1.2, 1.2]: box(parent, Vector3(x, 0.48, 0.55), Vector3(0.12, 0.96, 0.7), _metal)
			box(parent, Vector3(0, 1.9, 0.12), Vector3(2.8, 1.3, 0.1), _dark)
			for i in range(7):
				box(parent, Vector3(-1.1 + i * 0.36, 1.85, 0.24), Vector3(0.05, 0.25 + (i % 3) * 0.13, 0.08), _metal)
			box(parent, Vector3(0.8, 1.25, 0.55), Vector3(0.65, 0.32, 0.4), _warm)
			solid(parent, Vector3(0, 0.55, 0.55), Vector3(3, 1.1, 1))
		2:
			# Tall production cabinets with clearly numbered inspection bays.
			for x in [-0.9, 0, 0.9]:
				box(parent, Vector3(x, 1.55, 0.45), Vector3(0.8, 3.1, 0.8), _shell)
				box(parent, Vector3(x, 2.0, 0.87), Vector3(0.6, 1.15, 0.04), _dark)
				box(parent, Vector3(x, 2.0, 0.9), Vector3(0.4, 0.06, 0.03), _screen)
			label(parent, "ÜRETİM / KONTROL", Vector3(0, 3.35, 0.5), 38, 0.003)
			solid(parent, Vector3(0, 1.55, 0.45), Vector3(2.8, 3.1, 0.8))
		3:
			# Stacked cargo racks make the hangar read as a freight hall.
			for x in [-1.5, 1.5]: box(parent, Vector3(x, 2.3, 0.5), Vector3(0.12, 4.6, 0.8), _warm)
			for y in [0.18, 1.65, 3.15]:
				box(parent, Vector3(0, y, 0.6), Vector3(3.2, 0.12, 1.1), _metal)
				for x in [-0.8, 0.8]: box(parent, Vector3(x, y + 0.62, 0.6), Vector3(1.35, 1.1, 0.9), _accent)
			solid(parent, Vector3(0, 2.1, 0.6), Vector3(3.2, 4.2, 1.1))
		4:
			# Sealed specimen bays, luminous rails, clean white plinths.
			box(parent, Vector3(0, 0.3, 0.6), Vector3(3.2, 0.6, 1.1), _shell)
			for x in [-1, 0, 1]:
				box(parent, Vector3(x, 1.9, 0.35), Vector3(0.82, 2.6, 0.5), _dark)
				for edge in [-0.36, 0.36]: box(parent, Vector3(x + edge, 1.9, 0.64), Vector3(0.035, 2.6, 0.04), _screen)
				box(parent, Vector3(x, 1.8, 0.66), Vector3(0.36, 0.55, 0.15), _accent)
			label(parent, "HELIUM / ARAŞTIRMA", Vector3(0, 3.4, 0.5), 38, 0.003)
			solid(parent, Vector3(0, 1.6, 0.6), Vector3(3.2, 3.2, 1.1))

func _console(parent: Node3D, screen_idx: int = 0) -> void:
	box(parent, Vector3(0, 0.52, 0.4), Vector3(2.5, 1.04, 0.75), _shell)
	solid(parent, Vector3(0, 0.58, 0.42), Vector3(2.6, 1.16, 0.85))
	box(parent, Vector3(0, 1.08, 0.43), Vector3(2.7, 0.10, 0.88), _dark)
	for x in [-0.82, 0.0, 0.82]:
		box(parent, Vector3(x, 0.57, 0.79), Vector3(0.72, 0.88, 0.03), _accent)
		box(parent, Vector3(x, 0.83, 0.82), Vector3(0.25, 0.045, 0.035), _metal)
		
	# Primary Computer Monitor
	box(parent, Vector3(-0.40, 1.66, 0.21), Vector3(1.20, 0.80, 0.16), _dark)
	box(parent, Vector3(-0.40, 1.66, 0.30), Vector3(1.10, 0.70, 0.015), _dark)
	
	# Attach Dynamic Telemetry Screen Script to Monitor
	var screen_hub = Node3D.new()
	screen_hub.name = "TelemetryScreen"
	screen_hub.position = Vector3(-0.40, 1.66, 0.32)
	screen_hub.set_script(load("res://src/environment/telemetry_screen.gd"))
	screen_hub.set("screen_mode", screen_idx % 4)
	parent.add_child(screen_hub)
	
	box(parent, Vector3(0.67, 1.18, 0.48), Vector3(0.65, 0.08, 0.40), _metal)
	for i in range(4):
		box(parent, Vector3(0.43 + i * 0.16, 1.23, 0.5), Vector3(0.07, 0.025, 0.12), _warm if i == 3 else _screen)

func _storage(parent: Node3D) -> void:
	box(parent, Vector3(0, 1.15, 0.35), Vector3(2.4, 2.3, 0.65), _dark)
	solid(parent, Vector3(0, 1.15, 0.35), Vector3(2.4, 2.3, 0.65))
	for x in [-0.78, 0.0, 0.78]:
		box(parent, Vector3(x, 0.62, 0.69), Vector3(0.72, 1.12, 0.05), _shell)
		box(parent, Vector3(x + 0.22, 0.73, 0.73), Vector3(0.04, 0.26, 0.045), _metal)
		box(parent, Vector3(x, 1.70, 0.41), Vector3(0.56, 0.70, 0.42), _accent)
		box(parent, Vector3(x, 1.72, 0.64), Vector3(0.36, 0.19, 0.02), _warm)
	box(parent, Vector3(0, 1.27, 0.4), Vector3(2.4, 0.08, 0.72), _metal)
	label(parent, "He   /   NUMUNELER", Vector3(0, 2.12, 0.71), 40, 0.003)

func _window(parent: Node3D) -> void:
	box(parent, Vector3(0, 2.12, 0.09), Vector3(3.0, 1.6, 0.12), _metal)
	box(parent, Vector3(0, 2.12, 0.16), Vector3(2.78, 1.39, 0.025), _dark)
	for x in [-0.88, 0.0, 0.88]:
		box(parent, Vector3(x, 2.0, 0.20), Vector3(0.56, 0.86, 0.035), _accent)
		box(parent, Vector3(x, 2.1, 0.23), Vector3(0.38, 0.07, 0.02), _screen)
		box(parent, Vector3(x, 1.9, 0.23), Vector3(0.38, 0.025, 0.02), _screen)
	box(parent, Vector3(0, 2.66, 0.20), Vector3(2.65, 0.035, 0.045), _screen)
	box(parent, Vector3(0, 2.12, 0.25), Vector3(0.06, 1.40, 0.04), _metal)
	label(parent, "BASINÇ HÜCRELERİ", Vector3(0, 1.1, 0.12), 40, 0.004)
