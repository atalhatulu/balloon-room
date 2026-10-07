extends RigidBody3D

const Design = preload("res://src/entities/collectible_design.gd")
var _special_detail: MeshInstance3D
static var _detail_materials: Dictionary = {}

signal popped(balloon_node: RigidBody3D, pop_position: Vector3, balloon_color: Color, combo_depth: int, balloon_type: int, is_midair: bool)

@export var pop_particle_scene: PackedScene = preload("res://src/entities/pop_particle.tscn")

var balloon_color: Color = Color(1.0, 0.35, 0.45)
var is_popped: bool = false
var last_pop_source := ""
var has_touched_floor: bool = false
var blown_by_fan_time: float = -10.0
var pulled_by_magnet_time: float = -10.0
const SPECIAL_LIFETIME := 10.0
var special_seconds_left := -1.0
var expiry_label: Label3D
var expiry_display := -1

func _integrate_forces(state: PhysicsDirectBodyState3D) -> void:
	if not _is_timed_event_balloon() or is_popped or special_seconds_left >= 0.0: return
	# A supporting contact includes another balloon: stacks cannot store bonuses.
	for i in range(state.get_contact_count()):
		if state.get_contact_collider_position(i).y < state.transform.origin.y - 0.08:
			has_touched_floor = true
			special_seconds_left = SPECIAL_LIFETIME
			set_process(true)
			break

func _is_timed_event_balloon() -> bool:
	return gas_type == "chroma"

func _expire_special() -> void:
	if is_popped: return
	is_popped = true
	var manager = get_node_or_null("/root/Main/GameManager")
	if manager:
		manager.active_balloons = maxi(0, manager.active_balloons - tier_value)
		manager.active_count_changed.emit(manager.active_balloons, manager.max_room_balloons)
	# Expiration awards no coins, pops, quests, chain explosions or bonuses.
	hide()
	queue_free()

var custom_color_set: bool = false
var tier: int = 1
var tier_value: int = 1
var max_health: int = 1
var current_health: int = 1
var gas_type: String = "normal" # "normal", "bomb", "gold", "air", "electric", "cryo", "chroma"
var _chroma_mat: StandardMaterial3D = null
var _chroma_glow: OmniLight3D = null

func _process(delta: float) -> void:
	if is_popped: return
	if _is_timed_event_balloon() and special_seconds_left >= 0.0:
		special_seconds_left = maxf(0.0, special_seconds_left - delta)
		if special_seconds_left <= 0.0:
			_expire_special()
			return
		var seconds := int(ceil(special_seconds_left))
		if seconds != expiry_display:
			expiry_display = seconds
			if not expiry_label:
				expiry_label = Label3D.new()
				expiry_label.font_size = 32
				expiry_label.pixel_size = 0.004
				expiry_label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
				expiry_label.position.y = 0.8
				add_child(expiry_label)
			expiry_label.text = "%d sn" % seconds
			expiry_label.modulate = Color("ff735d") if seconds <= 3 else Color("ffe1a0")
	if gas_type == "chroma" and not is_popped:
		var hue = fmod(Time.get_ticks_msec() * 0.001 * 0.75, 1.0)
		balloon_color = Color.from_hsv(hue, 0.95, 1.0)
		if _chroma_mat:
			_chroma_mat.albedo_color = balloon_color
			_chroma_mat.emission = balloon_color
		if _chroma_glow and is_instance_valid(_chroma_glow):
			_chroma_glow.light_color = balloon_color

