shader_type spatial;
// Modelos de micro-vóxeles (personajes, criaturas, objetos).
// COLOR.rgb = albedo con AO; COLOR.a = emisión; UV2 = (metálico, rugosidad).
render_mode cull_back, diffuse_burley, specular_schlick_ggx;

uniform float emission_energy = 3.0;
uniform vec4 flash_color : source_color = vec4(1.0, 1.0, 1.0, 0.0);
uniform float dissolve = 0.0;

varying vec2 matp;
varying vec3 obj_pos;

float hash13(vec3 p) {
	p = fract(p * 0.1031);
	p += dot(p, p.zyx + 31.32);
	return fract((p.x + p.y) * p.z);
}

void vertex() {
	matp = UV2;
	obj_pos = VERTEX;
}

void fragment() {
	if (dissolve > 0.0 && hash13(floor(obj_pos * 24.0)) < dissolve) {
		discard;
	}
	vec3 c = COLOR.rgb;
	ALBEDO = mix(c, flash_color.rgb, flash_color.a);
	METALLIC = matp.x;
	ROUGHNESS = matp.y;
	SPECULAR = mix(0.3, 0.6, matp.x);
	EMISSION = c * COLOR.a * emission_energy + flash_color.rgb * flash_color.a * 0.5;
}
