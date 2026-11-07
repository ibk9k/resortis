shader_type canvas_item;
// UVs are measured on the pool painting. The two surface polygons keep the
// caustics clear of the coping, waterfall rocks, and ladder.
uniform float elapsed = 0.0;
uniform bool waterfall = false;

void fragment() {
	vec4 art = texture(TEXTURE, UV);
	vec2 p = UV / TEXTURE_PIXEL_SIZE;
	float light;
	if (waterfall) {
		float thread = sin(p.x * 0.48 + sin(p.y * 0.07) * 1.7);
		float flow = sin(p.y * 0.20 - elapsed * 16.0 + thread * 2.1);
		light = pow(max(0.0, flow * 0.65 + thread * 0.35), 3.0) * 0.32;
	} else {
		float wave = sin(p.x * 0.053 + p.y * 0.10 - elapsed * 2.1);
		float refraction = sin(p.x * 0.034 - p.y * 0.13 + elapsed * 1.7 + wave * 1.3);
		float pulse = sin(length((p - vec2(891.0, 550.0)) * vec2(0.72, 1.2)) * 0.18 - elapsed * 5.5);
		vec3 refracted = texture(TEXTURE, UV + vec2(wave * 5.2, refraction * 3.2) * TEXTURE_PIXEL_SIZE).rgb;
		float water_sample = smoothstep(0.12, 0.34, refracted.b - refracted.r);
		art.rgb = mix(art.rgb, refracted, water_sample * 0.70);
		light = pow(max(0.0, wave * refraction), 3.0) * 0.16 + pulse * 0.05;
	}
	vec3 color = mix(art.rgb, vec3(0.71, 0.99, 1.0), max(light, 0.0));
	COLOR = vec4(color + min(light, 0.0), art.a);
}