func setup_special_type(g: String) -> void:
	gas_type = g
	if is_in_group("needle_bonus"): remove_from_group("needle_bonus")
	if g.begins_with("bonus_") or g == "chroma": add_to_group("needle_bonus")
	match g:
		"chroma":
			balloon_color = Color.from_hsv(0.0, 0.95, 1.0)
			set_process(true)
			if not _chroma_mat:
				_chroma_mat = StandardMaterial3D.new()
				_chroma_mat.shading_mode = BaseMaterial3D.SHADING_MODE_PER_PIXEL
				_chroma_mat.metallic = 0.50
				_chroma_mat.roughness = 0.08
				_chroma_mat.emission_enabled = true
				_chroma_mat.emission_energy_multiplier = 0.85
				_chroma_mat.rim_enabled = true
				_chroma_mat.rim = 1.4
				_chroma_mat.rim_tint = 0.8
			if not _chroma_glow:
				_chroma_glow = OmniLight3D.new()
				_chroma_glow.omni_range = 3.5
				_chroma_glow.light_energy = 1.2
				_chroma_glow.shadow_enabled = false
				add_child(_chroma_glow)
		"bonus_coin":
			balloon_color = Color("ffb72e")
		"bonus_magnet":
			balloon_color = Color("b98cff")
		"bomb":
			balloon_color = Color(0.20, 0.22, 0.25) # Matte charcoal bomb
		"gold":
			balloon_color = Color(1.0, 0.82, 0.12) # Gleaming 24k gold
		"electric":
			balloon_color = Color(0.12, 0.88, 1.0)
		"cryo":
			balloon_color = Color(0.40, 1.0, 0.75)
		_:
			gas_type = "normal"
	# The 0.6% Chroma event balloon alone has a timed lifetime.
	set_process(gas_type == "chroma")
	max_contacts_reported = 4 if _is_timed_event_balloon() else 0
	custom_color_set = true
	_apply_cached_material()
	_apply_physics_profile()
	_apply_controlled_scale()

func setup_gas_type(g: String) -> void:
	setup_special_type(g)

# Shared static material cache to batch draw calls across all balloons
static var _material_cache: Dictionary = {}
static var _active_particle_count: int = 0

# Realistic Physics & Tier Mass/Buoyancy Profiles
# tier: { mass (kg), grav_mult (buoyancy), damp_mult (air drag), bounce (restitution), friction }
static var tier_physics_profiles: Dictionary = {
	1: {
		"mass": 0.05,
		"grav_mult": 0.65,    # Highly buoyant, stays aloft easily in room airflow
		"damp_mult": 1.30,    # Gentle air drag, slow float
		"bounce": 0.75,       # High rubber rebound
		"friction": 0.25
	},
	5: {
		"mass": 0.32,
		"grav_mult": 1.05,    # Metallic, moderate weight, cuts air
		"damp_mult": 0.95,
		"bounce": 0.52,       # Firm metallic bounce
		"friction": 0.35
	},
	10: {
		"mass": 0.85,
		"grav_mult": 1.45,    # Dense neon plasma/crystal, settles mid-to-low
		"damp_mult": 0.75,
		"bounce": 0.34,       # Heavy thud
		"friction": 0.45
	},
	50: {
		"mass": 1.80,
		"grav_mult": 1.70,    # Dense cosmic core
		"damp_mult": 0.65,
		"bounce": 0.25,
		"friction": 0.55
	}
}

static var _phys_mat_cache: Dictionary = {}
static func get_cached_physics_material(t: int) -> PhysicsMaterial:
	if _phys_mat_cache.has(t):
		return _phys_mat_cache[t]
	var prof = tier_physics_profiles.get(t, tier_physics_profiles[1])
	var pmat = PhysicsMaterial.new()
	pmat.bounce = prof["bounce"]
	pmat.friction = prof["friction"]
	pmat.absorbent = false
	_phys_mat_cache[t] = pmat
	return pmat

var current_room_gravity: float = 0.25
var current_room_damp: float = 2.2
var _elastic_tween: Tween = null
var base_scale_vec: Vector3 = Vector3(0.80, 0.80, 0.80)

@onready var mesh_instance: MeshInstance3D = $MeshInstance3D
@onready var knot_mesh: MeshInstance3D = get_node_or_null("MeshInstance3D/Knot")
@onready var collision_shape: CollisionShape3D = $CollisionShape3D

func _ready() -> void:
	add_to_group("balloons")
	collision_layer = 2
	collision_mask = 11
	can_sleep = false
	sleeping = false
	continuous_cd = false
	set_process(false)
	set_physics_process(false)
	
	if not mesh_instance:
		mesh_instance = get_node_or_null("MeshInstance3D")
	if not knot_mesh and mesh_instance:
		knot_mesh = mesh_instance.get_node_or_null("Knot")
	if not collision_shape:
		collision_shape = get_node_or_null("CollisionShape3D")
		
	if mesh_instance:
		mesh_instance.mesh = Design.get_balloon_body()
		mesh_instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	if knot_mesh:
		knot_mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		
	_apply_controlled_scale()
	_apply_physics_profile()
	
	if not custom_color_set:
		setup_random_color()
	else:
		_apply_cached_material()

