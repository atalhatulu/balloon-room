class_name ThemeController
extends Node

signal theme_changed(theme_id: String, theme_name: String)

var active_theme_id: String = "clean_lab"

# Cache node references
var _main: Node3D = null
var _floor_mat: ShaderMaterial = null
var _wall_mat: ShaderMaterial = null
var _ceiling_mat: StandardMaterial3D = null
var _pipe_mat: StandardMaterial3D = null
var _world_env: WorldEnvironment = null
var _dir_light: DirectionalLight3D = null
var _room_light: OmniLight3D = null

# UI references
var theme_modal: Control = null
var themes_grid: GridContainer = null
var btn_close: Button = null
var btn_random: Button = null
var player: CharacterBody3D = null
var sound_manager: Node = null

var _theme_card_nodes: Dictionary = {}

# Fixed authentic material testing laboratory theme matching reference photo
const THEMES: Dictionary = {
	"clean_lab": {
		"name": "Malzeme Test Laboratuvarı",
		"desc": "Gerçekçi endüstriyel deney ve malzeme test odası. Pürüzsüz epoksi zemin, mat beyaz sıva duvarlar, galvaniz sac havalandırma kanalları ve floresan aydınlatma.",
		"swatches": [Color(0.92, 0.93, 0.92), Color(0.835, 0.847, 0.835), Color(0.10, 0.32, 0.52)],
		"floor_base": Color(0.82, 0.84, 0.85),
		"floor_tile": Color(0.84, 0.86, 0.87),
		"floor_line": Color(0.68, 0.72, 0.74),
		"floor_dot": Color(0.80, 0.83, 0.84),
		"floor_roughness": 0.32,
		"floor_metallic": 0.04,
		"wall_panel": Color(0.91, 0.93, 0.93),
		"wall_seam": Color(0.84, 0.87, 0.88),
		"wall_baseboard": Color(0.58, 0.62, 0.65),
		"wall_accent": Color(0.88, 0.92, 0.93),
		"wall_roughness": 0.82,
		"wall_metallic": 0.0,
		"ceiling_color": Color(0.94, 0.96, 0.97),
		"sky_top": Color(0.55, 0.72, 0.92),
		"sky_horizon": Color(0.82, 0.88, 0.94),
		"ambient_color": Color.WHITE,
		"ambient_energy": 0.42,
		"sun_color": Color.WHITE,
		"sun_energy": 0.85,
		"room_light_color": Color.WHITE,
		"room_light_energy": 1.75,
		"glow_intensity": 0.08,
		"pipe_color": Color(0.08, 0.65, 0.22),
		"pipe_roughness": 0.22,
		"pipe_metallic": 0.15,
		"pipe_rim": 0.60,
		"pipe_clearcoat": 0.45
	}
}

func setup(main_node: Node3D) -> void:
	_main = main_node
	_world_env = main_node.get_node_or_null("WorldEnvironment")
	_dir_light = main_node.get_node_or_null("DirectionalLight3D")
	_room_light = main_node.get_node_or_null("MainRoomLight")
	
	if _dir_light:
		_dir_light.shadow_enabled = false
	
	var floor_body = main_node.get_node_or_null("Environment/MainRoom/Floor/MeshInstance3D")
	if floor_body and floor_body.material_override is ShaderMaterial:
		_floor_mat = floor_body.material_override
		
	var wall_north = main_node.get_node_or_null("Environment/MainRoom/WallNorth/MeshInstance3D")
	if wall_north and wall_north.material_override is ShaderMaterial:
		_wall_mat = wall_north.material_override
		
	var ceil_body = main_node.get_node_or_null("Environment/MainRoom/Ceiling/MeshInstance3D")
	if ceil_body and ceil_body.material_override is StandardMaterial3D:
		_ceiling_mat = ceil_body.material_override
		
	var vents_container = main_node.get_node_or_null("Environment/MainRoom/CeilingVents")
	if vents_container:
		for v in vents_container.get_children():
			var shaft = v.get_node_or_null("Shaft")
			if shaft and shaft.material_override is StandardMaterial3D:
				_pipe_mat = shaft.material_override
				break
				
	theme_modal = main_node.get_node_or_null("UI/ThemeModal")
	if theme_modal:
		theme_modal.visible = false
		
	player = main_node.get_node_or_null("Player")
	sound_manager = main_node.get_node_or_null("SoundManager")
	
	apply_theme("clean_lab")

