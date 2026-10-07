extends Node3D

var main: Node
var lamps: Array[SpotLight3D] = []
var lenses: Array[StandardMaterial3D] = []
var phase := 0.0
var status_elapsed := 0.0

func setup(owner_node: Node, size: Vector2, height: float, _stage: int) -> void:
	main = owner_node
	# The cargo door faces north; the maintenance entrance faces west.
	for x in [-4.6, 4.6]:
		_add_monitor(Vector3(x, 2.15, size.y / 2.0 - 0.55), PI)
	_add_monitor(Vector3(size.x / 2.0 - 0.55, 2.25, 4.4), -PI / 2.0)

func _add_monitor(pos: Vector3, yaw: float) -> void:
	var root := Node3D.new()
	root.position = pos
	root.rotation.y = yaw
	add_child(root)
	var frame := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = Vector3(3.5, 1.85, 0.16)
	frame.mesh = box
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color("07121c")
	mat.roughness = 0.6
	mat.emission_enabled = true
	mat.emission = Color("07121c")
	mat.emission_energy_multiplier = 0.35
	frame.material_override = mat
	root.add_child(frame)
	var screen := preload("res://src/environment/telemetry_screen.gd").new()
	screen.screen_mode = 4
	screen.position.z = 0.09
	screen.scale = Vector3.ONE * 2.7
	root.add_child(screen)