# Controlled balanced scales: Different balloons have distinct sizes, but NEVER oversized!
static var tier_scales: Dictionary = {
	1: 1.0,   # Standard rubber balloon
	5: 1.5,   # Metallic tier
	10: 2.0,  # Crystal neon tier
	50: 4.0   # Cosmic tier (Visually largest but not exaggerated)
}

func _apply_controlled_scale() -> void:
	var target_base: float = tier_scales.get(tier, 1.0)
	if gas_type == "bomb":
		target_base *= 1.2 # Slightly fuller bomb shell
	elif gas_type == "gold":
		target_base *= 0.9 # Nimble, shiny golden snitch-like balloon
	elif gas_type == "chroma":
		target_base *= 0.65 # Rare, small, agile rainbow mystery balloon
		
	# Subtle natural organic variation (+- 6%)
	var jitter = randf_range(0.94, 1.06)
	var final_s = clamp(target_base * jitter, 0.80, 5.0)
	base_scale_vec = Vector3(final_s, final_s, final_s)
	scale = base_scale_vec

# Thematic Color Palettes by Tier
static var tier_palettes: Dictionary = {
	1: [ # Classic Glossy Rubber
		Color("#ff4757"), # Candy Red
		Color("#2ed573"), # Vibrant Lime
		Color("#1e90ff"), # Sky Blue
		Color("#ffa502"), # Bright Amber
		Color("#9b59b6"), # Vivid Purple
		Color("#ff6b81"), # Bubblegum Pink
		Color("#00d2d3"), # Robin Egg Cyan
		Color("#ffd32a"), # Sunny Yellow
		Color("#ff5e57")  # Coral Pink
	],
	5: [ # Mirror Chrome & Metallic
		Color("#f1c40f"), # Polished Gold
		Color("#e0e0e0"), # Liquid Silver
		Color("#e67e22"), # Burnt Bronze
		Color("#e8a598"), # Rose Gold Chrome
		Color("#3498db")  # Metallic Cobalt
	],
	10: [ # Glowing Crystal Neon & Plasma
		Color("#00f0ff"), # Cyberpunk Cyan
		Color("#39ff14"), # Neon Acid Green
		Color("#bc13fe"), # Electric Violet
		Color("#ff3300"), # Solar Magma
		Color("#ffff00")  # Fluorescent Volt
	],
	50: [ # Cosmic Core & Hyper Energy
		Color("#ffaa00"), # Imperial Gold Obsidian
		Color("#8a2be2"), # Nebula Void Violet
		Color("#ff007f"), # Hyper Magenta Flame
		Color("#f0ffff")  # Quantum Supernova
	]
}

static var tier_health_table: Dictionary = {
	1: 1,
	5: 2,
	10: 3,
	50: 5
}

func setup_tier(t: int) -> void:
	tier = t
	tier_value = t
	max_health = tier_health_table.get(t, 1)
	current_health = max_health
	_apply_controlled_scale()
			
	if not custom_color_set:
		setup_random_color()
	else:
		_apply_cached_material()
		
	_apply_physics_profile()

func _apply_physics_profile() -> void:
	var prof = tier_physics_profiles.get(tier, tier_physics_profiles[1])
	mass = prof["mass"]
	physics_material_override = get_cached_physics_material(tier)
	
	var gas_grav_mult = 1.0
	var gas_damp_mult = 1.0
	if gas_type == "electric":
		gas_grav_mult = 0.55
		gas_damp_mult = 1.25
		mass = max(0.03, mass * 0.7)
	elif gas_type == "cryo":
		gas_grav_mult = 1.35
		gas_damp_mult = 0.85
		mass = mass * 1.45
		
	gravity_scale = current_room_gravity * prof["grav_mult"] * gas_grav_mult
	linear_damp = current_room_damp * prof["damp_mult"] * gas_damp_mult
	angular_damp = 2.4 * prof["damp_mult"]

