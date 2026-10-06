// Flat-shaded, vertex-coloured low-poly material used by almost everything.
// Vertex colour alpha < 1 marks a glowing face (glow = 1 - alpha) that pulses with the beat.
shader_type spatial;
render_mode cull_disabled, specular_disabled;

#include "res://shaders/psx_common.gdshaderinc"

global uniform float beat_pulse;
uniform float glow_mult = 1.0;
uniform float wind = 0.0;
// What is far off comes up over the horizon, as on a round world: beyond horizon_from metres
// from the eye it stands lower and lower, and at horizon_to it is horizon_drop metres down,
// out of sight under the sea. (0 drop is a flat world: only far-off scenery has any.)
// Needles (pines): the boughs are drawn in sprigs, rows of pale and dark chevrons going round
// the tree, in place of plain flat green. (0 is plain.)
uniform float needles = 0.0;
varying vec3 v_local;
uniform float horizon_drop = 0.0;
uniform float horizon_from = 140.0;
uniform float horizon_to = 900.0;

void vertex() {
	v_local = VERTEX;
	if (wind > 0.0) {
		vec3 wp = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
		float h = max(VERTEX.y, 0.0);
		VERTEX.x += sin(TIME * 1.3 + wp.x * 0.2 + wp.z * 0.15) * wind * h * 0.02;
		VERTEX.z += cos(TIME * 1.1 + wp.x * 0.13) * wind * h * 0.015;
	}
	if (horizon_drop > 0.0) {
		vec3 at = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
		float away = clamp((length(at.xz - CAMERA_POSITION_WORLD.xz) - horizon_from) / (horizon_to - horizon_from), 0.0, 1.0);
		at.y -= away * away * horizon_drop;
		VERTEX = (inverse(MODEL_MATRIX) * vec4(at, 1.0)).xyz;
	}
	POSITION = psx_snap(PROJECTION_MATRIX * MODELVIEW_MATRIX * vec4(VERTEX, 1.0), VIEWPORT_SIZE);
}

void fragment() {
	vec3 col = srgb_to_linear(COLOR.rgb);
	if (needles > 0.0) {
		float round_it = atan(v_local.x, v_local.z);
		float sprig = fract(round_it * 7.0 / 3.14159);
		// (each row of sprigs droops from its middle: a chevron)
		float row = fract(v_local.y * 1.5 + abs(sprig - 0.5) * 1.1);
		col *= mix(1.0, mix(0.7, 1.16, step(0.45, row)) * mix(0.92, 1.05, step(0.5, sprig)), needles);
	}
	ALBEDO = col;
	ROUGHNESS = 1.0;
	float glow = COLOR.a < 0.995 ? 1.0 - COLOR.a : 0.0;
	EMISSION = col * glow * (0.8 + beat_pulse * 3.0) * glow_mult;
}
