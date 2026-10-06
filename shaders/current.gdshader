// An ocean current, drawn the way wind is drawn: thin white wisps that wind round a tube in
// a spiral, each one a short stroke that starts from nothing, fattens and thins away again
// as it slides along; and faint, grainy rings that travel down it. (The bubbles carried along
// inside it are not drawn here: see current_bubbles.gd.) UV.x is metres along it (scaled),
// UV.y goes once round it.
//
// It is solid where it is drawn at all, and cut away everywhere else. (It was once a glow
// added on top of the picture, but then the water over it could not dim it, so it was
// brighter seen from above than from beside it under the sea, and it came and went as it was
// sorted in front of the water or behind.) Drawn solid, it is under the water like everything
// else down there, and the surface tints it from above. What looks see-through in it (the
// rings) is a scatter of solid grains with gaps between.
shader_type spatial;
render_mode unshaded, cull_disabled, shadows_disabled, fog_disabled;

uniform vec4 colour : source_color = vec4(1.0, 1.0, 1.0, 1.0);
uniform float speed = 2.2;
uniform float strength = 1.0;
// How many wisps wind round it side by side, how many times each goes round in a stretch of
// 6 m, and half how thick they are at their fattest (metres; they are drawn thicker far off,
// where they would otherwise be too thin to see).
uniform float strands = 3.0;
uniform float twist = 0.5;
uniform float thickness = 0.09;
// How far it is round the tube (metres): set from its radius, so that a wide one's wisps
// and bubbles are the same size as a narrow one's.
uniform float girth = 7.85;
// How much of each ring is there (0 is none, 1 is a solid band), and how wide it is (m).
uniform float ring_cover = 0.62;
uniform float ring_width = 0.4;
// A wall for the tunnel, as a screen of dots strongest at its edges: how much of it is there
// (0 is none, and none is what it has: it was tried, and it looked boxed in), and its colour.
uniform float wall = 0.0;
// Where it begins and ends (as UV.x), and over how many metres it fades in at the one and
// out at the other: its ends are not cut off, they thin away into the water.
uniform vec2 ends = vec2(-10000.0, 10000.0);
uniform float fade = 26.0;
uniform vec4 wall_colour : source_color = vec4(0.6, 0.85, 1.0, 1.0);
// How near the eye it is cut away (metres): more while the salmon is riding inside it, so
// that the tube is not in the way of the view.
uniform float clear = 2.0;

// (worked out in whole numbers, so that it is the same on every renderer: see water.gdshader)
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

// Noise that comes round again every `wrap` squares up, so that it joins up round the tube.
float grain_at(vec2 p, float wrap) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	float y0 = mod(i.y, wrap);
	float y1 = mod(i.y + 1.0, wrap);
	return mix(mix(hash(vec2(i.x, y0)), hash(vec2(i.x + 1.0, y0)), f.x),
			mix(hash(vec2(i.x, y1)), hash(vec2(i.x + 1.0, y1)), f.x), f.y);
}

void fragment() {
	float far = -VERTEX.z;
	float swell = 1.0 + far * 0.04;
	// The strands. Each is one stroke of wind, like a stroke of a brush: a thin tail that
	// fattens towards its head, and at the head a curl turned back on itself. There are
	// `strands` lines for them to run along, winding round the tube; each line carries one
	// stroke after another with gaps between, of its own length and at its own speed.
	float helix = (UV.y + UV.x * twist - TIME * speed * 0.12) * strands;
	float strand = mod(floor(helix), strands);
	float lane = girth / strands;
	float side_m = (fract(helix) - 0.5) * lane;
	float rate = 0.14 + hash(vec2(strand, 3.0)) * 0.12;
	float along = UV.x * rate - TIME * speed * (0.2 + hash(vec2(strand, 7.0)) * 0.2) + hash(vec2(strand, 1.0));
	float stroke = fract(along) / 0.4;
	// (how many metres back from the tip of its head this is, along the stroke)
	float long_m = 0.4 * 6.0 / rate;
	float back_m = (1.0 - stroke) * long_m;
	float curl_r = min(0.42, lane * 0.22);
	float wide = thickness * swell;
	float wisp = 0.0;
	if (stroke < 1.0) {
		// the tail: nothing at its end, fattest where it meets the curl
		float fat = wide * (0.25 + 1.6 * pow(stroke, 1.5));
		wisp = step(abs(side_m), fat) * step(curl_r, back_m);
		// the curl: three quarters of a circle that the tail runs into
		vec2 from_centre = vec2(back_m - curl_r, side_m - curl_r);
		float round_it = atan(from_centre.y, -from_centre.x);
		float curl = step(abs(length(from_centre) - curl_r), wide * 1.5) * step(round_it, 1.3) * step(back_m, curl_r * 2.2);
		wisp = max(wisp, curl);
	}
	// The rings: a band round the tube, sliding along it, of which only a scatter of grains
	// is drawn (most in its middle, few at its edges), so that it is faint and see-through.
	float from_ring = abs(fract(UV.x * 0.5 - TIME * speed * 0.5) - 0.5) * 12.0;
	float band = 1.0 - smoothstep(0.0, ring_width * 0.5 * swell, from_ring);
	float grain = grain_at(vec2(UV.x * 30.0 - TIME * speed * 9.0, UV.y * 48.0), 48.0);
	float ring = step(1.0 - band * ring_cover, grain) * step(0.001, band);
	// The wall of the tunnel: a thin scatter of grains all over the tube, thickest where it
	// turns away from the eye (its edges), so that the whole of it shows as a pipe of glass.
	float facing = abs(dot(normalize(NORMAL), normalize(VIEW)));
	float glass = wall * pow(1.0 - facing, 1.6);
	// (a regular screen of dots, not a scatter: it is clear glass, not static)
	const float screen[16] = float[16](0.03, 0.53, 0.16, 0.66, 0.78, 0.28, 0.91, 0.41, 0.22, 0.72, 0.09, 0.59, 0.97, 0.47, 0.84, 0.34);
	float dot_here = screen[(int(FRAGCOORD.x) & 3) + (int(FRAGCOORD.y) & 3) * 4];
	float shell = step(dot_here, glass);
	// (towards either end, less and less of everything is drawn: it is thinned through the
	// same screen of dots, and the strands grow finer too)
	float there = smoothstep(0.0, fade / 6.0, min(UV.x - ends.x, ends.y - UV.x));
	float kept = step(dot_here, there * there * 1.05);
	// (nothing of it is drawn right up against the eye)
	if (max(max(wisp, ring), shell) * kept < 0.5 || far < clear) {
		discard;
	}
	// (the murk does not hide it, as it is there to be found: it only dims with distance)
	float bright = max(wisp, max(ring * 0.85, shell * 0.45));
	vec3 tint = mix(wall_colour.rgb, colour.rgb, wisp);
	ALBEDO = tint * strength * bright * mix(1.0, 0.45, smoothstep(20.0, 130.0, far));
}
