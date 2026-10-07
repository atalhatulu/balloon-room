extends RefCounted

static var balloon_body: ArrayMesh
static var balloon_faces := PackedVector3Array()
static var balloon_surface: TriangleMesh
static var coin_mesh: ArrayMesh
static var special_meshes: Dictionary = {}

static func get_balloon_body() -> ArrayMesh:
	if balloon_body:
		return balloon_body
	var sphere := SphereMesh.new()
	sphere.radius = 0.42
	sphere.height = 0.94
	sphere.radial_segments = 28
	sphere.rings = 14
	var arrays := sphere.get_mesh_arrays()
	var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	for i in range(vertices.size()):
		var v := vertices[i]
		# Full shoulder, tapered neck: unmistakably inflated latex, not a ball.
		var taper := lerpf(0.78, 1.0, smoothstep(-0.47, 0.06, v.y))
		v.x *= taper
		v.z *= taper
		vertices[i] = v
	arrays[Mesh.ARRAY_VERTEX] = vertices
	var source := ArrayMesh.new()
	source.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	var builder := SurfaceTool.new()
	builder.create_from(source, 0)
	builder.generate_normals()
	balloon_body = builder.commit()
	balloon_faces = balloon_body.get_faces()
	balloon_surface = TriangleMesh.new()
	balloon_surface.create_from_faces(balloon_faces)
	balloon_body = with_lods(balloon_body)
	return balloon_body

static func get_coin_mesh() -> ArrayMesh:
	if coin_mesh:
		return coin_mesh
	var builder := SurfaceTool.new()
	builder.begin(Mesh.PRIMITIVE_TRIANGLES)
	var disc := CylinderMesh.new()
	disc.top_radius = 0.166
	disc.bottom_radius = 0.166
	disc.height = 0.042
	disc.radial_segments = 32
	disc.rings = 1
	builder.append_from(disc, 0, Transform3D.IDENTITY)
	var rim := TorusMesh.new()
	rim.inner_radius = 0.151
	rim.outer_radius = 0.18
	rim.rings = 32
	rim.ring_segments = 6
	for side in [-1.0, 1.0]:
		builder.append_from(rim, 0, Transform3D(Basis(), Vector3(0, side * 0.014, 0)))
		# Raised balloon insignia on both faces, reads through lighting, no labels.
		var emblem := SphereMesh.new()
		emblem.radius = 0.068
		emblem.height = 0.136
		emblem.radial_segments = 16
		emblem.rings = 6
		builder.append_from(emblem, 0, Transform3D(Basis().scaled(Vector3(0.82, 0.10, 1.0)), Vector3(0, side * 0.023, -0.02)))
		var stem := BoxMesh.new()
		stem.size = Vector3(0.017, 0.012, 0.07)
		builder.append_from(stem, 0, Transform3D(Basis(), Vector3(0, side * 0.024, 0.066)))
	# Reeded edge: merged, cached geometry for every coin.
	var notch := BoxMesh.new()
	notch.size = Vector3(0.012, 0.033, 0.014)
	for i in range(24):
		var a := i * TAU / 24.0
		builder.append_from(notch, 0, Transform3D(Basis(Vector3.UP, a), Vector3(sin(a) * 0.173, 0, cos(a) * 0.173)))
	coin_mesh = with_lods(builder.commit())
	return coin_mesh

static func get_special_mesh(kind: String) -> ArrayMesh:
	if special_meshes.has(kind):
		return special_meshes[kind]
	var builder := SurfaceTool.new()
	builder.begin(Mesh.PRIMITIVE_TRIANGLES)
	if kind == "bomb":
		var fuse := CylinderMesh.new()
		fuse.top_radius = 0.018
		fuse.bottom_radius = 0.024
		fuse.height = 0.18
		fuse.radial_segments = 6
		fuse.rings = 1
		builder.append_from(fuse, 0, Transform3D(Basis(Vector3.FORWARD, -0.35), Vector3(0.025, 0.51, 0)))
		var spark := SphereMesh.new()
		spark.radius = 0.032
		spark.height = 0.064
		spark.radial_segments = 8
		spark.rings = 4
		builder.append_from(spark, 0, Transform3D(Basis(), Vector3(0.057, 0.61, 0)))
	else:
		var ring := TorusMesh.new()
		ring.inner_radius = 0.425
		ring.outer_radius = 0.438
		ring.rings = 28
		ring.ring_segments = 5
		builder.append_from(ring, 0, Transform3D(Basis(Vector3.FORWARD, 0.22), Vector3(0, 0.08, 0)))
		if kind == "air":
			builder.append_from(ring, 0, Transform3D(Basis(Vector3.RIGHT, 0.50).scaled(Vector3.ONE * 0.87), Vector3(0, 0.25, 0)))
	var result := builder.commit()
	special_meshes[kind] = result
	return result

# Shared native LODs keep nearby relief and reduce distant geometry automatically.
static func with_lods(mesh: ArrayMesh) -> ArrayMesh:
	var importer := ImporterMesh.new()
	for surface in range(mesh.get_surface_count()):
		importer.add_surface(Mesh.PRIMITIVE_TRIANGLES, mesh.surface_get_arrays(surface))
	importer.generate_lods(60.0, 25.0, [])
	return importer.get_mesh()
