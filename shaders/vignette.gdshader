shader_type canvas_item;
// Viñeta roja de daño / salud baja.
uniform float intensity = 0.0;

void fragment() {
	vec2 uv = UV - 0.5;
	float d = length(uv * vec2(1.0, 0.8));
	float v = smoothstep(0.32, 0.75, d) * intensity;
	COLOR = vec4(0.55, 0.0, 0.0, v * 0.85);
}
