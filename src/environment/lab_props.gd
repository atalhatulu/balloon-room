class_name LabProps
extends Node3D

# Modular ceiling/wall decoration. Keep the playable floor clear and fixture
# thickness constant across room upgrades (never scale the whole hierarchy).
var fixture_material: StandardMaterial3D
var work_lights: Array[SpotLight3D] = []

func _process(_delta: float) -> void:
	var main = get_node_or_null("/root/Main")
	if fixture_material and main:
		fixture_material.emission_energy_multiplier = 0.0
		for light in work_lights:
			light.visible = not main.is_blackout

var room_size := Vector2.ZERO
var ceiling_height: float = 0.0

func _ready() -> void:
	configure_room(Vector2(18, 18), 6.5)

func _material(color: Color, roughness: float, metallic: float = 0.0, glow: float = 0.0) -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	mat.roughness = roughness
	mat.metallic = metallic
	if glow > 0.0:
		mat.emission_enabled = true
		mat.emission = color
		mat.emission_energy_multiplier = glow
	return mat

func _box(parent: Node3D, dimensions: Vector3, pos: Vector3, mat: Material) -> MeshInstance3D:
	var instance := MeshInstance3D.new()
	var mesh := BoxMesh.new()
	mesh.size = dimensions
	instance.mesh = mesh
	instance.material_override = mat
	instance.position = pos
	parent.add_child(instance)
	return instance

func configure_room(size: Vector2, height: float) -> void:
	if room_size == size and is_equal_approx(ceiling_height, height):
		return
	work_lights.clear()
	room_size = size
	ceiling_height = height
	for child in get_children():
		remove_child(child)
		child.queue_free()
	var fixtures := Node3D.new()
	fixtures.name = "FluorescentFixtures"
	add_child(fixtures)
	var ducts := Node3D.new()
	ducts.name = "HVAC_Ductwork"
	add_child(ducts)
	var housing := _material(Color(0.76, 0.80, 0.82), 0.42, 0.35)
	var diffuser := _material(Color(0.88, 0.95, 1.0), 0.3, 0.0, 1.6)
	fixture_material = diffuser
	var steel := _material(Color(0.55, 0.62, 0.66), 0.34, 0.78)
	var dark := _material(Color(0.13, 0.18, 0.22), 0.5, 0.5)
	var orange := _material(Color(0.91, 0.38, 0.10), 0.48)
	var furnishings = preload("res://src/environment/room_furnishings.gd").new()
	furnishings.name = "RoomFurnishings"
	add_child(furnishings)
	furnishings.build(size, height)
	# Bounded grid: at most 36 fixtures, without adding per-fixture lights.
	var nx := clampi(int(ceil(size.x / 16.0)), 2, 6)
	var nz := clampi(int(ceil(size.y / 16.0)), 2, 6)
	for x in range(nx):
		for z in range(nz):
			var pos := Vector3((float(x) + 0.5) * size.x / nx - size.x * 0.5, height - 0.16, (float(z) + 0.5) * size.y / nz - size.y * 0.5)
			_box(fixtures, Vector3(2.5, 0.12, 0.42), pos, housing)
			_box(fixtures, Vector3(2.28, 0.035, 0.28), pos + Vector3(0, -0.08, 0), diffuser)
	# Build each wall in local coordinates; the long runs follow actual bounds.
	for side in range(4):
		var wall := Node3D.new()
		wall.name = "WallRun%d" % side
		ducts.add_child(wall)
		wall.rotation.y = side * PI / 2.0
		var span := size.x if side % 2 == 0 else size.y
		var depth := size.y if side % 2 == 0 else size.x
		wall.position = wall.basis * Vector3(0, 0, -depth * 0.5 + 0.64)
		var y := height - 0.85
		_box(wall, Vector3(span - 1.0, 0.48, 0.58), Vector3(0, y, 0), steel)
		var sections := maxi(2, int(ceil(span / 6.0)))
		for i in range(sections):
			var x := (float(i) + 0.5) * (span - 1.6) / sections - (span - 1.6) * 0.5
			_box(wall, Vector3(0.07, 0.62, 0.67), Vector3(x, y, 0), dark)
			_box(wall, Vector3(0.8, 0.22, 0.025), Vector3(x + 0.65, y, 0.30), dark)
			for slat in range(4):
				_box(wall, Vector3(0.76, 0.018, 0.035), Vector3(x + 0.65, y - 0.075 + slat * 0.05, 0.32), steel)
		_box(wall, Vector3(0.18, 0.51, 0.61), Vector3(-span * 0.28, y, 0), orange)
		# A wall-mounted riser ties the high ducts back to human scale.
		var riser_height := height - 2.75
		_box(wall, Vector3(0.38, riser_height, 0.38), Vector3(-span * 0.5 + 1.1, 1.9 + riser_height * 0.5, 0), steel)
		_box(wall, Vector3(0.42, 0.22, 0.42), Vector3(-span * 0.5 + 1.1, 2.2, 0), orange)
		_box(wall, Vector3(0.50, 0.40, 0.44), Vector3(-span * 0.5 + 1.1, 1.95, 0), dark)

	_batch_boxes(furnishings)
	_batch_boxes(ducts)

func _batch_boxes(root_node: Node3D) -> void:
	# One draw per material instead of one draw per cabinet panel / duct slat.
	# Keep original collision bodies and labels untouched.
	var groups := {}
	var meshes: Array[Node] = root_node.find_children("*", "MeshInstance3D", true, false)
	for node in meshes:
		if not node.mesh is BoxMesh or not node.material_override: continue
		var material: Material = node.material_override
		var key := material.get_instance_id()
		if not groups.has(key): groups[key] = {"material": material, "transforms": []}
		var transform: Transform3D = root_node.global_transform.affine_inverse() * node.global_transform
		transform.basis = transform.basis.scaled_local(node.mesh.size)
		groups[key].transforms.append(transform)
		node.get_parent().remove_child(node)
		node.queue_free()
	for group in groups.values():
		var instance := MultiMeshInstance3D.new()
		var multimesh := MultiMesh.new()
		multimesh.transform_format = MultiMesh.TRANSFORM_3D
		var cube := BoxMesh.new()
		cube.size = Vector3.ONE
		multimesh.mesh = cube
		multimesh.instance_count = group.transforms.size()
		for i in range(group.transforms.size()): multimesh.set_instance_transform(i, group.transforms[i])
		instance.multimesh = multimesh
		instance.material_override = group.material
		root_node.add_child(instance)
