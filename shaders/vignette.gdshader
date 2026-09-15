shader_type spatial;
// Viñeta de confort para VR.
// Se dibuja como un triángulo de pantalla completa por ojo; el oscurecimiento
// se calcula por ÁNGULO respecto al eje de visión de cada ojo, así queda
// centrado en ambos ojos aunque sus proyecciones sean asimétricas.
render_mode unshaded, depth_test_disabled, depth_draw_never, cull_disabled, blend_mix, fog_disabled;

uniform float intensity : hint_range(0.0, 1.0) = 0.0;   // 0 = sin viñeta
uniform float fade : hint_range(0.0, 1.0) = 0.0;        // fundido a negro (choques, transiciones)
uniform float inner_deg = 58.0;                         // ángulo donde empieza con intensidad 0
uniform float min_inner_deg = 24.0;                     // ángulo donde empieza con intensidad 1
uniform float softness_deg = 16.0;

varying vec3 view_ray;

void vertex() {
	vec2 ndc = VERTEX.xy * 2.0;
	POSITION = vec4(ndc, 0.5, 1.0);
	vec4 v = INV_PROJECTION_MATRIX * vec4(ndc, 0.5, 1.0);
	view_ray = v.xyz / v.w;
}

void fragment() {
	vec3 dir = normalize(view_ray);
	float angle = degrees(acos(clamp(-dir.z, -1.0, 1.0)));
	float start = mix(inner_deg, min_inner_deg, intensity);
	float dark = smoothstep(start, start + softness_deg, angle) * step(0.001, intensity);
	float alpha = max(dark * mix(0.0, 0.94, intensity * 1.6), fade);
	ALBEDO = vec3(0.0);
	ALPHA = clamp(alpha, 0.0, 1.0);
}
