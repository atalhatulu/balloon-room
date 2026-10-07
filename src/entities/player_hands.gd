class_name PlayerHands
extends Node3D

const WeaponFinish = preload("res://src/entities/weapon_finish.gd")
# Logical equipment changes immediately; the displayed item changes below the frame.
# 1 = needle, 2 = dart, 3 = minigun (slot 4 or frenzy), 4 = flashlight, 5 = shotgun (slot 3)
var visual_equipment := 1
var equipment_lower := 0.0
var equipment_stowing := false
@onready var equipment_rest_position := position
@onready var equipment_rest_rotation := rotation

func requested_equipment() -> int:
	if is_flashlight_equipped: return 4
	if is_minigun_equipped: return 3
	if _player:
		if _player.is_minigun_frenzy or _player.current_weapon_slot == 4:
			return 3
		elif _player.current_weapon_slot == 3:
			return 5
		return _player.current_weapon_slot
	return 1

func equipment_busy() -> bool:
	return equipment_stowing or equipment_lower > 0.001 or visual_equipment != requested_equipment()

func _update_equipment_transition(delta: float) -> void:
	var requested := requested_equipment()
	var concealed: bool = _is_tablet_open or _is_carrying or (_player != null and _player.is_ui_open)
	if concealed:
		# Tablet/carry rigs own the hands. Resume from a lowered weapon afterwards.
		equipment_lower = 1.0
		visual_equipment = requested
		equipment_stowing = false
		position = equipment_rest_position
		rotation = equipment_rest_rotation
	else:
		if visual_equipment != requested and not equipment_stowing:
			cancel_actions()
			equipment_stowing = true
		if equipment_stowing:
			equipment_lower = move_toward(equipment_lower, 1.0, delta / (0.24 if visual_equipment in [3, 5] else 0.18))
			if equipment_lower >= 1.0:
				visual_equipment = requested
				equipment_stowing = false
				# Both hands adopt the next grip while below the camera.
				if visual_equipment == 3:
					right_hand.position = Vector3(0.12, -0.24, -0.32)
					right_hand.rotation = Vector3(deg_to_rad(-8.0), 0, 0)
					left_hand.position = Vector3(0.06, -0.06, -0.60)
					left_hand.rotation = Vector3(deg_to_rad(35.0), deg_to_rad(-15.0), deg_to_rad(25.0))
				elif visual_equipment == 5:
					right_hand.position = _right_rest_pos
					right_hand.rotation = _right_rest_rot
					left_hand.position = Vector3(0.08, -0.12, -0.45)
					left_hand.rotation = Vector3(deg_to_rad(25.0), deg_to_rad(-10.0), deg_to_rad(15.0))
				else:
					right_hand.position = _right_rest_pos
					right_hand.rotation = _right_rest_rot
					left_hand.position = _left_rest_pos
					left_hand.rotation = _left_rest_rot
		else:
			equipment_lower = move_toward(equipment_lower, 0.0, delta / (0.38 if visual_equipment in [3, 5] else 0.28))
		var eased := smoothstep(0.0, 1.0, equipment_lower)
		position = equipment_rest_position + Vector3(0.07 * eased, -0.95 * eased, 0.18 * eased)
		rotation = equipment_rest_rotation + Vector3(-0.14, 0.05, -0.08) * eased
	tool_node.visible = not concealed and visual_equipment == 1
	flashlight_prop.visible = not concealed and visual_equipment == 4
	if not _is_tablet_open:
		left_hand.visible = _is_carrying or (not concealed and visual_equipment in [3, 5])
		left_hand.process_mode = Node.PROCESS_MODE_INHERIT
		for i in range(_left_fingers.size()):
			if visual_equipment == 3:
				_left_fingers[i].rotation = Vector3(deg_to_rad(75.0), deg_to_rad(-5.0), deg_to_rad(10.0))
			elif visual_equipment == 5:
				_left_fingers[i].rotation = Vector3(deg_to_rad(65.0), deg_to_rad(-5.0), deg_to_rad(5.0))
			else:
				_left_fingers[i].rotation = _finger_rest[i]

var minigun_flash: MeshInstance3D
var minigun_glow: StandardMaterial3D
var minigun_kick := 0.0
var minigun_shot_left := 0.0
var minigun_flash_left := 0.0
var minigun_draw := 0.0
var minigun_warmth := 0.0
var minigun_motion := 0.0
var minigun_heat_bars: Array[MeshInstance3D] = []
var minigun_heat_mats: Array[StandardMaterial3D] = []

