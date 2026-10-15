shader_type spatial;
// Terreno voxel opaco: texturas en Texture2DArray (capa en UV2.x) y
// oclusión ambiental + tinte de bioma en el color de vértice.
render_mode cull_back, diffuse_burley, specular_schlick_ggx;

uniform sampler2DArray block_textures : source_color, filter_nearest_mipmap_anisotropic, repeat_enable;
uniform float roughness_value = 0.92;

varying float tex_layer;

void vertex() {
	tex_layer = UV2.x;
}

void fragment() {
	vec4 tex = texture(block_textures, vec3(UV, tex_layer));
	ALBEDO = tex.rgb * COLOR.rgb;
	ROUGHNESS = roughness_value;
	SPECULAR = 0.25;
}
