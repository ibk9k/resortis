shader_type canvas_item;
render_mode unshaded;

uniform sampler2D terrain_atlas : filter_nearest, repeat_disable;
uniform float elapsed = 0.0;
uniform float motion = 1.0;
varying vec2 ground_position;

void vertex() {
	ground_position = VERTEX;
}

void fragment() {
	vec2 cell = vec2(ground_position.x / 64.0 + ground_position.y / 32.0,
		ground_position.y / 32.0 - ground_position.x / 64.0);
	float t = elapsed * motion;
	float coast = 39.7 + sin(cell.x * 0.24) * 0.32 + sin(cell.x * 0.87) * 0.13;
	float cycle = fract(t * 0.15);
	float edge = coast - sin(cycle * 3.14159) * 0.9;
	float distance = cell.y - edge;
	vec2 ripples = fract((cell + vec2(t * 0.07, -t * 0.04)) / 9.0);
	vec3 water = texture(terrain_atlas, vec2(0.5) + clamp(ripples, vec2(0.003), vec2(0.997)) * 0.5).rgb;
	float depth = clamp((cell.y - coast) / 10.0, 0.0, 1.0);
	water = mix(water * vec3(0.70, 0.98, 1.02), vec3(0.045, 0.35, 0.43), depth * 0.75);
	float foam_noise = sin(floor(cell.x * 11.0) * 3.0 + floor(cell.y * 13.0) * 5.0);
	float foam = (1.0 - smoothstep(0.06, 0.32 + foam_noise * 0.09, abs(distance - 0.14)));
	float second_wave = 1.0 - smoothstep(0.025, 0.09, abs(distance - 1.8 - sin(cell.x * 0.5 + t) * 0.07));
	water = mix(water, vec3(0.95, 0.99, 0.91), max(foam, second_wave * 0.35));
	float alpha = smoothstep(-0.10, 0.18, distance);
	COLOR = vec4(water, alpha);
}
