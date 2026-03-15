shader_type canvas_item;

uniform vec4 mist_color : source_color = vec4(0.45, 0.72, 0.95, 1.0);
uniform float intensity : hint_range(0.0, 2.0) = 1.0;
uniform float vertical_fade_power : hint_range(0.5, 4.0) = 1.2;

// Animated ward shimmer using layered sine waves for reliable, visible motion.
// TIME is used directly; the parent script calls queue_redraw() each frame
// to ensure the canvas item is not stale-cached.

float ward_noise(vec2 p, float t) {
	// Layer 1: slow diagonal drift
	float n1 = sin(p.x * 3.0 + p.y * 2.0 + t * 0.8) * 0.5 + 0.5;
	// Layer 2: opposite drift, different frequency
	float n2 = sin(p.x * -2.5 + p.y * 3.5 + t * -0.6 + 1.7) * 0.5 + 0.5;
	// Layer 3: faster vertical shimmer
	float n3 = sin(p.y * 5.0 + p.x * 1.5 + t * 1.3 + 3.1) * 0.5 + 0.5;
	// Layer 4: slow large-scale pulse
	float n4 = sin(p.x * 1.2 + p.y * 0.8 + t * 0.4 + 5.0) * 0.5 + 0.5;
	return (n1 + n2 + n3 + n4) * 0.25;
}

void fragment() {
	vec2 uv = UV;
	float t = TIME;

	float mist = ward_noise(uv * 4.0, t);

	// Vertical fade: strongest at top, fading toward bottom
	float fade = pow(1.0 - uv.y, vertical_fade_power);

	// Horizontal edge fade to avoid hard edges on sides
	float edge_fade = smoothstep(0.0, 0.12, uv.x) * smoothstep(0.0, 0.12, 1.0 - uv.x);

	// Bottom edge fade too
	float bottom_fade = smoothstep(0.0, 0.08, 1.0 - uv.y);

	float alpha = clamp(mist * fade * edge_fade * bottom_fade * intensity, 0.0, 0.65);

	COLOR = vec4(mist_color.rgb, alpha);
}
