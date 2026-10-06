// The sky: a banded gradient, with either a striped retro sun or (sun_disc 0) only the glow
// of the sun where it stands.
shader_type sky;

uniform vec3 top_color : source_color = vec3(0.10, 0.05, 0.24);
uniform vec3 horizon_color : source_color = vec3(1.0, 0.42, 0.36);
uniform vec3 bottom_color : source_color = vec3(0.04, 0.16, 0.12);
uniform vec3 sun_color : source_color = vec3(1.0, 0.82, 0.35);
uniform vec3 sun_dir = vec3(0.0, 0.12, -1.0);
uniform float bands = 14.0;
uniform float sun_disc = 1.0;
// Simple clouds: flat puffs with hard edges, drifting slowly. How much of the sky they
// cover (0 is none), and how big they are.
uniform float clouds = 0.32;
uniform float cloud_size = 1.0;
// Night: stars (0 is none, 1 is a sky full), and an aurora (0 is none): curtains of green
// light, shading to violet at their tops, that hang in the sky and sway.
uniform float stars = 0.0;
uniform float aurora = 0.0;

// (worked out in whole numbers, so that it is the same on every renderer: see water.gdshader)
float cell(vec2 p) {
	ivec2 c = ivec2(round(p));
	uint h = uint(c.x) * 668265261u ^ (uint(c.y) * 374761393u);
	h ^= h >> 15u;
	h *= 2246822519u;
	h ^= h >> 13u;
	h *= 3266489917u;
	h ^= h >> 16u;
	return float(h) / 4294967295.0;
}

float puff(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	return mix(mix(cell(i), cell(i + vec2(1.0, 0.0)), f.x), mix(cell(i + vec2(0.0, 1.0)), cell(i + vec2(1.0, 1.0)), f.x), f.y);
}

void sky() {
	float y = EYEDIR.y;
	float g = floor(smoothstep(0.0, 0.65, y) * bands) / bands;
	vec3 col = mix(horizon_color, top_color, g);
	col = mix(col, bottom_color, smoothstep(0.0, -0.15, y));
	// The clouds lie on a flat ceiling over the world: looked at low down they are far off and
	// close together, overhead they are big. They are drawn in blocks, like the rest.
	if (clouds > 0.0 && y > 0.015) {
		vec2 over = EYEDIR.xz / (y + 0.12) * 1.6 / cloud_size + vec2(TIME * 0.006, TIME * 0.002);
		over = floor(over * 14.0) / 14.0;
		float heap = puff(over) * 0.65 + puff(over * 2.3 + 9.0) * 0.35;
		float there = step(1.0 - clouds * 0.62, heap) * smoothstep(0.015, 0.1, y);
		// (lit on top, a shade darker in the middle of each)
		vec3 cloud_col = mix(horizon_color, vec3(1.0), 0.55) * mix(1.0, 0.9, step(1.0 - clouds * 0.4, heap));
		col = mix(col, cloud_col, there * 0.9);
	}
	vec3 sd = normalize(sun_dir);
	float d = distance(EYEDIR, sd);
	float disc = 1.0 - step(0.16, d);
	float below = sd.y - EYEDIR.y;
	if (below > 0.0) {
		float stripe = step(0.45 + below * 2.5, fract(below * 38.0));
		disc *= 1.0 - stripe;
	}
	col = mix(col, sun_color * 1.6, disc * sun_disc);
	// (with no disc, the glow is the sun: brighter, and tight round where it stands)
	col += sun_color * (0.25 * exp(-d * 6.0) + (1.0 - sun_disc) * 0.9 * exp(-d * 22.0));
	if (stars > 0.0 && y > 0.0) {
		// (one, or none, in each little square of the sky; a few of them twinkle)
		vec2 sq = floor(EYEDIR.xz / (y + 0.35) * 120.0);
		float star = cell(sq);
		float lit = step(1.0 - 0.02 * stars, star) * (0.55 + 0.45 * sin(TIME * (1.0 + star * 5.0) + star * 40.0));
		col += vec3(0.9, 0.95, 1.0) * lit * smoothstep(0.0, 0.25, y);
	}
	if (aurora > 0.0 && y > 0.04) {
		vec2 over = EYEDIR.xz / (y + 0.2);
		// a curtain: a wavering line across the sky, bright at its foot and fading upwards
		float wave = sin(over.x * 1.3 + TIME * 0.15) * 0.5 + sin(over.x * 3.1 - TIME * 0.22) * 0.25;
		// (how far up the curtain this is: its foot hangs a little above the horizon)
		float from_foot = (y - 0.13 - 0.07 * wave) / 0.5;
		float curtain = smoothstep(0.0, 0.08, from_foot) * (1.0 - smoothstep(0.08, 1.1, from_foot));
		float rays = 0.6 + 0.4 * puff(vec2(over.x * 9.0 + TIME * 0.3, 2.0));
		vec3 glow = mix(vec3(0.2, 1.0, 0.55), vec3(0.6, 0.3, 1.0), smoothstep(0.1, 0.9, from_foot));
		col += glow * curtain * rays * aurora * 0.9 * smoothstep(0.04, 0.2, y);
	}
	COLOR = col;
}
