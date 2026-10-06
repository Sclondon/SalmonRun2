// Salmon: tail wag + body bends for charge/grab poses, with a rim light so it pops.
shader_type spatial;
render_mode cull_disabled, specular_disabled;

#include "res://shaders/psx_common.gdshaderinc"

uniform float wag_phase = 0.0;
uniform float wag_amp = 0.12;
uniform float curl = 0.0;
uniform float bend = 0.0;
uniform float flash = 0.0;
// A whale swims with its tail going up and down, not from side to side: how far (metres at
// the flukes; 0 for a fish), and how long the body is from its middle to its tail (metres).
uniform float heave = 0.0;
uniform float body = 1.0;

void vertex() {
	float t = clamp((VERTEX.z + 0.5) / 1.8, 0.0, 1.0);
	VERTEX.x += sin(wag_phase - VERTEX.z * 2.5) * wag_amp * t * t * 1.6;
	if (heave > 0.0) {
		// a wave down the body, small at the head and growing to the flukes
		float along = clamp(VERTEX.z / body * 0.5 + 0.5, 0.0, 1.0);
		VERTEX.y += sin(wag_phase - VERTEX.z / body * 2.2) * heave * (0.12 + 0.88 * along * along);
	}
	float zz = VERTEX.z * VERTEX.z;
	VERTEX.y += curl * zz * 0.45;
	VERTEX.x += bend * zz * 0.45;
	POSITION = psx_snap(PROJECTION_MATRIX * MODELVIEW_MATRIX * vec4(VERTEX, 1.0), VIEWPORT_SIZE);
}

void fragment() {
	vec3 col = srgb_to_linear(COLOR.rgb);
	ALBEDO = col;
	ROUGHNESS = 0.7;
	float rim = pow(1.0 - clamp(dot(NORMAL, VIEW), 0.0, 1.0), 3.0);
	EMISSION = col * rim * 0.8 + vec3(1.0) * flash;
}
