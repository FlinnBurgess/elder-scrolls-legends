shader_type canvas_item;

uniform float elapsed_time = 0.0;
uniform float scroll_speed_1 : hint_range(0.01, 0.5) = 0.08;
uniform float scroll_speed_2 : hint_range(0.01, 0.5) = 0.05;
uniform vec4 mist_color : source_color = vec4(0.45, 0.72, 0.95, 1.0);
uniform float intensity : hint_range(0.0, 2.0) = 1.2;
uniform float noise_scale_1 : hint_range(1.0, 20.0) = 6.0;
uniform float noise_scale_2 : hint_range(1.0, 20.0) = 4.0;
uniform float vertical_fade_power : hint_range(0.5, 4.0) = 1.2;

// Simple hash-based noise (no texture dependency)
float hash(vec2 p) {
	vec3 p3 = fract(vec3(p.xyx) * 0.1031);
	p3 += dot(p3, p3.yzx + 33.33);
	return fract((p3.x + p3.y) * p3.z);
}

float value_noise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f); // smoothstep
	float a = hash(i);
	float b = hash(i + vec2(1.0, 0.0));
	float c = hash(i + vec2(0.0, 1.0));
	float d = hash(i + vec2(1.0, 1.0));
	return mix(mix(a, b, f.x), mix(c, d, f.x), f.y);
}

float fbm(vec2 p) {
	float val = 0.0;
	float amp = 0.5;
	for (int i = 0; i < 4; i++) {
		val += amp * value_noise(p);
		p *= 2.0;
		amp *= 0.5;
	}
	return val;
}

void fragment() {
	vec2 uv = UV;

	// Two noise layers scrolling in different directions
	float n1 = fbm(uv * noise_scale_1 + vec2(elapsed_time * scroll_speed_1, elapsed_time * scroll_speed_1 * 0.7));
	float n2 = fbm(uv * noise_scale_2 + vec2(-elapsed_time * scroll_speed_2 * 0.8, elapsed_time * scroll_speed_2));

	// Blend noise layers for swirling mist
	float mist = (n1 + n2) * 0.5;

	// Vertical fade: strongest at top, fading out toward bottom
	float fade = pow(1.0 - uv.y, vertical_fade_power);

	// Horizontal edge fade to avoid hard edges on sides
	float edge_fade = smoothstep(0.0, 0.12, uv.x) * smoothstep(0.0, 0.12, 1.0 - uv.x);

	float alpha = clamp(mist * fade * edge_fade * intensity, 0.0, 1.0);

	COLOR = vec4(mist_color.rgb, alpha);
}