func toggle_theme_modal() -> void:
	# Themes are removed; fixed to authentic material testing lab
	if theme_modal:
		theme_modal.visible = false
	apply_theme("clean_lab")

func apply_random_theme() -> void:
	apply_theme("clean_lab")

func apply_theme(theme_id: String) -> void:
	# Locked permanently to clean_lab
	theme_id = "clean_lab"
	active_theme_id = "clean_lab"
	var t = THEMES["clean_lab"]
	
	# 1. Update Floor Shader Parameters
	if _floor_mat:
		_floor_mat.set_shader_parameter("base_color", t["floor_base"])
		_floor_mat.set_shader_parameter("tile_color", t["floor_tile"])
		_floor_mat.set_shader_parameter("line_color", t["floor_line"])
		_floor_mat.set_shader_parameter("dot_color", t["floor_dot"])
		_floor_mat.set_shader_parameter("roughness", t["floor_roughness"])
		_floor_mat.set_shader_parameter("metallic", t["floor_metallic"])
		
	# 2. Update Wall Shader Parameters
	if _wall_mat:
		_wall_mat.set_shader_parameter("panel_color", t["wall_panel"])
		_wall_mat.set_shader_parameter("seam_color", t["wall_seam"])
		_wall_mat.set_shader_parameter("baseboard_color", t["wall_baseboard"])
		_wall_mat.set_shader_parameter("accent_color", t["wall_accent"])
		_wall_mat.set_shader_parameter("roughness", t["wall_roughness"])
		_wall_mat.set_shader_parameter("metallic", t["wall_metallic"])
		
	# 3. Update Ceiling
	if _ceiling_mat:
		_ceiling_mat.albedo_color = t["ceiling_color"]
		_ceiling_mat.roughness = 0.85
		
	# 4. Update Directional Sun Light & Shadows
	if _dir_light:
		_dir_light.light_color = t["sun_color"]
		_dir_light.light_energy = float(t["sun_energy"]) * 0.65
		_dir_light.shadow_enabled = false
		
	# 5. Update Center Room Light
	if _room_light:
		_room_light.light_color = t["room_light_color"]
		_room_light.light_energy = t["room_light_energy"]
		
	# 6. Update World Environment & Sky
	if _world_env and _world_env.environment:
		var env = _world_env.environment
		env.ambient_light_color = t["ambient_color"]
		env.ambient_light_energy = minf(float(t["ambient_energy"]), 0.18)
		env.glow_enabled = true
		env.glow_intensity = t["glow_intensity"]
		env.glow_bloom = 0.06
		env.ssao_enabled = false
		env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
		env.tonemap_exposure = 1.05
		env.volumetric_fog_enabled = false
		env.volumetric_fog_density = 0.008
		env.volumetric_fog_albedo = Color(0.85, 0.90, 0.98)
		env.volumetric_fog_emission = Color(0.12, 0.15, 0.20)
		env.volumetric_fog_emission_energy = 0.25
		
		if env.sky and env.sky.sky_material is ProceduralSkyMaterial:
			var sky_mat = env.sky.sky_material as ProceduralSkyMaterial
			sky_mat.sky_top_color = t["sky_top"]
			sky_mat.sky_horizon_color = t["sky_horizon"]
			
	# 7. Update Duct / Pipe Materials
	if _pipe_mat:
		_pipe_mat.albedo_color = t["pipe_color"]
		_pipe_mat.roughness = t["pipe_roughness"]
		_pipe_mat.metallic = t["pipe_metallic"]
		_pipe_mat.rim = t["pipe_rim"]
		_pipe_mat.clearcoat = t["pipe_clearcoat"]
		
	theme_changed.emit("clean_lab", t["name"])

func cycle_next_theme() -> String:
	apply_theme("clean_lab")
	return "clean_lab"
