shader_type spatial;

uniform vec3 sand_color_a : source_color = vec3(0.82, 0.71, 0.50);
uniform vec3 sand_color_b : source_color = vec3(0.75, 0.63, 0.42);
uniform vec3 grid_color : source_color = vec3(0.65, 0.54, 0.36);

varying vec3 world_pos;

void vertex() {
	world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	// Subtle dune ripples + tactical reference grid for speed/altitude perception
	float ripple = sin(world_pos.x * 0.15 + sin(world_pos.z * 0.08) * 2.0) * 0.5 + 0.5;
	vec3 base = mix(sand_color_a, sand_color_b, ripple * 0.6);

	vec2 grid = abs(fract(world_pos.xz / 25.0 - 0.5) - 0.5) / fwidth(world_pos.xz / 25.0);
	float line = 1.0 - min(min(grid.x, grid.y), 1.0);
	ALBEDO = mix(base, grid_color, line * 0.25);
	ROUGHNESS = 0.92;
}
