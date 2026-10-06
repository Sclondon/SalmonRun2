// Water, in a flat, painted style: matte colour, clear close to and solid far off, faint pale
// lines wandering over it and drifts of flat white foam. Its colour goes from shallow to deep with how much
// water there really is under each pixel, a rim of foam forms wherever something breaks the
// surface (banks, rocks, ramps, the fish), patches of foam drift with the current, and waterfalls
// turn to white water.
//
// The waves are real: the mesh is fine enough (a few metres to a square) to be lifted into a
// swell, a sum of four trains of waves of different lengths crossing one another, and the
// light falls on the slope of that swell worked out at every pixel, so that it is smooth
// however coarse the mesh. track.gd works out the same swell (swell_y) to float things on it.
//
// Every stage can set any of these from its entry in levels.gd: a key "water_<name>" sets the
// uniform <name>.
shader_type spatial;
render_mode cull_disabled, specular_schlick_ggx;

#include "res://shaders/psx_common.gdshaderinc"


group_uniforms colour;
uniform vec4 deep : source_color = vec4(0.03, 0.30, 0.36, 1.0);
uniform vec4 shallow : source_color = vec4(0.16, 0.70, 0.64, 1.0);
uniform vec4 foam_color : source_color = vec4(0.92, 1.0, 0.96, 1.0);
// Metres of water before it reaches its deep colour.
uniform float depth_range = 5.0;
// How solid the water looks where it is shallow and where it is deep (1 hides what is under it).
uniform float alpha_shallow : hint_range(0.0, 1.0) = 0.6;
uniform float alpha_deep : hint_range(0.0, 1.0) = 0.93;
// How much the surface colour varies in ripples.
uniform float colour_ripple : hint_range(0.0, 1.0) = 0.08;
// Looked straight down into, water is paler than looked across: how much (0 is no
// difference, 1 is as pale as the shallows).
uniform float view_clear : hint_range(0.0, 1.0) = 0.35;

group_uniforms foam;
// Drifting patches of foam: 0 is none, 1 is a lot.
uniform float foam_amount : hint_range(0.0, 1.0) = 0.18;
// Whitecaps: how much of the water has drifts of flat white foam lying on it (0 is none).
uniform float whitecaps : hint_range(0.0, 1.0) = 0.3;
// Size of the patches (bigger number, smaller patches).
uniform float foam_scale = 1.0;
// The pattern the foam is cut from: a grey picture that wraps round at its edges. Where it
// is bright there is foam; the settings above say how bright it has to be. (Made by
// scripts/tools/bake_foam.gd; any picture that wraps will do in its place.) And how many
// metres of water one copy of it covers. (With no picture set there is no foam.)
uniform sampler2D foam_texture : repeat_enable, filter_linear, hint_default_black;
uniform float foam_size = 22.0;
// How much more foam there is on the crests of the swell than in its troughs (0 is no more).
uniform float crest_foam : hint_range(0.0, 1.0) = 0.5;
// Extra foam along a river's banks and in rapids.
uniform float edge_foam : hint_range(0.0, 1.0) = 0.35;
uniform float rapid_foam : hint_range(0.0, 1.0) = 0.5;
// The rim of foam round anything that breaks the surface: how wide (metres), and how ragged.
uniform float rim_width = 0.45;
uniform float rim_ragged : hint_range(0.0, 1.0) = 0.5;

group_uniforms motion;
uniform float flow = 0.6;
// The swell. How rough the stage's water is (open sea is rougher than a river: set from the
// stage), then how high its biggest wave is for each 1 of that (metres), how long (metres:
// rougher water has longer waves as well), and how fast it travels (1 is as real waves do).
uniform float swell = 1.0;
uniform float swell_height : hint_range(0.0, 1.0) = 0.18;
uniform float swell_length : hint_range(2.0, 60.0) = 12.0;
uniform float swell_speed : hint_range(0.0, 4.0) = 1.0;
// (The swell keeps time by water_clock, seconds since the stage was made: a setting of the
// whole project, sent every frame by track.gd, which keeps the same time for its own copy.)
global uniform float water_clock;

