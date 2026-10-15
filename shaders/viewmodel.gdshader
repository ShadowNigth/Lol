shader_type spatial;
// Brazos y armas en primera persona. La profundidad se comprime hacia el
// plano cercano (válido para Z inversa en todos los renderizadores de Godot 4)
// para que nunca atraviesen paredes, conservando la oclusión propia.
// El campo de visión del arma es independiente del de la cámara.
render_mode cull_back, diffuse_burley, specular_schlick_ggx;

uniform float emission_energy = 3.0;
uniform float fov_scale = 1.0;
uniform float depth_scale = 0.05;
uniform vec4 flash_color : source_color = vec4(1.0, 1.0, 1.0, 0.0);

varying vec2 matp;

void vertex() {
	matp = UV2;
	vec4 view_pos = MODELVIEW_MATRIX * vec4(VERTEX, 1.0);
	mat4 proj = PROJECTION_MATRIX;
	proj[0][0] *= fov_scale;
	proj[1][1] *= fov_scale;
	vec4 clip = proj * view_pos;
	clip.z = clip.w - (clip.w - clip.z) * depth_scale;
	POSITION = clip;
}

void fragment() {
	vec3 c = COLOR.rgb;
	ALBEDO = mix(c, flash_color.rgb, flash_color.a);
	METALLIC = matp.x;
	ROUGHNESS = matp.y;
	SPECULAR = mix(0.3, 0.6, matp.x);
	EMISSION = c * COLOR.a * emission_energy;
}
