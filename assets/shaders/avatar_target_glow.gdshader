shader_type canvas_item;

uniform vec4 glow_color : source_color = vec4(0.9, 0.92, 0.95, 1.0);
uniform float pulse_speed : hint_range(0.5, 4.0) = 1.8;
uniform float glow_intensity : hint_range(0.0, 1.0) = 0.35;
uniform float edge_softness : hint_range(0.05, 0.5) = 0.2;
uniform float corner_radius : hint_range(0.0, 0.5) = 0.35;

void fragment() {
	// Rounded-rectangle SDF in UV space
	vec2 half_size = vec2(0.5);
	vec2 p = abs(UV - half_size) - half_size + vec2(corner_radius);
	float d = length(max(p, 0.0)) - corner_radius;

	// Soft glow falloff from the edge inward
	float glow = smoothstep(0.0, -edge_softness, d);

	// Subtle pulse
	float pulse = 0.8 + 0.2 * sin(TIME * pulse_speed);

	float alpha = glow * glow_intensity * pulse;
	COLOR = vec4(glow_color.rgb, alpha);
}
