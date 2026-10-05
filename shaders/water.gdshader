// Toon water. Its colour goes from shallow to deep with how much water there really is under
// each pixel, a rim of foam forms wherever something breaks the surface (banks, rocks, ramps,
// the fish), patches of foam drift with the current, waterfalls turn to white water, and the
// whole thing shimmers on the beat.
//
// Every stage can set any of these from its entry in levels.gd: a key "water_<name>" sets the
// uniform <name>.
shader_type spatial;
render_mode cull_disabled, specular_schlick_ggx;

#include "res://shaders/psx_common.gdshaderinc"

global uniform float beat_pulse;

group_uniforms colour;
uniform vec4 deep : source_color = vec4(0.03, 0.30, 0.36, 1.0);
uniform vec4 shallow : source_color = vec4(0.16, 0.70, 0.64, 1.0);
uniform vec4 foam_color : source_color = vec4(0.92, 1.0, 0.96, 1.0);
uniform vec4 beat : source_color = vec4(0.25, 1.0, 0.8, 1.0);
// Metres of water before it reaches its deep colour.
uniform float depth_range = 5.0;
// How solid the water looks where it is shallow and where it is deep (1 hides what is under it).
uniform float alpha_shallow : hint_range(0.0, 1.0) = 0.6;
uniform float alpha_deep : hint_range(0.0, 1.0) = 0.93;
// How much the surface colour varies in ripples.
uniform float ripple : hint_range(0.0, 1.0) = 0.35;

group_uniforms foam;
// Drifting patches of foam: 0 is none, 1 is a lot.
uniform float foam_amount : hint_range(0.0, 1.0) = 0.25;
// Size of the patches (bigger number, smaller patches).
uniform float foam_scale = 1.0;
// Extra foam along a river's banks and in rapids.
uniform float edge_foam : hint_range(0.0, 1.0) = 0.35;
uniform float rapid_foam : hint_range(0.0, 1.0) = 0.5;
// The rim of foam round anything that breaks the surface: how wide (metres), and how ragged.
uniform float rim_width = 0.45;
uniform float rim_ragged : hint_range(0.0, 1.0) = 0.5;

group_uniforms motion;
uniform float flow = 0.6;
// How big the waves are (open sea is rougher than a river).
uniform float swell = 1.0;
// How strongly the water lights up on the beat.
uniform float sparkle : hint_range(0.0, 2.0) = 1.0;

group_uniforms shine;
// Glints of sunlight on the water: how many (0 is none), how big each is (metres), and how
// many more there are along the path of light towards the sun.
uniform float glint_amount : hint_range(0.0, 1.0) = 0.4;
uniform float glint_size = 0.22;
uniform float glint_path : hint_range(0.0, 4.0) = 2.0;
uniform vec4 glint_color : source_color = vec4(1.0, 0.98, 0.9, 1.0);
// The sheen of the sky on the water where it is seen at a low angle: how strong, and its colour.
uniform float sheen : hint_range(0.0, 1.0) = 0.3;
uniform vec4 sheen_color : source_color = vec4(0.7, 0.85, 0.95, 1.0);
// Where the sun is (set from the stage).
uniform vec3 sun_dir = vec3(0.0, 0.3, -1.0);

uniform sampler2D depth_texture : hint_depth_texture, filter_nearest, repeat_disable;

varying vec3 v_world;

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

// Distance from the camera (metres) of a depth-buffer value at a point on screen.
float view_depth(vec2 screen_uv, float depth, mat4 inv_projection) {
#if CURRENT_RENDERER == RENDERER_COMPATIBILITY
	vec3 ndc = vec3(screen_uv, depth) * 2.0 - 1.0;
#else
	vec3 ndc = vec3(screen_uv * 2.0 - 1.0, depth);
#endif
	vec4 view = inv_projection * vec4(ndc, 1.0);
	return -view.z / view.w;
}

void vertex() {
	v_steep = 1.0 - clamp(NORMAL.y, 0.0, 1.0);
	v_world = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	float w = sin(UV.y * 0.45 - TIME * 4.0 + UV.x * 9.0) * 0.08 + sin(UV.y * 0.9 + TIME * 2.3) * 0.05;
	VERTEX.y += w * swell * (1.0 - v_steep);
	POSITION = psx_snap(PROJECTION_MATRIX * MODELVIEW_MATRIX * vec4(VERTEX, 1.0), VIEWPORT_SIZE);
}

