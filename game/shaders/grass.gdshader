shader_type spatial;
render_mode cull_disabled, diffuse_lambert, specular_disabled;

// Grass tufts: vertex colour for albedo, swaying with the wind. Height in
// the tuft (VERTEX.y) scales the sway so roots stay put.
uniform float wind_strength = 0.12;
uniform float wind_speed = 1.6;

void vertex() {
	vec3 world = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	float sway = sin(TIME * wind_speed + world.x * 0.35 + world.z * 0.22) * wind_strength;
	VERTEX.x += sway * VERTEX.y;
	VERTEX.z += sway * 0.5 * VERTEX.y;
}

void fragment() {
	// Vertex colours are authored in sRGB.
	ALBEDO = pow(COLOR.rgb, vec3(2.2));
	ROUGHNESS = 1.0;
}
