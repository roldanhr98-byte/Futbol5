shader_type spatial;
// Balon procedural: parches oscuros sobre los 12 vertices de un icosaedro
// (patron de pentagonos). Sin texturas: coste minimo en gama baja.

uniform vec3 base_color : source_color = vec3(0.96, 0.96, 0.93);
uniform vec3 patch_color : source_color = vec3(0.07, 0.07, 0.10);
uniform float patch_threshold = 0.90;

varying vec3 local_n;

const vec3 DIRS[12] = vec3[12](
	vec3(0.0, 0.5257, 0.8507), vec3(0.0, 0.5257, -0.8507),
	vec3(0.0, -0.5257, 0.8507), vec3(0.0, -0.5257, -0.8507),
	vec3(0.5257, 0.8507, 0.0), vec3(0.5257, -0.8507, 0.0),
	vec3(-0.5257, 0.8507, 0.0), vec3(-0.5257, -0.8507, 0.0),
	vec3(0.8507, 0.0, 0.5257), vec3(0.8507, 0.0, -0.5257),
	vec3(-0.8507, 0.0, 0.5257), vec3(-0.8507, 0.0, -0.5257)
);

void vertex() {
	local_n = normalize(VERTEX);
}

void fragment() {
	float m = -1.0;
	for (int i = 0; i < 12; i++) {
		m = max(m, dot(local_n, DIRS[i]));
	}
	float p = smoothstep(patch_threshold - 0.01, patch_threshold + 0.01, m);
	ALBEDO = mix(base_color, patch_color, p);
	ROUGHNESS = 0.55;
	SPECULAR = 0.35;
}
