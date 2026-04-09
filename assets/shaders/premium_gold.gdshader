shader_type canvas_item;

uniform float intensity : hint_range(0.0, 2.0) = 1.0;

// Animated gold shimmer for premium cards — sweeping highlight across the border.

float gold_shimmer(vec2 p, float t) {
	// Diagonal sweep highlight
	float sweep = sin((p.x + p.y) * 3.0 - t * 1.2) * 0.5 + 0.5;
	sweep = pow(sweep, 3.0); // sharpen the highlight band
	// Secondary slower counter-sweep
	float sweep2 = sin((p.x - p.y) * 2.0 + t * 0.7 + 2.0) * 0.5 + 0.5;
	sweep2 = pow(sweep2, 4.0);
	// Subtle sparkle
	float sparkle = sin(p.x * 12.0 + t * 2.0) * sin(p.y * 10.0 - t * 1.5);
	sparkle = max(0.0, sparkle) * 0.3;
	return sweep * 0.6 + sweep2 * 0.3 + sparkle;
}

void fragment() {
	vec2 uv = UV;
	float t = TIME;

	float shimmer = gold_shimmer(uv * 4.0, t);

	// Only render near the edges (border region)
	float edge_x = min(smoothstep(0.0, 0.08, uv.x), smoothstep(0.0, 0.08, 1.0 - uv.x));
	float edge_y = min(smoothstep(0.0, 0.06, uv.y), smoothstep(0.0, 0.06, 1.0 - uv.y));
	float interior_mask = edge_x * edge_y;
	float border_mask = 1.0 - interior_mask;

	// Gentle pulse
	float pulse = mix(0.85, 1.15, sin(t * 0.6) * 0.5 + 0.5);

	float alpha = clamp(shimmer * border_mask * intensity * pulse, 0.0, 0.7);

	// Rich gold color with slight warm variation
	vec3 gold = mix(vec3(0.85, 0.65, 0.15), vec3(1.0, 0.9, 0.5), shimmer);

	COLOR = vec4(gold, alpha);
}