group_uniforms surface;
// The surface is lit as real water is: a smooth, shiny skin of small waves that mirrors the
// sky and catches the sun. How rough it is (0 is a mirror), and how strongly it reflects.
uniform float roughness : hint_range(0.0, 1.0) = 0.5;
uniform float specular : hint_range(0.0, 1.0) = 0.12;
// Stylised: how strongly faint pale lines are drawn wandering over the surface.
uniform float lines : hint_range(0.0, 1.0) = 0.6;
// The small waves that give it its shape: how fine they are, how steep, how peaked their
// crests are, and how fast they move.
uniform float ripple_scale = 0.55;
uniform float ripple_height : hint_range(0.0, 3.0) = 0.16;
uniform float ripple_choppy = 1.4;
uniform float ripple_speed = 1.0;
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
uniform float wake_spread = 2.4;
uniform float wake_width = 0.4;

uniform sampler2D depth_texture : hint_depth_texture, filter_nearest, repeat_disable;

varying vec3 v_world;

varying float v_steep;
// where this is on the water in metres (across from the middle, along), and how much of
// the swell there is here (none far out to sea)
varying vec2 v_metres;
varying float v_swell;

// A random number from 0 to 1 for each corner of a grid. It is worked out in whole numbers,
// so that a corner gets the same number whichever square of the grid asks for it. (The usual
// fract(sin(...)) does not: the desktop renderer works out "this corner plus one" a hair
// differently from "the next corner", the number comes out quite different, and every square
// of the noise shows as a block with a seam round it.)
float hash(vec2 p) {
	ivec2 c = ivec2(round(p));
	uint h = uint(c.x) * 668265261u ^ (uint(c.y) * 374761393u);
	h ^= h >> 15u;
	h *= 2246822519u;
	h ^= h >> 13u;
	h *= 3266489917u;
	h ^= h >> 16u;
	return float(h) / 4294967295.0;
}

float vnoise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash(i), hash(i + vec2(1.0, 0.0)), f.x),
			mix(hash(i + vec2(0.0, 1.0)), hash(i + vec2(1.0, 1.0)), f.x), f.y);
}

// Smooth noise for anything whose slope is looked at (the shape of the waves): a slope at
// each corner of a grid, blended so that neither the height nor its slope nor its curve
// jumps from one square to the next. (vnoise above is only smooth in height: light glancing
// off waves made from it shows up every square of its grid.) From 0 to 1, like vnoise.
vec2 slope_at(vec2 corner) {
	float a = hash(corner) * 6.2831853;
	return vec2(cos(a), sin(a));
}

float gnoise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	vec2 u = f * f * f * (f * (f * 6.0 - 15.0) + 10.0);
	float a = dot(slope_at(i), f);
	float b = dot(slope_at(i + vec2(1.0, 0.0)), f - vec2(1.0, 0.0));
	float c = dot(slope_at(i + vec2(0.0, 1.0)), f - vec2(0.0, 1.0));
	float d = dot(slope_at(i + vec2(1.0, 1.0)), f - vec2(1.0, 1.0));
	return 0.5 + 0.7 * mix(mix(a, b, u.x), mix(c, d, u.x), u.y);
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

// One layer of ripples: smooth humps, peaked the more the choppier.
float ripples_of(vec2 p) {
	return pow(clamp(gnoise(p), 0.0, 1.0), ripple_choppy);
}

// The height of the small waves at a point on the water (metres across, metres along):
// three layers of smooth humps, each finer than the last, each turned a different way and
// each drifting its own way, so that nothing in them lines up or comes round again. (They
// were once trains of straight waves crossing one another, which is a criss-cross: a grid.)
float wave_h(vec2 p) {
	float t = TIME * ripple_speed;
	p *= ripple_scale;
	float h = ripples_of(p * 0.33 + vec2(t * 0.17, t * 0.11)) * 1.5;
	p = vec2(p.x * 0.8 - p.y * 0.6, p.x * 0.6 + p.y * 0.8);
	h += ripples_of(p * 0.71 + vec2(-t * 0.23, t * 0.19) + 13.0) * 0.8;
	p = vec2(p.x * 0.8 - p.y * 0.6, p.x * 0.6 + p.y * 0.8);
	h += ripples_of(p * 1.57 + vec2(t * 0.31, -t * 0.37) + 31.0) * 0.4;
	return h;
}

