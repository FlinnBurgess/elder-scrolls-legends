shader_type canvas_item;

uniform vec4 glow_color : source_color = vec4(0.95, 0.85, 0.4, 1.0);
uniform float pulse_speed : hint_range(0.5, 4.0) = 1.4;
uniform float glow_intensity : hint_range(0.0, 1.0) = 0.55;
uniform float corner_radius : hint_range(0.0, 0.5) = 0.06;
uniform vec2 padding_uv = vec2(0.063, 0.04);

void fragment() {
	vec2 inner_min = padding_uv;
	vec2 inner_max = vec2(1.0) - padding_uv;
	vec2 inner_half = (inner_max - inner_min) * 0.5;
	vec2 inner_center = (inner_min + inner_max) * 0.5;

	vec2 p = abs(UV - inner_center) - inner_half + vec2(corner_radius);
	float d = length(max(p, 0.0)) - corner_radius;

	float outer_fade = 1.0 - smoothstep(0.0, length(padding_uv), d);
	float inner_mask = smoothstep(-0.01, 0.005, d);
	float glow = outer_fade * inner_mask;

	// Dual-speed pulse for a mystical flicker
	float pulse = 0.7 + 0.2 * sin(TIME * pulse_speed) + 0.1 * sin(TIME * pulse_speed * 2.3);

	float alpha = glow * glow_intensity * pulse;
	COLOR = vec4(glow_color.rgb, alpha);
}
