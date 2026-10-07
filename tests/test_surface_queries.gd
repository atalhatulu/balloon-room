extends SceneTree
const Design = preload("res://src/entities/collectible_design.gd")
var failures := 0
func old_hit(origin: Vector3, direction: Vector3) -> Variant:
	var closest: Variant = null
	var distance := INF
	var faces := Design.balloon_faces
	for i in range(0, faces.size(), 3):
		var point = Geometry3D.ray_intersects_triangle(origin, direction, faces[i], faces[i + 1], faces[i + 2])
		if point != null and origin.distance_squared_to(point) < distance:
			distance = origin.distance_squared_to(point)
			closest = point
	return closest
func _init() -> void:
	Design.get_balloon_body()
	var origins: Array[Vector3] = []
	var directions: Array[Vector3] = []
	seed(4711)
	for i in range(200):
		var origin := Vector3(randf_range(-2, 2), randf_range(-2, 2), 3)
		origins.append(origin)
		directions.append((Vector3(randf_range(-0.6, 0.6), randf_range(-0.6, 0.6), 0) - origin).normalized())
	var start := Time.get_ticks_usec()
	var reference: Array = []
	for i in range(origins.size()): reference.append(old_hit(origins[i], directions[i]))
	var old_us := Time.get_ticks_usec() - start
	start = Time.get_ticks_usec()
	var hits: Array = []
	for i in range(origins.size()): hits.append(Design.balloon_surface.intersect_ray(origins[i], directions[i]))
	var native_us := Time.get_ticks_usec() - start
	for i in range(origins.size()):
		if reference[i] == null:
			if not hits[i].is_empty(): failures += 1
		elif hits[i].is_empty() or reference[i].distance_to(hits[i].position) > 0.0001:
			failures += 1
	print("SURFACE: 200 reference rays, ", failures, " mismatches; script=", old_us, " us; native=", native_us, " us")
	quit(1 if failures else 0)