# Spring Damper Physics Parameters
@export var sway_pos_sensitivity: float = 0.0015
@export var sway_rot_sensitivity: float = 0.0035

# Right Hand (Dominant needle hand: responsive, tighter spring)
@export var spring_stiffness_r: float = 140.0
@export var spring_damping_r: float = 17.0
@export var max_pos_sway_r: float = 0.05
@export var max_rot_sway_r: float = 0.12

# Left Hand (Free support hand: looser, lagging secondary spring)
@export var spring_stiffness_l: float = 85.0
@export var spring_damping_l: float = 11.5
@export var max_pos_sway_l: float = 0.08
@export var max_rot_sway_l: float = 0.16

@onready var right_hand: Node3D = $RightHand
@onready var left_hand: Node3D = $LeftHand
@onready var needle_mesh: Node3D = get_node_or_null("RightHand/Tool/Needle")
@onready var tool_node: Node3D = get_node_or_null("RightHand/Tool")

var minigun_model: Node3D = null
var minigun_barrels: Node3D = null
var is_minigun_equipped: bool = false
var minigun_spin_speed: float = 0.0

# Rest positions and rotations
var _right_rest_pos: Vector3
var _left_rest_pos: Vector3
var _right_rest_rot: Vector3
var _left_rest_rot: Vector3

# Damped Harmonic Oscillator (Spring) state for Right Hand
var _pos_offset_r: Vector3 = Vector3.ZERO
var _pos_vel_r: Vector3 = Vector3.ZERO
var _rot_offset_r: Vector3 = Vector3.ZERO
var _rot_vel_r: Vector3 = Vector3.ZERO

# Damped Harmonic Oscillator (Spring) state for Left Hand
var _pos_offset_l: Vector3 = Vector3.ZERO
var _pos_vel_l: Vector3 = Vector3.ZERO
var _rot_offset_l: Vector3 = Vector3.ZERO
var _rot_vel_l: Vector3 = Vector3.ZERO

var _bob_timer: float = 0.0
var _player: CharacterBody3D = null

var _right_tween: Tween = null
var _left_tween: Tween = null
var _is_carrying: bool = false
var arm_rig: Node3D

# Continuous Raycast Reach / Proximity Tracking (like toothbrush / cleaning tool in just-one-more-floor)
var _is_aiming_at_balloon: bool = false
var _target_reach_pos: Vector3 = Vector3.ZERO
var _target_reach_rot: Vector3 = Vector3.ZERO
var _target_reach_weight: float = 0.0

signal needle_contact(target: Node)

var contact_pending: bool = false
var air_pending: bool = false
var _strike_target: WeakRef
var _strike_local_point := Vector3.ZERO
var _strike_local_normal := Vector3.UP
var _strike_start := Transform3D.IDENTITY
var _needle_tip_local := Vector3.ZERO
var _needle_axis_local := Vector3.UP
var last_contact_point := Vector3.ZERO
var _left_fingers: Array[Node3D] = []
var _finger_rest: Array[Vector3] = []

func _pose_at_surface(world_point: Vector3, world_normal: Vector3, clearance: float) -> Transform3D:
	var point := to_local(world_point)
	var normal := (global_basis.inverse() * world_normal).normalized()
	if normal.length_squared() < 0.01:
		normal = Vector3.BACK
	# Rotate the actual needle shaft axis, then subtract the transformed tip offset.
	# This places the tip at the surface, instead of placing the palm at the hit.
	# Keep a small right-hand approach angle so the shaft remains visible
	# instead of presenting the back of the palm directly over the crosshair.
	var approach := (-normal + Vector3(-0.65, 0.28, 0.0)).normalized()
	var aligned := Basis(Quaternion(_needle_axis_local, approach))
	return Transform3D(aligned, point + normal * clearance - aligned * _needle_tip_local)

func set_target_reach(is_aiming: bool, hit_distance: float = 0.0, hit_normal: Vector3 = Vector3.ZERO, hit_point: Vector3 = Vector3.ZERO) -> void:
	_is_aiming_at_balloon = is_aiming and not equipment_busy() and not _is_carrying and not _is_tablet_open and not is_minigun_equipped
	if not _is_aiming_at_balloon:
		return
	if hit_point == Vector3.ZERO:
		hit_point = global_position - global_basis.z * hit_distance
	var pose := _pose_at_surface(hit_point, hit_normal, 0.18)
	_target_reach_pos = pose.origin
	_target_reach_rot = pose.basis.get_euler()

