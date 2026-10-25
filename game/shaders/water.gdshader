shader_type spatial;
render_mode diffuse_lambert, specular_schlick_ggx;

// Simple stylised water: gentle waves, a deep-to-shallow tint, and a
// brighter rim at grazing angles.
uniform vec4 deep_color : source_color = vec4(0.12, 0.32, 0.42, 0.9);
uniform vec4 shallow_color : source_color = vec4(0.3, 0.55, 0.58, 0.85);
uniform float wave_height = 0.05;

void vertex() {
	vec3 world = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	VERTEX.y += sin(TIME * 1.3 + world.x * 0.9) * wave_height + cos(TIME * 1.1 + world.z * 0.7) * wave_height;
}

void fragment() {
	float rim = pow(1.0 - clamp(dot(NORMAL, VIEW), 0.0, 1.0), 3.0);
	float ripple = sin(UV.x * 40.0 + TIME * 2.0) * sin(UV.y * 36.0 - TIME * 1.7) * 0.5 + 0.5;
	vec3 color = mix(deep_color.rgb, shallow_color.rgb, ripple * 0.35 + rim * 0.6);
	ALBEDO = color;
	ALPHA = mix(deep_color.a, shallow_color.a, rim);
	ROUGHNESS = 0.15;
	METALLIC = 0.0;
}
