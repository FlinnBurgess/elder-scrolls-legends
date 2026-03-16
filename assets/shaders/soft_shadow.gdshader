shader_type canvas_item;

uniform float blur_radius : hint_range(0.0, 0.5) = 0.15;
uniform float shadow_alpha : hint_range(0.0, 1.0) = 0.3;

void fragment() {
	// Distance from each edge in UV space (0 at edge, 0.5 at centre)
	float dx = min(UV.x, 1.0 - UV.x);
	float dy = min(UV.y, 1.0 - UV.y);
	// Normalise edge distance by blur_radius so the falloff zone is consistent
	float fx = smoothstep(0.0, blur_radius, dx);
	float fy = smoothstep(0.0, blur_radius, dy);
	float alpha = fx * fy * shadow_alpha;
	COLOR = vec4(0.0, 0.0, 0.0, alpha);
}
