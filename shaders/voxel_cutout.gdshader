shader_type spatial;
// Hojas, plantas, ventanas y antorchas: recorte alfa y balanceo por viento.
render_mode cull_disabled, diffuse_burley, specular_schlick_ggx;

uniform sampler2DArray block_textures : source_color, filter_nearest_mipmap_anisotropic, repeat_enable;
uniform float wind_strength = 0.045;
uniform float alpha_cut = 0.5;

varying float tex_layer;

void vertex() {
	tex_layer = UV2.x;
	vec3 world = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	// Solo se balancea la vegetación (normales hacia arriba) y las hojas.
	float sway = sin(TIME * 1.7 + world.x * 0.35 + world.z * 0.27) * 0.6 + sin(TIME * 2.9 + world.z * 0.5) * 0.4;
	float top_weight = (1.0 - UV.y);
	float is_plant = step(0.99, NORMAL.y) * step(0.001, top_weight);
	VERTEX.x += sway * wind_strength * (is_plant * top_weight * 1.6 + 0.25);
	VERTEX.z += sway * wind_strength * 0.6 * (is_plant * top_weight * 1.6 + 0.25);
}

void fragment() {
	vec4 tex = texture(block_textures, vec3(UV, tex_layer));
	if (tex.a < alpha_cut) {
		discard;
	}
	ALBEDO = tex.rgb * COLOR.rgb;
	ROUGHNESS = 0.85;
	SPECULAR = 0.2;
	// Las caras traseras de las plantas se iluminan como las delanteras.
	if (!FRONT_FACING) {
		NORMAL = -NORMAL;
	}
}