func apply_room_physics(r_grav: float, r_damp: float) -> void:
	current_room_gravity = r_grav
	current_room_damp = r_damp
	_apply_physics_profile()

func apply_elastic_impact(impact_vector: Vector3) -> void:
	if is_popped or not mesh_instance:
		return
	if _elastic_tween and _elastic_tween.is_valid():
		_elastic_tween.kill()
		
	var base_scale = Vector3.ONE
	var intensity = clamp(impact_vector.length() / 14.0, 0.12, 0.42)
	
	var squashed_scale = Vector3(
		base_scale.x * (1.0 + intensity * 0.35),
		base_scale.y * (1.0 - intensity * 0.45),
		base_scale.z * (1.0 + intensity * 0.35)
	)
	
	_elastic_tween = create_tween()
	_elastic_tween.tween_property(mesh_instance, "scale", squashed_scale, 0.06).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	_elastic_tween.tween_property(mesh_instance, "scale", base_scale, 0.28).set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)

func wake_physics() -> void:
	if freeze:
		thaw_physics()
	else:
		sleeping = false

func freeze_pile() -> void:
	if not freeze and not is_popped:
		freeze = true
		freeze_mode = FREEZE_MODE_STATIC

func thaw_physics() -> void:
	if freeze and not is_popped:
		freeze = false
		sleeping = false

func set_balloon_color(col: Color) -> void:
	custom_color_set = true
	balloon_color = col
	_apply_cached_material()

func setup_random_color() -> void:
	var palette = tier_palettes.get(tier, tier_palettes[1])
	balloon_color = palette[randi() % palette.size()]
	_apply_cached_material()

static func get_cached_material(t: int, color: Color, gas: String = "normal") -> StandardMaterial3D:
	var key = str(t) + "_" + gas + "_" + color.to_html(false)
	if _material_cache.has(key):
		return _material_cache[key]
		
	var mat = StandardMaterial3D.new()
	mat.albedo_color = color
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_PER_PIXEL
	mat.clearcoat_enabled = true
	mat.clearcoat = 0.65
	mat.clearcoat_roughness = 0.18
	
	if gas == "bomb":
		mat.metallic = 0.85
		mat.roughness = 0.32
		mat.metallic_specular = 0.40
		mat.emission_enabled = true
		mat.emission = Color(1.0, 0.25, 0.05)
		mat.emission_energy_multiplier = 0.03
		mat.rim_enabled = true
		mat.rim = 0.65
		mat.rim_tint = 0.3
	elif gas == "gold":
		mat.metallic = 0.95
		mat.roughness = 0.08
		mat.metallic_specular = 0.98
		mat.emission_enabled = true
		mat.emission = Color(1.0, 0.78, 0.15)
		mat.emission_energy_multiplier = 0.15
		mat.rim_enabled = true
		mat.rim = 1.20
		mat.rim_tint = 0.7
	elif gas == "air":
		mat.metallic = 0.10
		mat.roughness = 0.05
		mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		mat.albedo_color = Color(color.r, color.g, color.b, 0.88)
		mat.emission_enabled = true
		mat.emission = Color(0.4, 0.9, 1.0)
		mat.emission_energy_multiplier = 0.12
		mat.rim_enabled = true
		mat.rim = 1.40
		mat.rim_tint = 0.8
	elif gas == "hydrogen":
		mat.metallic = 0.35
		mat.roughness = 0.14
		mat.emission_enabled = true
		mat.emission = Color(1.0, 0.35, 0.05)
		mat.emission_energy_multiplier = 1.45
		mat.rim_enabled = true
		mat.rim = 0.85
		mat.rim_tint = 0.4
	elif gas == "electric":
		mat.metallic = 0.25
		mat.roughness = 0.08
		mat.emission_enabled = true
		mat.emission = Color(0.12, 0.88, 1.0)
		mat.emission_energy_multiplier = 1.65
		mat.rim_enabled = true
		mat.rim = 1.15
		mat.rim_tint = 0.6
	elif gas == "cryo":
		mat.metallic = 0.15
		mat.roughness = 0.06
		mat.emission_enabled = true
		mat.emission = Color(0.35, 1.0, 0.75)
		mat.emission_energy_multiplier = 1.0
		mat.rim_enabled = true
		mat.rim = 0.80
	else:
		match t:
			5: # Tier 5: Mirror Chrome
				mat.metallic = 0.92
				mat.roughness = 0.12
				mat.metallic_specular = 0.90
				mat.rim_enabled = true
				mat.rim = 0.55
				mat.rim_tint = 0.3
			10: # Tier 10: Glowing Crystal Neon
				mat.metallic = 0.18
				mat.roughness = 0.08
				mat.metallic_specular = 0.70
				mat.emission_enabled = true
				mat.emission = color
				mat.emission_energy_multiplier = 0.22
				mat.rim_enabled = true
				mat.rim = 1.0
				mat.rim_tint = 0.5
			50: # Tier 50: Cosmic Core & Dual Clearcoat
				mat.metallic = 0.75
				mat.roughness = 0.04
				mat.metallic_specular = 0.95
				mat.emission_enabled = true
				mat.emission = color
				mat.emission_energy_multiplier = 0.35
				mat.clearcoat_enabled = true
				mat.clearcoat = 1.0
				mat.clearcoat_roughness = 0.06
				mat.rim_enabled = true
				mat.rim = 1.25
				mat.rim_tint = 0.6
			_: # Tier 1: Glossy Rubber with Fresnel Rim
				mat.metallic = 0.0
				mat.roughness = 0.22
				mat.metallic_specular = 0.50
				mat.rim_enabled = true
				mat.rim = 0.45
				mat.rim_tint = 0.4
			
	_material_cache[key] = mat
	return mat

