shader_type spatial;
// Agua translúcida con ondulación de textura y brillo especular.
render_mode cull_back, depth_draw_opaque, diffuse_burley, specular_schlick_ggx;

uniform sampler2DArray block_textures : source_color, filter_nearest_mipmap, repeat_enable;
uniform vec4 water_tint : source_color = vec4(0.55, 0.75, 1.0, 1.0);
uniform float opacity = 0.72;

varying float tex_layer;
varying vec3 world_pos;

void vertex() {
	tex_layer = UV2.x;
	world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	if (NORMAL.y > 0.5) {
		VERTEX.y += sin(TIME * 1.3 + world_pos.x * 0.6 + world_pos.z * 0.4) * 0.025 - 0.02;
	}
}

void fragment() {
	vec2 uv = world_pos.xz * 0.5 + vec2(TIME * 0.05, TIME * 0.03);
	vec2 uv2 = world_pos.xz * 0.37 - vec2(TIME * 0.04, -TIME * 0.02);
	vec4 a = texture(block_textures, vec3(uv, tex_layer));
	vec4 b = texture(block_textures, vec3(uv2, tex_layer));
	vec3 col = mix(a.rgb, b.rgb, 0.5) * water_tint.rgb;
	float fres = pow(1.0 - clamp(dot(NORMAL, VIEW), 0.0, 1.0), 3.0);
	ALBEDO = col;
	ALPHA = clamp(opacity + fres * 0.25, 0.0, 0.95);
	ROUGHNESS = 0.08;
	SPECULAR = 0.6;
	METALLIC = 0.0;
}