func _ready() -> void:
	if right_hand:
		_right_rest_pos = right_hand.position
		_right_rest_rot = right_hand.rotation
	if left_hand:
		_left_rest_pos = left_hand.position
		_left_rest_rot = left_hand.rotation
		
	if needle_mesh:
		_needle_tip_local = right_hand.to_local(needle_mesh.to_global(Vector3(0, 0.16, 0)))
		_needle_axis_local = (right_hand.global_basis.inverse() * needle_mesh.global_basis.y).normalized()
	for i in range(1, 4):
		var finger := left_hand.get_node_or_null("Finger%d" % i) as Node3D
		if finger:
			_left_fingers.append(finger)
			_finger_rest.append(finger.rotation)
	left_hand.hide()
	left_hand.process_mode = Node.PROCESS_MODE_DISABLED
	_setup_hand_flashlight()
	tablet_rig = preload("res://src/entities/tablet_rig.gd").new()
	add_child(tablet_rig)
	tablet_rig.setup(self, get_parent() as Camera3D)
	# Find parent Player
	var p = get_parent()
	while p and not (p is CharacterBody3D):
		p = p.get_parent()
	_player = p as CharacterBody3D
	arm_rig = preload("res://src/entities/right_arm_rig.gd").new()
	arm_rig.name = "RightArm"
	add_child(arm_rig)
	arm_rig.setup(self, _player)
	var left_arm = preload("res://src/entities/right_arm_rig.gd").new()
	left_arm.name = "TabletLeftArm"
	add_child(left_arm)
	left_arm.setup(self, _player, true)

func handle_mouse_motion(relative: Vector2) -> void:
	var rx = relative.x
	var ry = relative.y
	
	# Right hand (Needle): Fluid, responsive inertia - lags behind camera turns and tilts organically
	var impulse_r_x = -rx * sway_pos_sensitivity * 1.8
	var impulse_r_y = -ry * sway_pos_sensitivity * 1.8
	_pos_vel_r.x += impulse_r_x * 9.5
	_pos_vel_r.y += impulse_r_y * 9.5
	_rot_vel_r.x += ry * sway_rot_sensitivity * 6.5
	_rot_vel_r.y += -rx * sway_rot_sensitivity * 8.5
	_rot_vel_r.z += -rx * sway_rot_sensitivity * 4.8 # Organic wrist bank
	
	# Left hand: looser, lagging follow-through, opposite roll
	var impulse_l_x = -rx * sway_pos_sensitivity * 2.2
	var impulse_l_y = -ry * sway_pos_sensitivity * 2.0
	_pos_vel_l.x += impulse_l_x * 12.0
	_pos_vel_l.y += impulse_l_y * 11.0
	_rot_vel_l.x += ry * sway_rot_sensitivity * 7.5
	_rot_vel_l.y += -rx * sway_rot_sensitivity * 10.5
	_rot_vel_l.z += rx * sway_rot_sensitivity * 5.0 # opposite outward roll prevents parallel wiper look!

