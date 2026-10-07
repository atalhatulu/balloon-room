extends RefCounted

# Two simple meshes instead of full-screen volumetric fog.
static func create(parent: Node3D, length: float, width: float, color: Color) -> MeshInstance3D:
	var beam := MeshInstance3D.new()
	var cone := CylinderMesh.new()
	cone.top_radius = 0.12
	cone.bottom_radius = width
	cone.height = length
	cone.radial_segments = 16
	cone.rings = 1
	beam.mesh = cone
	beam.rotation.x = PI / 2.0
	beam.position.z = -length * 0.5
	beam.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var shader := Shader.new()
	shader.code = """shader_type spatial;
render_mode unshaded, blend_add, depth_draw_never, cull_disabled, shadows_disabled;
uniform vec4 tint : source_color = vec4(0.8, 0.9, 1.0, 1.0);
void fragment() {
 float ends = smoothstep(0.0, 0.12, UV.y) * (1.0 - smoothstep(0.65, 1.0, UV.y));
 float soft_edge = pow(abs(dot(normalize(NORMAL), normalize(VIEW))), 1.5);
 ALBEDO = tint.rgb;
 ALPHA = ends * soft_edge * 0.045;
}
"""
	var material := ShaderMaterial.new()
	material.shader = shader
	material.set_shader_parameter("tint", color)
	beam.material_override = material
	parent.add_child(beam)
	return beam
