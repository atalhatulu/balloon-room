shader_type spatial;
render_mode blend_mix, depth_draw_opaque, cull_back, diffuse_burley, specular_schlick_ggx;

// Authentic laboratory floor matching reference photo:
// Smooth industrial light grey concrete/epoxy floor with subtle expansion joints

uniform vec3 base_color : source_color = vec3(0.835, 0.847, 0.835);
uniform vec3 tile_color : source_color = vec3(0.85, 0.86, 0.85);
uniform vec3 line_color : source_color = vec3(0.72, 0.74, 0.73);
uniform vec3 dot_color : source_color = vec3(0.835, 0.847, 0.835);

uniform float grid_size = 4.0;
uniform float line_thickness = 0.005;
uniform float roughness : hint_range(0.0, 1.0) = 0.38;
uniform float metallic : hint_range(0.0, 1.0) = 0.02;

varying vec3 world_pos;

void vertex() {
	world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	vec2 pos = world_pos.xz / grid_size;
	
	// Very subtle industrial concrete expansion slab joints (4m slabs)
	vec2 grid = abs(fract(pos - 0.5) - 0.5) / (fwidth(pos) + vec2(0.0001));
	float line = min(grid.x, grid.y);
	float joint_factor = clamp(1.0 - line * (1.0 - line_thickness * 20.0), 0.0, 1.0);
	
	vec3 final_color = mix(base_color, line_color, joint_factor * 0.6);
	
	ALBEDO = final_color;
	ROUGHNESS = roughness;
	METALLIC = metallic;
	SPECULAR = 0.45;
}