func _process(delta: float) -> void:
	_update_equipment_transition(delta)
	_update_minigun_visuals(delta)
	# The tablet owns both poses until closed; idle must not pull it back down.
	if _is_tablet_open:
		return
	delta = minf(delta, 0.033)
	# 1. Update Spring-Damper Physics for Right Hand
	var force_pos_r = -spring_stiffness_r * _pos_offset_r - spring_damping_r * _pos_vel_r
	_pos_vel_r += force_pos_r * delta
	_pos_offset_r += _pos_vel_r * delta
	_pos_offset_r.x = clamp(_pos_offset_r.x, -max_pos_sway_r, max_pos_sway_r)
	_pos_offset_r.y = clamp(_pos_offset_r.y, -max_pos_sway_r, max_pos_sway_r)
	
	var force_rot_r = -spring_stiffness_r * _rot_offset_r - spring_damping_r * _rot_vel_r
	_rot_vel_r += force_rot_r * delta
	_rot_offset_r += _rot_vel_r * delta
	_rot_offset_r.x = clamp(_rot_offset_r.x, -max_rot_sway_r * 0.7, max_rot_sway_r * 0.7)
	_rot_offset_r.y = clamp(_rot_offset_r.y, -max_rot_sway_r, max_rot_sway_r)
	_rot_offset_r.z = clamp(_rot_offset_r.z, -max_rot_sway_r * 0.8, max_rot_sway_r * 0.8)
	
	# 2. Update Spring-Damper Physics for Left Hand
	var force_pos_l = -spring_stiffness_l * _pos_offset_l - spring_damping_l * _pos_vel_l
	_pos_vel_l += force_pos_l * delta
	_pos_offset_l += _pos_vel_l * delta
	_pos_offset_l.x = clamp(_pos_offset_l.x, -max_pos_sway_l, max_pos_sway_l)
	_pos_offset_l.y = clamp(_pos_offset_l.y, -max_pos_sway_l, max_pos_sway_l)
	
	var force_rot_l = -spring_stiffness_l * _rot_offset_l - spring_damping_l * _rot_vel_l
	_rot_vel_l += force_rot_l * delta
	_rot_offset_l += _rot_vel_l * delta
	_rot_offset_l.x = clamp(_rot_offset_l.x, -max_rot_sway_l * 0.8, max_rot_sway_l * 0.8)
	_rot_offset_l.y = clamp(_rot_offset_l.y, -max_rot_sway_l, max_rot_sway_l)
	_rot_offset_l.z = clamp(_rot_offset_l.z, -max_rot_sway_l, max_rot_sway_l)
	
	# 3. Calculate Movement Inertia (Strafing tilt & jumping dip)
	var move_tilt_r_z: float = 0.0
	var move_tilt_l_z: float = 0.0
	var move_dip_y: float = 0.0
	var is_moving = false
	var speed_factor = 1.0
	
	if _player and is_instance_valid(_player):
		var local_vel = _player.global_transform.basis.inverse() * _player.velocity
		move_tilt_r_z = clamp(-local_vel.x * 0.012, -0.08, 0.08)
		move_tilt_l_z = clamp(-local_vel.x * 0.018, -0.12, 0.12)
		move_dip_y = clamp(local_vel.y * 0.006, -0.04, 0.03)
		
		var vel_h = Vector2(local_vel.x, local_vel.z).length()
		if vel_h > 0.4 and _player.is_on_floor():
			is_moving = true
			speed_factor = clamp(vel_h / 5.2, 0.8, 1.8)
			
	if is_moving:
		_bob_timer += delta * 9.0 * speed_factor
	else:
		_bob_timer += delta * 2.0
		
	# Natural alternating footsteps: Right and Left hands have phase-offset bobbing
	var bob_r_h = sin(_bob_timer * 0.5) * (0.010 if is_moving else 0.002)
	var bob_r_v = abs(sin(_bob_timer)) * (0.014 if is_moving else 0.003)
	var bob_r_rot_z = cos(_bob_timer * 0.5) * (0.020 if is_moving else 0.004)
	
	var bob_l_h = -sin(_bob_timer * 0.5 + 0.5) * (0.014 if is_moving else 0.003)
	var bob_l_v = abs(sin(_bob_timer + 1.2)) * (0.018 if is_moving else 0.004)
	var bob_l_rot_z = -cos(_bob_timer * 0.5 + 0.5) * (0.028 if is_moving else 0.005)
	
	# 4. Apply to Right Hand
	if right_hand and (_right_tween == null or not _right_tween.is_running()):
		var base_pos = _right_rest_pos
		var base_rot = _right_rest_rot
		if _is_carrying:
			base_pos += Vector3(-0.06, 0.08, -0.08)
		elif visual_equipment == 4:
			base_pos = Vector3(0.23, -0.21, -0.40)
			base_rot = Vector3.ZERO
		elif visual_equipment == 3:
			base_pos = Vector3(0.12, -0.24, -0.32)
			base_rot = Vector3(deg_to_rad(-8.0), deg_to_rad(0.0), deg_to_rad(0.0))
		elif visual_equipment == 5:
			base_pos = Vector3(0.16, -0.20, -0.30)
			base_rot = Vector3(deg_to_rad(-4.0), deg_to_rad(0.0), deg_to_rad(0.0))
			
		var target_pos = base_pos + Vector3(
			_pos_offset_r.x + bob_r_h,
			_pos_offset_r.y - bob_r_v + move_dip_y,
			-_pos_offset_r.y * 0.2
		)
		var target_rot = base_rot + Vector3(
			_rot_offset_r.x,
			_rot_offset_r.y,
			_rot_offset_r.z + move_tilt_r_z + bob_r_rot_z
		)
		
		# Smooth continuous reach towards targeted balloon (only for needle)
		var target_w = 1.0 if (_is_aiming_at_balloon and visual_equipment == 1 and not equipment_busy()) else 0.0
		_target_reach_weight = move_toward(_target_reach_weight, target_w, delta * 8.0)
		if _target_reach_weight > 0.001:
			target_pos = target_pos.lerp(_target_reach_pos, _target_reach_weight)
			target_rot = target_rot.lerp(_target_reach_rot, _target_reach_weight)
			
		right_hand.position = right_hand.position.lerp(target_pos, delta * 16.0)
		right_hand.quaternion = right_hand.quaternion.slerp(Quaternion.from_euler(target_rot), 1.0 - exp(-16.0 * delta))
		
		
	# 5. Apply to Left Hand
	if left_hand.visible and (_left_tween == null or not _left_tween.is_running()):
		var base_pos = _left_rest_pos
		var base_rot = _left_rest_rot
		if _is_carrying:
			base_pos += Vector3(0.06, 0.08, -0.08)
		elif visual_equipment == 3:
			base_pos = Vector3(0.06, -0.06, -0.60)
			base_rot = Vector3(deg_to_rad(35.0), deg_to_rad(-15.0), deg_to_rad(25.0))
		elif visual_equipment == 5:
			base_pos = Vector3(0.08, -0.12, -0.45)
			base_rot = Vector3(deg_to_rad(25.0), deg_to_rad(-10.0), deg_to_rad(15.0))
			
		var target_pos = base_pos + Vector3(
			_pos_offset_l.x + bob_l_h,
			_pos_offset_l.y - bob_l_v + move_dip_y * 1.15,
			-_pos_offset_l.y * 0.2
		)
		var target_rot = base_rot + Vector3(
			_rot_offset_l.x,
			_rot_offset_l.y,
			_rot_offset_l.z + move_tilt_l_z + bob_l_rot_z
		)
		left_hand.position = left_hand.position.lerp(target_pos, delta * 18.0)
		left_hand.rotation = left_hand.rotation.lerp(target_rot, delta * 18.0)


