extends RefCounted

static func material(color: Color, metal := 0.6, glow := false) -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	mat.metallic = metal
	mat.roughness = 0.36
	if glow:
		mat.emission_enabled = true
		mat.emission = color
		mat.emission_energy_multiplier = 2.0
	return mat

static func part(parent: Node3D, mesh: Mesh, pos: Vector3, mat: Material, label: String) -> MeshInstance3D:
	var node := MeshInstance3D.new()
	node.name = label
	node.mesh = mesh
	node.position = pos
	node.material_override = mat
	node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(node)
	return node

static func box(parent: Node3D, size: Vector3, pos: Vector3, mat: Material, label: String) -> MeshInstance3D:
	return part(parent, beveled_mesh(size), pos, mat, label)

static func tube(parent: Node3D, radius: float, length: float, pos: Vector3, mat: Material, label: String) -> MeshInstance3D:
	var mesh := CylinderMesh.new()
	mesh.top_radius = radius
	mesh.bottom_radius = radius
	mesh.height = length
	mesh.radial_segments = 16
	var node := part(parent, mesh, pos, mat, label)
	node.rotation.x = PI / 2.0
	return node

static func flash(parent: Node3D, color: Color, radius: float, length: float) -> MeshInstance3D:
	var mesh := SphereMesh.new()
	mesh.radius = radius
	mesh.height = radius * 2.0
	mesh.radial_segments = 8
	mesh.rings = 4
	var mat := material(color, 0.0, true)
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	var node := part(parent, mesh, Vector3(0, 0, -length * 0.5), mat, "MuzzleFlash")
	node.scale = Vector3(1, 1, length / (radius * 2.0))
	node.hide()
	return node

# Small machined chamfers catch room light without extra meshes or lights.
static func beveled_mesh(size: Vector3) -> ArrayMesh:
	var half := size * 0.5
	var bevel := minf(minf(size.x, size.y), size.z) * 0.14
	var outline: Array[Vector2] = [Vector2(-half.x + bevel, -half.y), Vector2(half.x - bevel, -half.y), Vector2(half.x, -half.y + bevel), Vector2(half.x, half.y - bevel), Vector2(half.x - bevel, half.y), Vector2(-half.x + bevel, half.y), Vector2(-half.x, half.y - bevel), Vector2(-half.x, -half.y + bevel)]
	var rings: Array[PackedVector3Array] = []
	for layer in range(4):
		var ring := PackedVector3Array()
		var z: float = [-half.z, -half.z + bevel, half.z - bevel, half.z][layer]
		var inset: float = bevel * 0.5 if layer in [0, 3] else 0.0
		for point in outline:
			ring.append(Vector3(point.x * (1.0 - inset / half.x), point.y * (1.0 - inset / half.y), z))
		rings.append(ring)
	var surface := SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	for layer in range(3):
		for i in range(8):
			var next := (i + 1) % 8
			for vertex in [rings[layer][i], rings[layer + 1][next], rings[layer][next], rings[layer][i], rings[layer + 1][i], rings[layer + 1][next]]:
				surface.add_vertex(vertex)
	for i in range(1, 7):
		for vertex in [rings[0][0], rings[0][i], rings[0][i + 1], rings[3][0], rings[3][i + 1], rings[3][i]]:
			surface.add_vertex(vertex)
	surface.generate_normals()
	return surface.commit()