static var _outline_pass: StandardMaterial3D = null

static func get_outline_pass() -> StandardMaterial3D:
	if _outline_pass != null:
		return _outline_pass
		
	_outline_pass = StandardMaterial3D.new()
	_outline_pass.cull_mode = BaseMaterial3D.CULL_FRONT
	_outline_pass.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_outline_pass.albedo_color = Color(1.0, 1.0, 1.0, 1.0) # Bright pure white silhouette
	_outline_pass.grow = true
	_outline_pass.grow_amount = 0.038 # 3.8cm distinct outline border
	return _outline_pass

static var _highlight_mat_cache: Dictionary = {}
static func get_highlight_material(t: int, color: Color, gas: String = "normal") -> StandardMaterial3D:
	var key = str(t) + "_" + gas + "_hl_" + color.to_html(false)
	if _highlight_mat_cache.has(key):
		return _highlight_mat_cache[key]
		
	var base_mat = get_cached_material(t, color, gas)
	var mat = base_mat.duplicate() as StandardMaterial3D
	mat.next_pass = get_outline_pass()
	
	_highlight_mat_cache[key] = mat
	return mat

func _apply_cached_material() -> void:
	if not mesh_instance:
		mesh_instance = get_node_or_null("MeshInstance3D")
	if not knot_mesh and mesh_instance:
		knot_mesh = mesh_instance.get_node_or_null("Knot")
		
	_update_special_detail()
	var mat = _chroma_mat if (gas_type == "chroma" and _chroma_mat) else get_cached_material(tier, balloon_color, gas_type)
	if mesh_instance:
		mesh_instance.material_override = mat
	if knot_mesh:
		knot_mesh.material_override = mat

