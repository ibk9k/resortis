shader_type canvas_item;
render_mode unshaded;

uniform sampler2D terrain_atlas : filter_nearest, repeat_disable;
uniform sampler2D wang_atlas : filter_linear, repeat_disable;
uniform bool wang_enabled = false;
uniform vec2 quadrant = vec2(0.0, 0.0);
uniform vec4 material_tint : source_color = vec4(1.0);
uniform float repeat_cells = 8.0;
varying vec2 ground_position;

void vertex() {
	ground_position = VERTEX;
}

uint edge_bit(ivec2 edge, uint axis) {
	uint value = uint(edge.x) * 0x9e3779b9u ^ uint(edge.y) * 0x85ebca6bu ^ axis;
	value = (value ^ (value >> 16u)) * 0x7feb352du;
	value = (value ^ (value >> 15u)) * 0x846ca68bu;
	return (value ^ (value >> 16u)) & 1u;
}

void fragment() {
	vec2 logical = vec2(ground_position.x / 64.0 + ground_position.y / 32.0,
		ground_position.y / 32.0 - ground_position.x / 64.0);
	if (wang_enabled) {
		vec2 point = (logical + 0.5) / 2.0;
		ivec2 cell = ivec2(floor(point));
		uint north = edge_bit(cell, 0u);
		uint east = edge_bit(cell + ivec2(1, 0), 1u);
		uint south = edge_bit(cell + ivec2(0, 1), 0u);
		uint west = edge_bit(cell, 1u);
		uint variant = north | (east << 1u) | (south << 2u) | (west << 3u);
		vec2 tile = vec2(float(variant % 4u), float(variant / 4u));
		vec2 uv = (tile * 164.0 + 2.5 + fract(point) * 159.0) / 656.0;
		COLOR = texture(wang_atlas, uv) * material_tint;
	} else {
		vec2 pattern = fract((logical + 0.5) / repeat_cells);
		vec2 uv = quadrant + clamp(pattern, vec2(0.002), vec2(0.998)) * 0.5;
		COLOR = texture(terrain_atlas, uv) * material_tint;
	}
}
