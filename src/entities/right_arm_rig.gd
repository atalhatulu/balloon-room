extends Node3D

# Shoulder anchor follows the body; elbow bends toward the outside of the torso.
# The forearm extends for the existing long-reach needle interaction.
var hand: Node3D
var side := 1.0
var hands: Node3D
var player: CharacterBody3D
var upper: MeshInstance3D
var forearm: MeshInstance3D
var joint: MeshInstance3D
var cuff: MeshInstance3D
var shoulder_world := Vector3.ZERO
var elbow_world := Vector3.ZERO
var wrist_world := Vector3.ZERO

func material(color: Color, metal := 0.0) -> StandardMaterial3D:
	var result := StandardMaterial3D.new()
	result.albedo_color = color
	result.metallic = metal
	result.roughness = 0.48
	return result

func segment(top: float, bottom: float, mat: Material) -> MeshInstance3D:
	var node := MeshInstance3D.new()
	var mesh := CylinderMesh.new()
	mesh.top_radius = top
	mesh.bottom_radius = bottom
	mesh.height = 1
	mesh.radial_segments = 12
	mesh.rings = 1
	node.mesh = mesh
	node.material_override = mat
	node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(node)
	return node

func setup(owner_hands: Node3D, owner_player: CharacterBody3D, left := false) -> void:
	hands = owner_hands
	hand = hands.left_hand if left else hands.right_hand
	side = -1.0 if left else 1.0
	player = owner_player
	process_priority = 30
	upper = segment(0.066, 0.095, material(Color("243b46")))
	forearm = segment(0.033, 0.056, material(Color("798b91"), 0.6))
	cuff = segment(0.038, 0.04, material(Color("cf8e33"), 0.35))
	joint = MeshInstance3D.new()
	var sphere := SphereMesh.new()
	sphere.radius = 0.065
	sphere.height = 0.13
	sphere.radial_segments = 12
	sphere.rings = 6
	joint.mesh = sphere
	joint.material_override = material(Color("1a272e"), 0.3)
	joint.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(joint)

func align(node: MeshInstance3D, start: Vector3, end: Vector3) -> void:
	var delta := end - start
	node.global_transform = Transform3D(Basis(Quaternion(Vector3.UP, delta.normalized())).scaled_local(Vector3(1, maxf(0.001, delta.length()), 1)), (start + end) * 0.5)

func _process(_delta: float) -> void:
	if not is_instance_valid(player) or not is_instance_valid(hands): return
	if hands.visual_equipment == 3:
		visible = false
		return
	visible = hand.is_visible_in_tree()
	if not visible: return
	shoulder_world = player.global_position + player.global_basis * Vector3(0.24 * side, 1.29, 0.05)
	wrist_world = hand.to_global(Vector3(0, 0, 0.05))
	var direction := wrist_world - shoulder_world
	var distance := maxf(direction.length(), 0.01)
	direction /= distance
	var upper_length := 0.31
	var lower_length := maxf(0.29, distance - upper_length + 0.035)
	var along := clampf((upper_length * upper_length - lower_length * lower_length + distance * distance) / (2 * distance), -upper_length, upper_length)
	var bend := player.global_basis * Vector3(0.7 * side, -1, 0.25)
	bend = (bend - direction * bend.dot(direction)).normalized()
	if bend.is_zero_approx(): bend = player.global_basis.x
	elbow_world = shoulder_world + direction * along + bend * sqrt(maxf(0, upper_length * upper_length - along * along))
	align(upper, elbow_world, shoulder_world)
	align(forearm, elbow_world, wrist_world)
	joint.global_position = elbow_world
	var wrist_dir := (wrist_world - elbow_world).normalized()
	align(cuff, wrist_world - wrist_dir * 0.045, wrist_world)
