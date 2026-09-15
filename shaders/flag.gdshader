shader_type spatial;
// Bandera ondeando. UV.x = 0 en el asta, 1 en la punta.
render_mode cull_disabled, specular_disabled, vertex_lighting;

uniform float amplitude = 0.11;
uniform float speed = 3.2;

void vertex() {
	float along = UV.x;
	float phase = VERTEX.x * 2.3 + VERTEX.z * 0.05;
	VERTEX.z += sin(phase - TIME * speed) * amplitude * along;
	VERTEX.y -= along * along * 0.05;
}

void fragment() {
	ALBEDO = COLOR.rgb;
	ROUGHNESS = 1.0;
}