func play_target_stab(target: Node3D, point: Vector3, normal: Vector3, duration: float = 0.07) -> void:
	if contact_pending or _is_carrying or _is_tablet_open:
		return
	if _right_tween:
		_right_tween.kill()
	contact_pending = true
	_strike_target = weakref(target)
	_strike_local_point = target.mesh_instance.to_local(point)
	_strike_local_normal = target.mesh_instance.global_basis.transposed() * normal
	_strike_start = right_hand.transform
	_right_tween = create_tween()
	_right_tween.tween_method(_advance_strike, 0.0, 1.0, clampf(duration, 0.012, 0.09)).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	_right_tween.tween_callback(_finish_strike)
	_right_tween.tween_property(right_hand, "position", _right_rest_pos, 0.14).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	_right_tween.parallel().tween_property(right_hand, "quaternion", Quaternion.from_euler(_right_rest_rot), 0.14)

func _advance_strike(weight: float) -> void:
	var target = _strike_target.get_ref() if _strike_target else null
	if not is_instance_valid(target) or target.get("is_popped"):
		return
	var point: Vector3 = target.mesh_instance.to_global(_strike_local_point)
	var normal: Vector3 = (target.mesh_instance.global_basis.inverse().transposed() * _strike_local_normal).normalized()
	last_contact_point = point
	var pose := _pose_at_surface(point, normal, 0.0)
	right_hand.transform = _strike_start.interpolate_with(pose, weight)
	# Small wrist arc during approach, exactly zero at contact.
	right_hand.position.y += sin(weight * PI) * 0.035

func _finish_strike() -> void:
	_advance_strike(1.0)
	contact_pending = false
	var target = _strike_target.get_ref() if _strike_target else null
	needle_contact.emit(target if is_instance_valid(target) else null)
	_strike_target = null

func play_stab(_target_dist: float = 0.0) -> void:
	if contact_pending or _is_carrying or _is_tablet_open:
		return
	if _right_tween:
		_right_tween.kill()
	_right_tween = create_tween()
	_right_tween.tween_property(right_hand, "position", _right_rest_pos + Vector3(-0.08, 0.04, -0.25), 0.06)
	_right_tween.tween_property(right_hand, "position", _right_rest_pos, 0.13)

func play_nudge() -> void:
	# Left-hand air action retired; reserved for a future equipped tool.
	return

func cancel_actions() -> void:
	contact_pending = false
	air_pending = false
	_strike_target = null
	_is_aiming_at_balloon = false
	_target_reach_weight = 0.0
	if _right_tween:
		_right_tween.kill()
	if _left_tween:
		_left_tween.kill()
	for i in range(_left_fingers.size()):
		_left_fingers[i].rotation = _finger_rest[i]


func set_carrying_device(is_carrying: bool) -> void:
	if is_carrying:
		cancel_actions()
	_is_carrying = is_carrying
	if needle_mesh:
		needle_mesh.visible = not is_carrying and not _is_tablet_open

