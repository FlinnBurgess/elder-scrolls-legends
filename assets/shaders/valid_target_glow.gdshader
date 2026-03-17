shader_type canvas_item;

uniform vec4 glow_color : source_color = vec4(0.9, 0.92, 0.95, 1.0);
uniform float pulse_speed : hint_range(0.5, 4.0) = 1.8;
uniform float glow_intensity : hint_range(0.0, 1.0) = 0.4;
uniform float corner_radius : hint_range(0.0, 0.5) = 0.06;
// Padding ratio: how much of the ColorRect (in UV space) is padding beyond the card.
// e.g. if pad is 14px and total width is 221px, padding_x = 14.0 / 221.0 ≈ 0.063
uniform vec2 padding_uv = vec2(0.063, 0.04);

void fragment() {
	// Inner rect (the card boundary) in UV space
	vec2 inner_min = padding_uv;
	vec2 inner_max = vec2(1.0) - padding_uv;
	vec2 inner_half = (inner_max - inner_min) * 0.5;
	vec2 inner_center = (inner_min + inner_max) * 0.5;

	// Rounded-rect SDF relative to the inner card boundary
	vec2 p = abs(UV - inner_center) - inner_half + vec2(corner_radius);
	float d = length(max(p, 0.0)) - corner_radius;

	// d < 0 = inside card, d > 0 = outside card
	// Glow: visible outside the card, fading outward toward the ColorRect edge
	float outer_fade = 1.0 - smoothstep(0.0, length(padding_uv), d);
	float inner_mask = smoothstep(-0.01, 0.005, d);  // sharp cutoff at card edge
	float glow = outer_fade * inner_mask;

	// Subtle pulse
	float pulse = 0.75 + 0.25 * sin(TIME * pulse_speed);

	float alpha = glow * glow_intensity * pulse;
	COLOR = vec4(glow_color.rgb, alpha);
}
