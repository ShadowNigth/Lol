shader_type spatial;
// Llama procedural en billboard (antorchas, fraguas, braseros).
render_mode blend_add, unshaded, cull_disabled, depth_draw_never, shadows_disabled;

uniform vec4 core_color : source_color = vec4(1.0, 0.9, 0.5, 1.0);
uniform vec4 edge_color : source_color = vec4(1.0, 0.35, 0.05, 1.0);
uniform float intensity = 2.2;

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

float noise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	vec2 u = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash(i), hash(i + vec2(1.0, 0.0)), u.x), mix(hash(i + vec2(0.0, 1.0)), hash(i + vec2(1.0, 1.0)), u.x), u.y);
}

void vertex() {
	// Billboard esférico
	MODELVIEW_MATRIX = VIEW_MATRIX * mat4(INV_VIEW_MATRIX[0], INV_VIEW_MATRIX[1], INV_VIEW_MATRIX[2], MODEL_MATRIX[3]);
}

void fragment() {
	float seed = NODE_POSITION_WORLD.x * 3.1 + NODE_POSITION_WORLD.z * 1.7;
	vec2 uv = UV;
	// Pixelado para encajar con la estética voxel
	uv = floor(uv * 12.0) / 12.0;
	float t = TIME * 3.0 + seed;
	float n = noise(vec2(uv.x * 5.0, uv.y * 4.0 + t)) * 0.6 + noise(vec2(uv.x * 9.0, uv.y * 8.0 + t * 1.7)) * 0.4;
	float h = 1.0 - uv.y;
	float width = (1.0 - h) * 0.45 + 0.05;
	float d = abs(uv.x - 0.5);
	float shape = smoothstep(width, width - 0.18, d) * smoothstep(1.0, 0.25, h + n * 0.35);
	vec3 col = mix(edge_color.rgb, core_color.rgb, smoothstep(0.2, 0.8, shape));
	ALBEDO = col * shape * intensity;
	ALPHA = shape;
}