func _update_special_detail() -> void:
	if not mesh_instance:
		return
	if gas_type not in ["bomb", "gold", "air", "electric", "cryo", "bonus_coin", "bonus_magnet"]:
		if is_instance_valid(_special_detail):
			_special_detail.hide()
		return
	if not is_instance_valid(_special_detail):
		_special_detail = MeshInstance3D.new()
		_special_detail.name = "GasSignature"
		_special_detail.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		mesh_instance.add_child(_special_detail)
	_special_detail.show()
	_special_detail.mesh = Design.get_special_mesh(gas_type)
	if gas_type.begins_with("bonus_") and not _special_detail.has_node("NeedleLabel"):
		var label := Label3D.new()
		label.name = "NeedleLabel"
		label.text = ("2× COIN · 10 sn" if gas_type == "bonus_coin" else "ÇEKİM · 10 sn") + "\nPATLAT"
		label.font_size = 32
		label.pixel_size = 0.003
		label.position.y = 0.65
		label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		_special_detail.add_child(label)
	var bonus_label = _special_detail.get_node_or_null("NeedleLabel")
	if bonus_label:
		bonus_label.visible = gas_type.begins_with("bonus_")
		bonus_label.text = ("2× COIN · 10 sn" if gas_type == "bonus_coin" else "ÇEKİM · 10 sn") + "\nPATLAT"
	if not _detail_materials.has(gas_type):
		var detail := StandardMaterial3D.new()
		detail.albedo_color = Color(1, 0.66, 0.14) if gas_type in ["bomb", "gold"] else Color(0.68, 0.96, 1)
		detail.metallic = 0.55
		detail.roughness = 0.28
		detail.emission_enabled = true
		detail.emission = detail.albedo_color
		detail.emission_energy_multiplier = 0.45
		_detail_materials[gas_type] = detail
	_special_detail.material_override = _detail_materials[gas_type]

func set_highlight(active: bool) -> void:
	if not mesh_instance or is_popped: return
	if not knot_mesh:
		knot_mesh = mesh_instance.get_node_or_null("Knot")
		
	if active:
		var hl_mat = get_highlight_material(tier, balloon_color, gas_type)
		mesh_instance.material_override = hl_mat
		if knot_mesh: knot_mesh.material_override = hl_mat
	else:
		_apply_cached_material()

static var _shockwave_query: PhysicsShapeQueryParameters3D = null
static var _shockwave_sphere: SphereShape3D = null

func _trigger_physics_shockwave(origin: Vector3, radius: float, force: float, pop_chain_limit: int = 0) -> void:
	var world = get_world_3d()
	if not world: return
	var space_state = world.direct_space_state
	if not space_state: return
	
	if _shockwave_sphere == null:
		_shockwave_sphere = SphereShape3D.new()
	if _shockwave_query == null:
		_shockwave_query = PhysicsShapeQueryParameters3D.new()
		_shockwave_query.shape = _shockwave_sphere
		_shockwave_query.collision_mask = 2 # Balloons layer
		_shockwave_query.collide_with_bodies = true
		_shockwave_query.collide_with_areas = false
		
	_shockwave_sphere.radius = radius
	_shockwave_query.transform = Transform3D(Basis(), origin)
	_shockwave_query.exclude = [get_rid()]
	
	var hits = space_state.intersect_shape(_shockwave_query, 36)
	var chain_popped = 0
	
	for hit in hits:
		var b = hit.collider
		if b is RigidBody3D and is_instance_valid(b) and not b.get("is_popped"):
			var diff = b.global_position - origin
			var dist = max(0.15, diff.length())
			var norm = diff.normalized()
			if norm.is_zero_approx():
				norm = Vector3(randf_range(-1, 1), randf_range(0.2, 1), randf_range(-1, 1)).normalized()
				
			var falloff = clamp(1.0 - (dist / radius), 0.15, 1.0)
			
			# If this is a bomb explosion: pop all balloons inside the lethal blast zone
			if pop_chain_limit > 0 and chain_popped < pop_chain_limit and dist <= radius:
				chain_popped += 1
				if b.has_method("take_hit"):
					# Larger tiers have multiple health points; a lethal bomb blast
					# must remove all remaining health instead of merely damaging them.
					b.call_deferred("take_hit", maxi(1, int(b.get("current_health"))), "bomb_explosion", 1)
					continue
					
			# Physical impulse scaled by target balloon mass for consistent, reliable displacement
			var target_mass = b.mass if ("mass" in b and b.mass > 0.0) else 0.1
			var impulse_mag = force * falloff * target_mass
			var impulse = (norm * impulse_mag) + Vector3(0.0, impulse_mag * 0.20, 0.0)
			b.apply_central_impulse(impulse)
			if b.has_method("apply_elastic_impact"):
				b.apply_elastic_impact(impulse * 0.35)

func can_pop(_source: String = "") -> bool:
	if is_popped: return false
	return true

