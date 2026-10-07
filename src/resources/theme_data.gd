class_name ThemeData
extends Resource

@export var theme_id: String = "clean_lab"
@export var theme_name: String = "Klinik Beyaz Laboratuvar"
@export_multiline var description: String = ""
@export var swatches: Array[Color] = []

# Floor & Wall Colors
@export var floor_base: Color = Color(0.86, 0.89, 0.93)
@export var floor_tile: Color = Color(0.92, 0.94, 0.97)
@export var floor_line: Color = Color(0.65, 0.72, 0.80)
@export var floor_dot: Color = Color(0.10, 0.60, 0.95)
@export var floor_roughness: float = 0.22
@export var floor_metallic: float = 0.05

@export var wall_panel: Color = Color(0.88, 0.91, 0.95)
@export var wall_seam: Color = Color(0.55, 0.62, 0.70)
@export var wall_baseboard: Color = Color(0.18, 0.20, 0.25)
@export var wall_accent: Color = Color(0.10, 0.65, 0.95)
@export var wall_roughness: float = 0.35
@export var wall_metallic: float = 0.08

# Lighting & Pipes
@export var ceiling_color: Color = Color(0.16, 0.18, 0.22)
@export var sun_color: Color = Color(1.0, 0.98, 0.94)
@export var sun_energy: float = 1.10
@export var room_light_color: Color = Color(0.92, 0.96, 1.0)
@export var room_light_energy: float = 2.2
@export var pipe_color: Color = Color(0.08, 0.65, 0.22)
@export var pipe_roughness: float = 0.22
@export var pipe_metallic: float = 0.15
@export var pipe_rim: float = 0.60
@export var pipe_clearcoat: float = 0.45