var tablet_rig: Node3D
var _is_tablet_open: bool = false
@onready var tablet_device: Node3D = get_node_or_null("LeftHand/TabletDevice")

func set_tablet_mode(is_open: bool) -> void:
	if tablet_rig:
		tablet_rig.set_open(is_open)

var flashlight_prop: Node3D = null
var is_flashlight_equipped: bool = false

func _setup_hand_flashlight() -> void:
	if not right_hand: return
	flashlight_prop = Node3D.new()
	flashlight_prop.name = "IndustrialFlashlight"
	
	# Materials
	var mat_body = StandardMaterial3D.new()
	mat_body.albedo_color = Color(0.15, 0.17, 0.20)
	mat_body.metallic = 0.6
	mat_body.roughness = 0.35
	
	var mat_yellow = StandardMaterial3D.new()
	mat_yellow.albedo_color = Color(0.92, 0.65, 0.12)
	mat_yellow.metallic = 0.2
	mat_yellow.roughness = 0.4
	
	var mat_lens = StandardMaterial3D.new()
	mat_lens.albedo_color = Color(0.9, 0.95, 1.0)
	mat_lens.emission_enabled = true
	mat_lens.emission = Color(1.0, 0.95, 0.8)
	mat_lens.emission_energy_multiplier = 4.0
	
	# Cylinder handle
	var handle = MeshInstance3D.new()
	var h_mesh = CylinderMesh.new()
	h_mesh.top_radius = 0.024
	h_mesh.bottom_radius = 0.022
	h_mesh.height = 0.18
	handle.mesh = h_mesh
	handle.material_override = mat_body
	handle.rotation_degrees = Vector3(90, 0, 0)
	flashlight_prop.add_child(handle)
	
	# Yellow grip ring
	var grip = MeshInstance3D.new()
	var g_mesh = CylinderMesh.new()
	g_mesh.top_radius = 0.026
	g_mesh.bottom_radius = 0.026
	g_mesh.height = 0.06
	grip.mesh = g_mesh
	grip.material_override = mat_yellow
	grip.rotation_degrees = Vector3(90, 0, 0)
	grip.position = Vector3(0, 0, 0.02)
	flashlight_prop.add_child(grip)
	
	# Bezel head
	var head_mesh = CylinderMesh.new()
	head_mesh.top_radius = 0.040
	head_mesh.bottom_radius = 0.025
	head_mesh.height = 0.06
	var head_node = MeshInstance3D.new()
	head_node.mesh = head_mesh
	head_node.material_override = mat_body
	head_node.rotation_degrees = Vector3(90, 0, 0)
	head_node.position = Vector3(0, 0, -0.11)
	flashlight_prop.add_child(head_node)
	
	# Glowing lens disc
	var lens_mesh = CylinderMesh.new()
	lens_mesh.top_radius = 0.038
	lens_mesh.bottom_radius = 0.038
	lens_mesh.height = 0.008
	var lens = MeshInstance3D.new()
	lens.mesh = lens_mesh
	lens.material_override = mat_lens
	lens.rotation_degrees = Vector3(90, 0, 0)
	lens.position = Vector3(0, 0, -0.14)
	flashlight_prop.add_child(lens)
	
	flashlight_prop.position = Vector3(0.02, 0.01, -0.04)
	flashlight_prop.rotation_degrees = Vector3(10, 5, 0)
	flashlight_prop.visible = false
	right_hand.add_child(flashlight_prop)

func set_flashlight_mode(enabled: bool) -> void:
	is_flashlight_equipped = enabled
	cancel_actions()


func pop_recoil(strength: float = 1.0) -> void:
	_pos_vel_r.y -= 0.10 * strength
	_rot_vel_r.x -= 0.65 * strength

