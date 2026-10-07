extends Node3D

signal presented
signal stowed

const SCREEN_SIZE := Vector2(1.52, 0.82)
var requested_open := false
var transitioning := false
var _hands: Node3D
var _camera: Camera3D
var _tween: Tween
var _rest_fov := 75.0
var _screen: MeshInstance3D

func setup(hands: Node3D, camera: Camera3D) -> void:
	_hands = hands
	_camera = camera
	_rest_fov = camera.fov
	name = "FacilityTablet"
	visible = false
	position = Vector3(0.0, -0.85, -0.48)
	_make_box("Chassis", Vector3(1.64, 0.94, 0.045), Vector3.ZERO, Color(0.035, 0.055, 0.072), 0.55)
	_make_box("Bezel", Vector3(1.59, 0.89, 0.018), Vector3(0, 0, 0.028), Color(0.08, 0.12, 0.15), 0.65)
	_screen = _make_box("Screen", Vector3(SCREEN_SIZE.x, SCREEN_SIZE.y, 0.008), Vector3(0, 0, 0.042), Color(0.035, 0.062, 0.09), 0.0)
	_screen.material_override.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_make_box("Camera", Vector3(0.025, 0.009, 0.009), Vector3(0, 0.437, 0.042), Color(0.1, 0.3, 0.35), 0.4)
	_make_box("PowerLED", Vector3(0.04, 0.008, 0.009), Vector3(0.62, -0.437, 0.042), Color(0.2, 0.9, 0.7), 0.0)
	for side in [-1.0, 1.0]:
		_make_box("Grip", Vector3(0.045, 0.55, 0.06), Vector3(side * 0.815, 0, 0), Color(0.10, 0.14, 0.17), 0.15)

func _make_box(node_name: String, dimensions: Vector3, pos: Vector3, color: Color, metal: float) -> MeshInstance3D:
	var node := MeshInstance3D.new()
	node.name = node_name
	var mesh_box := BoxMesh.new()
	mesh_box.size = dimensions
	node.mesh = mesh_box
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	mat.metallic = metal
	mat.roughness = 0.35
	node.material_override = mat
	node.position = pos
	node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(node)
	return node

func _view_distance() -> float:
	var viewport_size := get_viewport().get_visible_rect().size
	var aspect := viewport_size.x / maxf(viewport_size.y, 1.0)
	var half_angle := tan(deg_to_rad(_rest_fov - 7.0) * 0.5)
	return maxf(0.47 / (half_angle * 0.88), 0.82 / (half_angle * aspect * 0.88)) + 0.046

func set_open(open: bool) -> void:
	if open == requested_open and not transitioning:
		return
	requested_open = open
	transitioning = true
	if _tween:
		_tween.kill()
	_tween = create_tween()
	if open:
		visible = true
		_hands._is_tablet_open = true
		_hands.cancel_actions()
		_hands.get_node("RightHand").hide()
		_hands.get_node("LeftHand").show()
		if _hands.flashlight_prop: _hands.flashlight_prop.hide()
		_hands.get_node("RightHand/Tool").hide()
		if _hands.tablet_device:
			_hands.tablet_device.hide()
		_tween.set_parallel(true)
		# Retrieve below the camera, then square up and bring it close to read.
		_tween.tween_property(self, "position", Vector3(-0.10, -0.20, -1.05), 0.23).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
		_tween.tween_property(self, "rotation", Vector3(-0.16, -0.08, 0.08), 0.23)
		_tween.chain().tween_property(self, "position", Vector3(0, 0, -_view_distance()), 0.30).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN_OUT)
		_tween.parallel().tween_property(self, "rotation", Vector3.ZERO, 0.30)
		_tween.parallel().tween_property(_camera, "fov", _rest_fov - 7.0, 0.30)
		_tween.chain().tween_callback(func():
			transitioning = false
			presented.emit()
		)
	else:
		_tween.set_parallel(true)
		_tween.tween_property(self, "position", Vector3(0, -0.9, -0.55), 0.30).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)
		_tween.tween_property(self, "rotation", Vector3(-0.35, 0.0, 0.08), 0.30)
		_tween.tween_property(_camera, "fov", _rest_fov, 0.30)
		_tween.chain().tween_callback(func():
			visible = false
			transitioning = false
			_hands._is_tablet_open = false
			_hands.get_node("RightHand").show()
			_hands.get_node("LeftHand").hide()
			_hands.get_node("RightHand/Tool").show()
			if _hands.needle_mesh:
				_hands.needle_mesh.visible = not _hands._is_carrying
			stowed.emit()
		)

func _process(delta: float) -> void:
	if not visible or not _hands:
		return
	if requested_open and not transitioning:
		position.z = -_view_distance()
	var weight := 1.0 - exp(-30.0 * delta)
	var left_pose := global_transform * Transform3D(Basis.from_euler(Vector3(0.0, -0.12, -0.12)), Vector3(-0.80, -0.11, 0.05))
	_hands.left_hand.global_transform = _hands.left_hand.global_transform.interpolate_with(left_pose, weight)

func screen_rect() -> Rect2:
	var top_left := _camera.unproject_position(_screen.to_global(Vector3(-SCREEN_SIZE.x * 0.5, SCREEN_SIZE.y * 0.5, 0.005)))
	var bottom_right := _camera.unproject_position(_screen.to_global(Vector3(SCREEN_SIZE.x * 0.5, -SCREEN_SIZE.y * 0.5, 0.005)))
	return Rect2(top_left, bottom_right - top_left)