void fragment() {
	// how much water lies between the surface here and whatever is behind it
	float behind = view_depth(SCREEN_UV, texture(depth_texture, SCREEN_UV).r, INV_PROJECTION_MATRIX);
	float surface = view_depth(SCREEN_UV, FRAGCOORD.z, INV_PROJECTION_MATRIX);
	float water = max(behind - surface, 0.0);
	float depth = clamp(water / depth_range, 0.0, 1.0);

	vec2 p = vec2(UV.x * 10.0, UV.y * 0.18 - TIME * flow * 3.0) * foam_scale;
	float n = vnoise(p) * 0.6 + vnoise(p * 2.3 + 7.0) * 0.4;

	// drifting patches, thicker along the banks (vertex green marks open water, which has
	// none) and in rapids (vertex red)
	float edge = smoothstep(0.36, 0.5, abs(UV.x - 0.5)) * (1.0 - COLOR.g);
	float patches = step(1.0 - foam_amount * 0.5 - edge * edge_foam * 0.6 - COLOR.r * rapid_foam * 0.3, n);
	// the rim: a hard band wherever the water is only this deep, with a ragged outer edge
	float rim = step(water, rim_width * (1.0 - rim_ragged * 0.8 * (1.0 - n)));
	float fall = smoothstep(0.35, 0.6, v_steep);
	float streak = step(0.45, vnoise(vec2(UV.x * 40.0, UV.y * 0.5 - TIME * 12.0 * sign(flow))));
	float white = max(max(patches * 0.85, rim), fall * (0.55 + 0.45 * streak));

	vec3 col = mix(shallow.rgb, deep.rgb, depth);
	col = mix(col, shallow.rgb, (n - 0.5) * ripple * (0.4 + 0.6 * depth));
	col = mix(col, foam_color.rgb, white);
	float band = step(0.9, fract(UV.y * 0.04 - TIME * 0.6));
	// the sheen: seen at a low angle, water takes the colour of the sky
	vec3 to_eye = CAMERA_POSITION_WORLD - v_world;
	float far = length(to_eye);
	float graze = 1.0 - clamp(to_eye.y / max(far, 0.001), 0.0, 1.0);
	col = mix(col, sheen_color.rgb, pow(graze, 8.0) * sheen * (1.0 - white));
	// glints: the water is cut into patches, each of which catches the sun for a moment now
	// and then. There are more of them, and they are brighter, on the path towards the sun.
	// (The patches grow with distance, so that far ones are still a pixel or two across.)
	float patch_size = glint_size * exp2(floor(log2(1.0 + far * 0.14)));
	vec2 spot = (v_world.xz + vec2(0.0, TIME * flow * 1.5)) / patch_size;
	vec2 cell = floor(spot);
	// (each glint is a small round spark in the middle of its patch)
	float spark = 1.0 - smoothstep(0.16, 0.34, length(fract(spot) - 0.5));
	float chance = hash(cell);
	float wink = sin(TIME * (3.0 + chance * 5.0) + chance * 40.0);
	vec2 sun_way = normalize(sun_dir.xz + vec2(0.0001));
	float path = pow(max(dot(normalize(-to_eye.xz + vec2(0.0001)), sun_way), 0.0), 12.0);
	float lit = glint_amount * (0.1 + glint_path * path * 0.3);
	float glint = step(1.0 - lit, chance) * smoothstep(0.55, 0.95, wink) * spark * (1.0 - white);
	ALBEDO = col;
	ALPHA = mix(mix(alpha_shallow, alpha_deep, depth), 0.97, white);
	ROUGHNESS = 0.42;
	SPECULAR = 0.2;
	EMISSION = beat.rgb * beat_pulse * sparkle * (0.12 + 0.5 * band + 0.3 * patches) + foam_color.rgb * fall * 0.15
			+ glint_color.rgb * glint * (0.55 + 0.5 * path);
	// seen from underneath, the surface is a bright ceiling that hides the sky
	if (!FRONT_FACING) {
		ALBEDO = mix(shallow.rgb, vec3(1.0), 0.2 + 0.4 * white);
		ALPHA = 0.95;
		EMISSION = shallow.rgb * 0.45;
	}
}