func _setup_minigun_model() -> void:
	if not right_hand: return
	minigun_model = Node3D.new()
	minigun_model.name = "MinigunModel"
	minigun_model.visible = false
	
	var mat_body = StandardMaterial3D.new()
	mat_body.albedo_color = Color(0.11, 0.12, 0.15)
	mat_body.metallic = 0.90
	mat_body.roughness = 0.22
	
	var mat_accent = StandardMaterial3D.new()
	mat_accent.albedo_color = Color(0.95, 0.45, 0.08)
	mat_accent.metallic = 0.45
	mat_accent.roughness = 0.30
	
	var mat_barrel = StandardMaterial3D.new()
	mat_barrel.albedo_color = Color(0.32, 0.34, 0.40)
	mat_barrel.metallic = 0.98
	mat_barrel.roughness = 0.15
	
	# Receiver chassis (Heavier, larger)
	var receiver = MeshInstance3D.new()
	var rec_mesh = WeaponFinish.beveled_mesh(Vector3(0.14, 0.16, 0.38))
	receiver.mesh = rec_mesh
	receiver.material_override = mat_body
	receiver.position = Vector3(0, 0.02, -0.08)
	minigun_model.add_child(receiver)
	
	# Motor housing cylinder
	var motor = MeshInstance3D.new()
	var motor_mesh = CylinderMesh.new()
	motor_mesh.top_radius = 0.085
	motor_mesh.bottom_radius = 0.085
	motor_mesh.height = 0.20
	motor.mesh = motor_mesh
	motor.material_override = mat_accent
	motor.rotation_degrees = Vector3(90, 0, 0)
	motor.position = Vector3(0, 0.02, -0.26)
	minigun_model.add_child(motor)
	
	# Rotating Barrels cluster
	minigun_barrels = Node3D.new()
	minigun_barrels.name = "Barrels"
	minigun_barrels.position = Vector3(0, 0.02, -0.36)
	minigun_model.add_child(minigun_barrels)
	
	for i in range(6):
		var angle = float(i) * TAU / 6.0
		var barrel = MeshInstance3D.new()
		var b_mesh = CylinderMesh.new()
		b_mesh.top_radius = 0.014
		b_mesh.bottom_radius = 0.014
		b_mesh.height = 0.52
		barrel.mesh = b_mesh
		barrel.material_override = mat_barrel
		barrel.rotation_degrees = Vector3(90, 0, 0)
		barrel.position = Vector3(cos(angle) * 0.058, sin(angle) * 0.058, -0.26)
		minigun_barrels.add_child(barrel)
		
	# Dual front ring clamps
	for ring_z in [-0.22, -0.48]:
		var clamp_ring = MeshInstance3D.new()
		var ring_mesh = TorusMesh.new()
		ring_mesh.inner_radius = 0.054
		ring_mesh.outer_radius = 0.072
		clamp_ring.mesh = ring_mesh
		clamp_ring.material_override = mat_body
		clamp_ring.position = Vector3(0, 0, ring_z)
		clamp_ring.rotation.x = PI / 2.0
		minigun_barrels.add_child(clamp_ring)
	var steel := WeaponFinish.material(Color("9aa8b3"))
	var dark := WeaponFinish.material(Color("101820"), 0.2)
	minigun_glow = WeaponFinish.material(Color("f09c38"), 0.4, true)
	WeaponFinish.tube(minigun_model, 0.12, 0.22, Vector3(0.17, -0.035, -0.06), mat_body, "FeedDrum")
	WeaponFinish.tube(minigun_model, 0.10, 0.015, Vector3(0.17, -0.035, -0.178), mat_accent, "DrumCap")
	for side in [-1, 1]:
		WeaponFinish.box(minigun_model, Vector3(0.018, 0.10, 0.25), Vector3(side * 0.078, 0.025, -0.08), steel, "Armor%d" % side)
		for i in range(5):
			WeaponFinish.box(minigun_model, Vector3(0.022, 0.043, 0.012), Vector3(side * 0.088, 0.03, -0.18 + i * 0.039), dark, "CoolingVent%d_%d" % [side, i])
		WeaponFinish.box(minigun_model, Vector3(0.022, 0.009, 0.15), Vector3(side * 0.09, 0.09, -0.10), minigun_glow, "HeatStrip%d" % side)
	for i in range(5):
		var gauge_mat := WeaponFinish.material(Color("43cfc0"), 0.25, true)
		var gauge := WeaponFinish.box(minigun_model, Vector3(0.024, 0.012, 0.032), Vector3(-0.055 + i * 0.027, 0.112, -0.04), gauge_mat, "HeatGauge%d" % i)
		minigun_heat_bars.append(gauge)
		minigun_heat_mats.append(gauge_mat)
	for i in range(6):
		var angle := float(i) * TAU / 6.0
		WeaponFinish.tube(minigun_barrels, 0.018, 0.034, Vector3(cos(angle) * 0.058, sin(angle) * 0.058, -0.51), steel, "BarrelTip%d" % i)
		WeaponFinish.tube(minigun_barrels, 0.011, 0.003, Vector3(cos(angle) * 0.058, sin(angle) * 0.058, -0.529), dark, "BarrelBore%d" % i)
	
	# Heavy top carry handle (Gripped firmly by Left Hand)
	var handle = MeshInstance3D.new()
	var h_mesh = BoxMesh.new()
	h_mesh.size = Vector3(0.04, 0.09, 0.28)
	handle.mesh = h_mesh
	handle.material_override = mat_accent
	handle.position = Vector3(-0.06, 0.16, -0.16)
	minigun_model.add_child(handle)
	
	# Rear firing spade grip (Gripped by Right Hand)
	var rear_grip = MeshInstance3D.new()
	var grip_mesh = BoxMesh.new()
	grip_mesh.size = Vector3(0.045, 0.12, 0.06)
	rear_grip.mesh = grip_mesh
	rear_grip.material_override = mat_accent
	rear_grip.position = Vector3(0.0, -0.04, 0.12)
	minigun_model.add_child(rear_grip)

	# Dedicated Muzzle Tip Marker node for 100% accurate bullet ray / tracer origin
	var muzzle_node = Marker3D.new()
	muzzle_node.name = "MuzzleMarker"
	muzzle_node.position = Vector3(0, 0.02, -0.895)
	minigun_model.add_child(muzzle_node)
	minigun_flash = WeaponFinish.flash(muzzle_node, Color("ffd489"), 0.035, 0.17)
	
	# Position minigun solidly in camera view space (parented to Hands root for true FPS stability)
	minigun_model.position = Vector3(0.12, -0.22, -0.46)
	minigun_model.rotation_degrees = Vector3(-2.0, 0.0, 0.0)
	minigun_model.scale = Vector3.ONE * 1.35
	add_child(minigun_model)

