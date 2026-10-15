shader_type sky;
// Cielo procedural: degradado según la hora, sol, luna, estrellas y nubes
// voxel (celdas cuadradas) que se desplazan lentamente.

uniform vec3 sky_top : source_color = vec3(0.25, 0.45, 0.8);
uniform vec3 sky_horizon : source_color = vec3(0.7, 0.8, 0.9);
uniform vec3 ground_color : source_color = vec3(0.3, 0.32, 0.3);
uniform vec3 sun_dir = vec3(0.0, 1.0, 0.0);
uniform vec3 sun_color : source_color = vec3(1.0, 0.95, 0.85);
uniform vec3 moon_dir = vec3(0.0, -1.0, 0.0);
uniform float star_amount = 0.0;
uniform float cloud_coverage = 0.45;
uniform vec3 cloud_color : source_color = vec3(1.0, 1.0, 1.0);
uniform vec3 cloud_shadow : source_color = vec3(0.7, 0.72, 0.78);
uniform vec2 cloud_offset = vec2(0.0, 0.0);

float hash12(vec2 p) {
	vec3 p3 = fract(vec3(p.xyx) * 0.1031);
	p3 += dot(p3, p3.yzx + 33.33);
	return fract((p3.x + p3.y) * p3.z);
}

float vnoise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	vec2 u = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash12(i), hash12(i + vec2(1.0, 0.0)), u.x), mix(hash12(i + vec2(0.0, 1.0)), hash12(i + vec2(1.0, 1.0)), u.x), u.y);
}

void sky() {
	vec3 dir = normalize(EYEDIR);
	float h = dir.y;
	vec3 col = mix(sky_horizon, sky_top, smoothstep(0.0, 0.55, h));
	col = mix(col, ground_color, smoothstep(0.0, -0.12, h));

	// Halo y disco solar
	float sd = dot(dir, normalize(sun_dir));
	col += sun_color * pow(max(sd, 0.0), 8.0) * 0.25;
	col += sun_color * smoothstep(0.9993, 0.9996, sd) * 6.0;
	// Luna (disco pixelado)
	float md = dot(dir, normalize(moon_dir));
	col += vec3(0.8, 0.85, 1.0) * smoothstep(0.9990, 0.9993, md) * 1.6 * (1.0 - smoothstep(0.0, 0.3, sun_dir.y));

	// Estrellas
	if (star_amount > 0.001 && h > 0.0) {
		vec2 sp = dir.xz / (h + 0.25) * 140.0;
		vec2 cell = floor(sp);
		float r = hash12(cell);
		float star = step(0.985, r) * smoothstep(0.6, 0.0, length(fract(sp) - 0.5));
		col += vec3(star) * star_amount * (0.6 + 0.4 * sin(TIME * 2.0 + r * 50.0));
	}

	// Nubes voxel en un plano alto
	if (h > 0.02) {
		vec2 p = dir.xz / h * 120.0 + cloud_offset;
		vec2 cell = floor(p / 9.0);
		float n = vnoise(cell * 0.18) * 0.65 + vnoise(cell * 0.55) * 0.35;
		float cloud = step(1.0 - cloud_coverage, n);
		// Sombreado: borde inferior más oscuro según la celda vecina
		float n2 = vnoise((cell + vec2(0.0, 1.0)) * 0.18) * 0.65 + vnoise((cell + vec2(0.0, 1.0)) * 0.55) * 0.35;
		vec3 cc = mix(cloud_shadow, cloud_color, step(1.0 - cloud_coverage, n2) * 0.5 + 0.5);
		float fade = smoothstep(0.02, 0.18, h);
		col = mix(col, cc, cloud * fade * 0.92);
	}
	COLOR = col;
}