func take_hit(damage: int = 1, trigger_source: String = "manual", combo_depth: int = 0) -> bool:
	if not can_pop(trigger_source):
		return false
	current_health -= damage
	if current_health <= 0:
		_execute_pop(trigger_source, combo_depth)
		return true
	else:
		_on_damaged(trigger_source)
		return false

func _on_damaged(trigger_source: String) -> void:
	# Elastic wobble hit response
	var hit_impulse = Vector3(randf_range(-2.0, 2.0), 3.0, randf_range(-2.0, 2.0))
	apply_central_impulse(hit_impulse)
	apply_elastic_impact(hit_impulse * 2.0)
	
	# Drop minor coin chip when damaging big tier balloons
	var main_node = get_node_or_null("/root/Main")
	if main_node and main_node.has_method("spawn_floor_coin"):
		main_node.spawn_floor_coin(global_position, 1, 1)
		
	# Play damage sound
	if main_node and main_node.sound_manager and main_node.sound_manager.has_method("play_pop"):
		main_node.sound_manager.play_pop(3)

func pop(trigger_source: String = "manual", combo_depth: int = 0) -> void:
	take_hit(1, trigger_source, combo_depth)

func _execute_pop(trigger_source: String = "manual", combo_depth: int = 0) -> void:
	is_popped = true
	last_pop_source = trigger_source
	if gas_type != "normal":
		var events = get_node_or_null("/root/Main/BonusController")
		if events: events.signal_special_pop()
	if gas_type.begins_with("bonus_"):
		var bonus = get_node_or_null("/root/Main/BonusController")
		if bonus: bonus.activate(gas_type)
	elif gas_type == "chroma":
		var bonus = get_node_or_null("/root/Main/BonusController")
		if bonus and bonus.has_method("activate_chroma"):
			bonus.activate_chroma()
	
	var pop_pos = global_position
	var pop_col = balloon_color
	var t_val = tier_value
	var g_type = gas_type
	var is_midair = false # Airborne coin premium retired; stacks are not bonus targets.
	
	popped.emit(self, pop_pos, pop_col, combo_depth, t_val, is_midair)
	
	# Execute type-specific shockwave physics & effects
	match g_type:
		"bomb":
			# Bomb Balloon: 3.2m lethal blast zone (pops all balloons within radius, up to 10), outer balloons get pushed
			_trigger_physics_shockwave(pop_pos, 3.2, 8.5, 10)
		"gold":
			# Gold Balloon: Subtle twinkle ripple
			_trigger_physics_shockwave(pop_pos, 2.0, 1.8, 0)
		_:
			# Standard Balloon: Skip expensive 3D physics queries to keep physics frame rate at solid 144 FPS
			pass
	
	# Hide visual and disable collision immediately
	if mesh_instance: mesh_instance.visible = false
	if knot_mesh: knot_mesh.visible = false
	if collision_shape: collision_shape.disabled = true
	freeze = true
	
	# Spawn visual rubber shreds with throttle cap
	if pop_particle_scene and _active_particle_count < 14:
		_active_particle_count += 1
		var particle = pop_particle_scene.instantiate()
		particle.position = get_parent().to_local(pop_pos)
		get_parent().add_child(particle)
		if particle.has_method("init"):
			particle.init(pop_col, t_val, g_type)
		particle.tree_exited.connect(func(): _active_particle_count = max(0, _active_particle_count - 1))
			
	queue_free()

# Refine the broad physics sphere against the cached visible surface. Only the
# currently aimed balloon pays this cost; physics keeps cheap spherical bodies.
func get_surface_hit(world_origin: Vector3, world_direction: Vector3) -> Dictionary:
	var local_origin := mesh_instance.to_local(world_origin)
	var local_direction := (mesh_instance.global_basis.inverse() * world_direction).normalized()
	# One shared native BVH replaces a GDScript loop over every body triangle.
	var hit: Dictionary = Design.balloon_surface.intersect_ray(local_origin, local_direction)
	if hit.is_empty(): return {}
	var normal: Vector3 = hit.normal
	if normal.dot(local_direction) > 0.0: normal = -normal
	return {"position": mesh_instance.to_global(hit.position), "normal": (mesh_instance.global_basis.inverse().transposed() * normal).normalized()}