func minigun_shot_feedback() -> void:
	minigun_kick = minf(0.045, minigun_kick + 0.018)
	minigun_shot_left = 0.08
	minigun_flash_left = 0.022
	minigun_warmth = minf(1.0, minigun_warmth + 0.025)

func _update_minigun_visuals(delta: float) -> void:
	if not is_instance_valid(minigun_model): return
	var usable: bool = visual_equipment == 3 and not _is_tablet_open and not _is_carrying and (_player == null or not _player.is_ui_open)
	minigun_shot_left = maxf(0.0, minigun_shot_left - delta)
	minigun_flash_left = maxf(0.0, minigun_flash_left - delta)
	minigun_kick *= exp(-22.0 * delta)
	minigun_warmth = maxf(0.0, minigun_warmth - delta * 0.12)
	minigun_motion += delta
	var firing: bool = visual_equipment == 3 and not equipment_busy() and usable and (_player == null or not _player.is_minigun_blocked()) and (minigun_shot_left > 0.0 or (Input.mouse_mode == Input.MOUSE_MODE_CAPTURED and Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT)))
	minigun_spin_speed = move_toward(minigun_spin_speed, 48.0 if firing else 0.0, delta * (85.0 if firing else 32.0))
	minigun_barrels.rotate_z(minigun_spin_speed * minf(delta, 0.05))
	# Shared hand rig supplies the draw/stow movement for every weapon.
	minigun_draw = 1.0 if usable else 0.0
	minigun_model.visible = usable
	minigun_model.position = Vector3(0.12, -0.22, -0.46 + minigun_kick)
	minigun_model.rotation = Vector3(deg_to_rad(-2.0) + minigun_kick * 1.2, sin(minigun_motion * 37.0) * minigun_kick * 0.12, sin(minigun_motion * 52.0) * minigun_kick * 0.18)
	minigun_flash.visible = minigun_model.visible and minigun_flash_left > 0.0
	var heat := maxf(minigun_warmth, _player.minigun_heat if _player else 0.0)
	var heat_color := Color("43cfc0").lerp(Color("ff442e"), heat)
	minigun_glow.albedo_color = heat_color
	minigun_glow.emission = heat_color
	minigun_glow.emission_energy_multiplier = 0.6 + heat * 3.4
	for i in range(minigun_heat_mats.size()):
		var lit := heat >= float(i + 1) / float(minigun_heat_mats.size())
		minigun_heat_mats[i].albedo_color = heat_color if lit else Color("25343b")
		minigun_heat_mats[i].emission = heat_color if lit else Color("101719")
		minigun_heat_mats[i].emission_energy_multiplier = 0.8 + heat * 2.5 if lit else 0.0

func get_minigun_muzzle_position() -> Vector3:
	if minigun_model and minigun_model.has_node("MuzzleMarker"):
		return minigun_model.get_node("MuzzleMarker").global_position
	elif minigun_model:
		return minigun_model.to_global(Vector3(0, 0.02, -0.68))
	return global_position

func set_minigun_mode(enabled: bool) -> void:
	if is_minigun_equipped == enabled: return
	is_minigun_equipped = enabled
	cancel_actions()
	if not minigun_model:
		_setup_minigun_model()