// The swell at a point on the water (metres across, metres along): its height, and its slope
// each way. Four trains of waves, each shorter and lower than the last and running its own
// way; the long ones travel faster, as real waves do. (track.gd has the same sum: SWELLS.)
vec3 swell_at(vec2 p) {
	const vec4 trains[4] = vec4[4](
			vec4(0.34, -0.94, 1.0, 1.0),
			vec4(-0.78, -0.62, 0.62, 0.55),
			vec4(0.97, 0.26, 0.37, 0.3),
			vec4(-0.57, 0.82, 0.23, 0.16));
	float long = swell_length * (0.4 + 0.6 * swell);
	float high = swell_height * swell;
	vec3 sum = vec3(0.0);
	for (int i = 0; i < 4; i++) {
		float k = 6.2831853 / (long * trains[i].z);
		float phase = k * dot(trains[i].xy, p) - sqrt(9.8 * k) * swell_speed * water_clock + float(i) * 1.7;
		float a = high * trains[i].w;
		sum.x += a * sin(phase);
		sum.yz += trains[i].xy * (a * k * cos(phase));
	}
	return sum;
}

void vertex() {
	v_steep = 1.0 - clamp(NORMAL.y, 0.0, 1.0);
	v_metres = vec2(UV2.x, UV.y);
	// (none on a waterfall, and none far out to sea, where the mesh is too coarse to bend)
	v_swell = UV2.y * (1.0 - smoothstep(0.1, 0.4, v_steep));
	VERTEX.y += swell_at(v_metres).x * v_swell;
	v_world = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	POSITION = psx_snap(PROJECTION_MATRIX * MODELVIEW_MATRIX * vec4(VERTEX, 1.0), VIEWPORT_SIZE);
}

