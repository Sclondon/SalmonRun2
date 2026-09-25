// Flat-shaded, vertex-coloured low-poly material used by almost everything.
// Vertex colour alpha < 1 marks a glowing face (glow = 1 - alpha) that pulses with the beat.
shader_type spatial;
render_mode cull_disabled, specular_disabled;

#include "res://shaders/psx_common.gdshaderinc"

global uniform float beat_pulse;
uniform float glow_mult = 1.0;
uniform float wind = 0.0;

void vertex() {
	if (wind > 0.0) {
		vec3 wp = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
		float h = max(VERTEX.y, 0.0);
		VERTEX.x += sin(TIME * 1.3 + wp.x * 0.2 + wp.z * 0.15) * wind * h * 0.02;
		VERTEX.z += cos(TIME * 1.1 + wp.x * 0.13) * wind * h * 0.015;
	}
	POSITION = psx_snap(PROJECTION_MATRIX * MODELVIEW_MATRIX * vec4(VERTEX, 1.0), VIEWPORT_SIZE);
}

void fragment() {
	vec3 col = srgb_to_linear(COLOR.rgb);
	ALBEDO = col;
	ROUGHNESS = 1.0;
	float glow = COLOR.a < 0.995 ? 1.0 - COLOR.a : 0.0;
	EMISSION = col * glow * (0.8 + beat_pulse * 3.0) * glow_mult;
}
