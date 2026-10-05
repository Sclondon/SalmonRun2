// Water. It is lit as real water is: a smooth, shiny skin of small waves that mirrors the sky
// and catches the sun on every crest. Its colour goes from shallow to deep with how much
// water there really is under each pixel, a rim of foam forms wherever something breaks the
// surface (banks, rocks, ramps, the fish), patches of foam drift with the current, waterfalls
// turn to white water, and the whole thing shimmers on the beat.
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
uniform float ripple : hint_range(0.0, 1.0) = 0.12;

group_uniforms foam;
// Drifting patches of foam: 0 is none, 1 is a lot.
uniform float foam_amount : hint_range(0.0, 1.0) = 0.25;
// Whitecaps: how readily the tops of the waves break into flecks of foam (0 is never).
uniform float whitecaps : hint_range(0.0, 1.0) = 0.3;
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

group_uniforms surface;
// The surface is lit as real water is: a smooth, shiny skin of small waves that mirrors the
// sky and catches the sun. How rough it is (0 is a mirror), and how strongly it reflects.
uniform float roughness : hint_range(0.0, 1.0) = 0.14;
uniform float specular : hint_range(0.0, 1.0) = 0.3;
// Stylised: how strongly a thin light line is drawn along the shoulder of each swell.
uniform float lines : hint_range(0.0, 1.0) = 0.5;
// The small waves that give it its shape: how fine they are, how steep, how peaked their
// crests are, and how fast they move.
uniform float wave_scale = 0.55;
uniform float wave_height : hint_range(0.0, 3.0) = 0.5;
uniform float wave_choppy = 1.4;
uniform float wave_speed = 1.0;
// How far across the water UV.x runs from 0 to 1, in metres (set from the stage).
uniform float across = 22.0;

group_uniforms wake;
// The salmon's trail, oldest first: (where across, as UV.x; metres along; seconds ago, or -1
// for a break in it). Set every frame by fx/wake.gd.
uniform vec3 wake_pts[24];
uniform int wake_count = 0;
// The stretch of water (metres along) the trail lies in: nothing outside it is looked at.
uniform vec2 wake_span = vec2(0.0, 0.0);
// How long the wake lasts (s), how fast its arms move apart (m/s), and how wide they get (m).
uniform float wake_life = 1.6;
uniform float wake_spread = 2.1;
uniform float wake_width = 0.55;

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

// A wave train: smooth swells, peaked the more the choppier.
float swell_of(float phase) {
	return pow(0.5 + 0.5 * sin(phase), wave_choppy);
}

