// River water: flowing foam streaks, white-water on waterfalls, beat-reactive shimmer.
shader_type spatial;
render_mode cull_disabled, specular_schlick_ggx;

#include "res://shaders/psx_common.gdshaderinc"

global uniform float beat_pulse;
uniform vec4 deep_color : source_color = vec4(0.03, 0.30, 0.36, 1.0);
uniform vec4 shallow_color : source_color = vec4(0.16, 0.70, 0.64, 1.0);
uniform vec4 foam_color : source_color = vec4(0.92, 1.0, 0.96, 1.0);
uniform vec4 beat_color : source_color = vec4(0.25, 1.0, 0.8, 1.0);
uniform float flow = 0.6;

varying float v_steep;

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

float vnoise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash(i), hash(i + vec2(1.0, 0.0)), f.x),
			mix(hash(i + vec2(0.0, 1.0)), hash(i + vec2(1.0, 1.0)), f.x), f.y);
}

void vertex() {
	v_steep = 1.0 - clamp(NORMAL.y, 0.0, 1.0);
	float w = sin(UV.y * 0.45 - TIME * 4.0 + UV.x * 9.0) * 0.08 + sin(UV.y * 0.9 + TIME * 2.3) * 0.05;
	VERTEX.y += w * (1.0 - v_steep);
	POSITION = psx_snap(PROJECTION_MATRIX * MODELVIEW_MATRIX * vec4(VERTEX, 1.0), VIEWPORT_SIZE);
}

void fragment() {
	vec2 p = vec2(UV.x * 10.0, UV.y * 0.18 - TIME * flow * 3.0);
	float n = vnoise(p) * 0.6 + vnoise(p * 2.3 + 7.0) * 0.4;
	float edge = smoothstep(0.36, 0.5, abs(UV.x - 0.5));
	float foam = step(0.74 - edge * 0.35 - COLOR.r * 0.14, n);
	float fall = smoothstep(0.35, 0.6, v_steep);
	float streak = step(0.45, vnoise(vec2(UV.x * 40.0, UV.y * 0.5 - TIME * 12.0)));
	vec3 col = mix(deep_color.rgb, shallow_color.rgb, 0.3 + 0.7 * n);
	col = mix(col, foam_color.rgb, max(foam * 0.85, fall * (0.55 + 0.45 * streak)));
	float band = step(0.9, fract(UV.y * 0.04 - TIME * 0.6));
	ALBEDO = col;
	ALPHA = mix(0.8, 0.96, max(foam, fall));
	ROUGHNESS = 0.45;
	SPECULAR = 0.2;
	EMISSION = beat_color.rgb * beat_pulse * (0.12 + 0.5 * band + 0.3 * foam) + foam_color.rgb * fall * 0.15;
}
