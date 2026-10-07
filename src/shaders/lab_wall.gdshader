shader_type spatial;
render_mode blend_mix, depth_draw_opaque, cull_back, diffuse_burley, specular_schlick_ggx;

// Authentic civil/materials testing laboratory wall
// Off-white matte plaster finish with subtle concrete skirting baseboard

uniform vec3 panel_color : source_color = vec3(0.92, 0.93, 0.92);
uniform vec3 seam_color : source_color = vec3(0.88, 0.89, 0.88);
uniform vec3 baseboard_color : source_color = vec3(0.68, 0.70, 0.69);
uniform vec3 accent_color : source_color = vec3(0.92, 0.93, 0.92);

uniform float panel_width = 4.0;
uniform float panel_height = 3.0;
uniform float seam_width = 0.005;
uniform float baseboard_height = 0.12;
uniform float roughness : hint_range(0.0, 1.0) = 0.85;
uniform float metallic : hint_range(0.0, 1.0) = 0.0;

varying vec3 world_pos;
varying vec3 world_normal;

void vertex() {
	world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	world_normal = normalize((MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz);
}

void fragment() {
	if (world_pos.y <= baseboard_height) {
		// Realistic concrete baseboard skirting with top shadow groove
		float groove = smoothstep(baseboard_height - 0.015, baseboard_height, world_pos.y);
		ALBEDO = mix(baseboard_color, baseboard_color * 0.75, groove);
		ROUGHNESS = 0.60;
		METALLIC = 0.05;
	} else {
		// Clean matte laboratory plaster wall
		ALBEDO = panel_color;
		ROUGHNESS = roughness;
		METALLIC = metallic;
		SPECULAR = 0.25;
	}
}
