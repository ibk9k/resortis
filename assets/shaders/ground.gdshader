shader_type canvas_item;
render_mode unshaded;

uniform sampler2D terrain_atlas : filter_nearest, repeat_disable;
uniform vec2 quadrant = vec2(0.0, 0.0);
uniform vec4 material_tint : source_color = vec4(1.0);
uniform float repeat_cells = 8.0;
varying vec2 ground_position;

void vertex() {
	ground_position = VERTEX;
}

void fragment() {
	vec2 logical = vec2(ground_position.x / 64.0 + ground_position.y / 32.0,
		ground_position.y / 32.0 - ground_position.x / 64.0);
	vec2 pattern = fract((logical + 0.5) / repeat_cells);
	vec2 uv = quadrant + clamp(pattern, vec2(0.002), vec2(0.998)) * 0.5;
	COLOR = texture(terrain_atlas, uv) * material_tint;
}