void fragment() {
	// how much water lies between the surface here and whatever is behind it
	float behind = view_depth(SCREEN_UV, texture(depth_texture, SCREEN_UV).r, INV_PROJECTION_MATRIX);
	float surface = view_depth(SCREEN_UV, FRAGCOORD.z, INV_PROJECTION_MATRIX);
	float water = max(behind - surface, 0.0);
	float depth = clamp(water / depth_range, 0.0, 1.0);

	vec2 p = vec2(v_metres.x * 0.37, UV.y * 0.18 - TIME * flow * 3.0) * foam_scale;
	float n = smoothstep(0.25, 0.75, texture(foam_texture, p * 0.13).r * 0.6 + texture(foam_texture, p.yx * 0.29 + 0.37).r * 0.4);

	// drifting patches, thicker along the banks (vertex green marks open water, which has
	// none) and in rapids (vertex red)
	float edge = smoothstep(0.36, 0.5, abs(UV.x - 0.5)) * (1.0 - COLOR.g);
	// (a hair over 1 with everything at 0, so that then there is none at all)
	float patches = step(1.001 - foam_amount * 0.5 - edge * edge_foam * 0.6 - COLOR.r * rapid_foam * 0.3, n);
	// the rim: a hard band wherever the water is only this deep, with a ragged outer edge
	float rim = step(water, rim_width * (1.0 - rim_ragged * 0.8 * (1.0 - n))) * step(0.0001, rim_width);
	float fall = smoothstep(0.35, 0.6, v_steep);
	float streak = step(0.45, vnoise(vec2(UV.x * 40.0, UV.y * 0.5 - TIME * 12.0 * sign(flow))));
	float white = max(max(patches * 0.85, rim), fall * (0.55 + 0.45 * streak));

	// The swell here: its height, and its slope each way.
	vec3 rise = swell_at(v_metres);
	float crest = clamp(rise.x / max(swell_height * swell * 1.4, 0.001), -1.0, 1.0) * v_swell;
	vec3 to_eye = CAMERA_POSITION_WORLD - v_world;
	float far = length(to_eye);
	// looked straight down into, water is paler than looked across
	float tone = depth * (1.0 - view_clear * clamp(to_eye.y / max(far, 0.001), 0.0, 1.0));
	vec3 col = mix(shallow.rgb, deep.rgb, tone);
	// (and a crest is a little paler than a trough)
	col = mix(col, shallow.rgb, max(crest, 0.0) * 0.18);
	// (the colour varies in soft patches: made from the smooth noise, or its grid shows)
	float tint = gnoise(p * 0.7) * 0.6 + gnoise(p * 1.6 + 7.0) * 0.4;
	col = mix(col, shallow.rgb, (tint - 0.5) * 2.0 * colour_ripple * (0.4 + 0.6 * depth));
	col = mix(col, foam_color.rgb, white);
	// The shape of the surface: the slope of the small waves here, turned into a normal, so
	// that the light and the sky are reflected off each one as off real water. (The slope is
	// measured a short step each way; the step is longer the bigger the waves are set, or it
	// would be too short to measure at all.)
	// (in metres across the course, not by the mapping, which is not the same size out to sea)
	vec2 at = vec2(v_metres.x, UV.y - TIME * flow * 2.0);
	float eps = (0.06 + far * 0.003) * 0.55 / max(ripple_scale, 0.02);
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
	// Foam lies on the water in flat white patches with ragged edges, gathered into drifts
	// with clear water between them, and a scatter of small flecks round about. (None far
	// off, where they would only be specks, nor in the wake.)
	// (cut from the foam picture, laid twice at two sizes so that it is not seen to repeat;
	// a slow, smooth noise gathers it into drifts)
	vec2 fuv = at * foam_scale / foam_size;
	float sheet = texture(foam_texture, fuv).r * 0.65 + texture(foam_texture, fuv.yx * 2.63 + vec2(0.31, 0.17)).r * 0.35;
	float drift = gnoise(at * 0.022 + 20.0);
	// (more of it on the crests of the swell than in the troughs: it forms as a crest comes
	// up under it, and thins away again as the crest goes by)
	float lift = crest * crest_foam * 0.12;
	float cap = step(mix(1.02, 0.6, whitecaps), sheet + (drift - 0.5) * 0.8 + lift);
	cap *= (1.0 - fall) * step(0.001, whitecaps) * (1.0 - smoothstep(150.0, 340.0, far)) * (1.0 - wake_calm);
	white = max(white, cap);
	col = mix(col, foam_color.rgb, cap);
	// and faint pale lines wander over it, like light on the surface
	vec2 lp = at * 0.3 + (vec2(vnoise(at * 0.2 + 1.0), vnoise(at * 0.2 + 7.0)) - 0.5) * 2.0;
	float line = (1.0 - smoothstep(0.0, 0.045, abs(vnoise(lp + vec2(0.0, TIME * 0.12)) - 0.5))) * lines * (1.0 - white)
			* (1.0 - smoothstep(50.0, 160.0, far)) * (1.0 - wake_calm);
	col = mix(col, mix(col, foam_color.rgb, 0.35), line);
	// The water's own two directions in the world, across and along: each corner of the mesh
	// carries them (its tangent), so that they turn smoothly with the course. (They were once
	// worked out from how the surface changes over the screen, which gave every triangle of
	// the mesh directions of its own, and a seam along each of its edges.)
	vec3 across_way = normalize((INV_VIEW_MATRIX * vec4(TANGENT, 0.0)).xyz);
	vec3 along_way = normalize((INV_VIEW_MATRIX * vec4(BINORMAL, 0.0)).xyz);
	vec3 flat_normal = normalize((INV_VIEW_MATRIX * vec4(NORMAL, 0.0)).xyz);
	// (far off the small waves are smaller than a pixel: they are smoothed away, or they would
	// only be noise; foam is not shiny; and the wake has flattened them. The swell is none
	// of those things: it is the shape of the water itself.)
	float steepness = ripple_height * 0.5 * mix(1.0, 0.12, smoothstep(30.0, 170.0, far)) * (1.0 - white) * (1.0 - 0.85 * wake_calm);
	vec2 slope = vec2(slope_x, slope_y) * steepness + rise.yz * v_swell;
	vec3 wavy = normalize(flat_normal - across_way * slope.x - along_way * slope.y);
	// seen at a low angle water is a mirror, however clear it is seen from above
	float fresnel = pow(1.0 - clamp(dot(wavy, to_eye / max(far, 0.001)), 0.0, 1.0), 5.0);
	ALBEDO = col;
	ALPHA = mix(mix(mix(alpha_shallow, alpha_deep, depth), 1.0, fresnel * 0.9), 0.97, white);
	ROUGHNESS = mix(roughness, 0.85, white);
	SPECULAR = specular;
	METALLIC = 0.0;
	EMISSION = foam_color.rgb * fall * 0.15;
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