// The height of the small waves at a point on the water (metres across, metres along):
// a few broad trains of swell crossing one another, each running its own way, with a soft
// ripple over them. A slow drift bends them all, so that no two crests run side by side
// for long.
float wave_h(vec2 p) {
	float t = TIME * wave_speed;
	p *= wave_scale;
	p += (vec2(vnoise(p * 0.3 + 3.0), vnoise(p * 0.3 + 11.0)) - 0.5) * 3.0;
	float h = swell_of(dot(p, vec2(0.8, 0.6)) + t * 1.3) * 0.9;
	h += swell_of(dot(p, vec2(-0.5, 0.86)) * 1.7 - t * 1.7) * 0.55;
	h += swell_of(dot(p, vec2(0.95, -0.3)) * 2.9 + t * 2.3) * 0.3;
	h += vnoise(p * 2.3 + vec2(t * 0.6, 0.0)) * 0.35;
	return h;
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
	// The shape of the surface: the slope of the small waves here, turned into a normal, so
	// that the light and the sky are reflected off each one as off real water. (The slope is
	// measured along the water's own two directions, across and along, which are found in
	// the world from how they change over the screen.)
	vec3 to_eye = CAMERA_POSITION_WORLD - v_world;
	float far = length(to_eye);
	vec2 at = vec2(UV.x * across, UV.y - TIME * flow * 2.0);
	float eps = 0.06 + far * 0.003;
	float h0 = wave_h(at);
	float slope_x = (wave_h(at + vec2(eps, 0.0)) - h0) / eps;
	float slope_y = (wave_h(at + vec2(0.0, eps)) - h0) / eps;
	// The salmon's wake is part of the water: two bands of foam that open out behind it into
	// a V, with the water between them churned flat, so that the waves do not run on through
	// it. (The salmon's trail comes in as a string of points: where it was across the water,
	// how far along, and how long ago.)
	float wake_foam = 0.0;
	float wake_calm = 0.0;
	vec2 here = vec2((UV.x - 0.5) * across, UV.y);
	if (wake_count > 1 && here.y > wake_span.x && here.y < wake_span.y) {
		for (int i = 0; i < wake_count - 1; i++) {
			vec3 a = wake_pts[i];
			vec3 b = wake_pts[i + 1];
			if (a.z < 0.0 || b.z < 0.0) {
				continue;
			}
			vec2 pa = vec2((a.x - 0.5) * across, a.y);
			vec2 ab = vec2((b.x - 0.5) * across, b.y) - pa;
			// (only the water beside this stretch of the trail, not round its ends)
			float t = dot(here - pa, ab) / max(dot(ab, ab), 0.0001);
			if (t < -0.04 || t > 1.04) {
				continue;
			}
			float d = length(here - (pa + ab * t));
			float age = mix(a.z, b.z, t);
			float k = clamp(age / wake_life, 0.0, 1.0);
			// each arm moves out from the middle as it ages, widens, and fades
			float inner = 0.26 + wake_spread * age * (1.0 - 0.3 * k);
			float wide = wake_width * smoothstep(0.0, 0.12, age) * (1.0 - 0.45 * k) + 0.06;
			float fade = pow(1.0 - k, 1.3);
			float arm = smoothstep(inner - 0.1, inner, d) * (1.0 - smoothstep(inner + wide * 0.35, inner + wide, d));
			wake_foam = max(wake_foam, arm * fade);
			wake_calm = max(wake_calm, (1.0 - smoothstep(inner * 0.7, inner + wide, d)) * fade);
		}
	}
	// (its foam has a ragged edge, like the rest)
	float wake_white = step(0.4, wake_foam * (0.5 + n));
	white = max(white, wake_white);
	col = mix(col, shallow.rgb, wake_calm * 0.3 * (1.0 - white));
	col = mix(col, foam_color.rgb, wake_white);
	// whitecaps: the tops of the bigger waves break into hard-edged flecks of foam (broken up
	// by a finer noise, so that they are flecks and streaks, not blobs). There are none far
	// off, where they would only be specks, nor in the wake.
	float fleck = vnoise(at * 4.0 + vec2(0.0, TIME * 0.7)) * 0.65 + vnoise(at * 1.1 - vec2(TIME * 0.3, 0.0)) * 0.35;
	float cap = step(mix(0.95, 0.66, whitecaps), h0 / 2.1 + (fleck - 0.5) * 0.5) * (1.0 - fall) * step(0.001, whitecaps)
			* (1.0 - smoothstep(110.0, 300.0, far)) * (1.0 - wake_calm);
	white = max(white, cap * 0.92);
	col = mix(col, foam_color.rgb, cap * 0.92);
	// wave lines: a thin light line along the shoulder of each swell, as water is drawn
	float line = (1.0 - smoothstep(0.0, 0.03, abs(h0 / 2.1 - 0.56))) * lines * (1.0 - white)
			* (1.0 - smoothstep(60.0, 200.0, far)) * (1.0 - wake_calm);
	col = mix(col, mix(shallow.rgb, foam_color.rgb, 0.45), line);
	vec2 metres = vec2(UV.x * across, UV.y);
	vec3 dp1 = dFdx(v_world);
	vec3 dp2 = dFdy(v_world);
	vec2 d1 = dFdx(metres);
	vec2 d2 = dFdy(metres);
	vec3 across_way = normalize(dp1 * d2.y - dp2 * d1.y + vec3(0.00001, 0.0, 0.0));
	vec3 along_way = normalize(dp2 * d1.x - dp1 * d2.x + vec3(0.0, 0.0, 0.00001));
	vec3 flat_normal = normalize((INV_VIEW_MATRIX * vec4(NORMAL, 0.0)).xyz);
	// (far off the waves are smaller than a pixel: they are smoothed away, or they would
	// only be noise; foam is not shiny; and the wake has flattened them)
	float steepness = wave_height * 0.5 * mix(1.0, 0.12, smoothstep(30.0, 170.0, far)) * (1.0 - white) * (1.0 - 0.85 * wake_calm);
	vec3 wavy = normalize(flat_normal - (across_way * slope_x + along_way * slope_y) * steepness);
	// seen at a low angle water is a mirror, however clear it is seen from above
	float fresnel = pow(1.0 - clamp(dot(wavy, to_eye / max(far, 0.001)), 0.0, 1.0), 5.0);
	ALBEDO = col;
	ALPHA = mix(mix(mix(alpha_shallow, alpha_deep, depth), 1.0, fresnel * 0.9), 0.97, white);
	ROUGHNESS = mix(roughness, 0.85, white);
	SPECULAR = specular;
	METALLIC = 0.0;
	EMISSION = beat.rgb * beat_pulse * sparkle * (0.12 + 0.5 * band + 0.3 * patches) + foam_color.rgb * fall * 0.15;
	// seen from underneath, the surface is a bright ceiling that hides the sky
	if (!FRONT_FACING) {
		ALBEDO = mix(shallow.rgb, vec3(1.0), 0.2 + 0.4 * white);
		ALPHA = 0.95;
		EMISSION = shallow.rgb * 0.45;
		ROUGHNESS = 0.9;
	} else {
		NORMAL = normalize((VIEW_MATRIX * vec4(wavy, 0.0)).xyz);
	}
}
