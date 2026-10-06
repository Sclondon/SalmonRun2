// An ocean current, drawn the way wind is drawn: thin white wisps that wind round a tube in
// a spiral, each one a short stroke that starts from nothing, fattens and thins away again
// as it slides along; faint, grainy rings that travel down it; and bubbles carried along with
// it. UV.x is metres along it (scaled), UV.y goes once round it.
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
uniform float thickness = 0.045;
// How far it is round the tube (metres): set from its radius, so that a wide one's wisps
// and bubbles are the same size as a narrow one's.
uniform float girth = 7.85;
// How much of each ring is there (0 is none, 1 is a solid band), and how wide it is (m).
uniform float ring_cover = 0.4;
uniform float ring_width = 0.7;
// How many bubbles (0 is none, 1 is one in every place there could be one).
uniform float bubbles = 0.4;
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
	// The spiral. Each wisp is one of `strands` lines winding round the tube; along its line
	// it is broken into strokes of its own length, sliding at its own speed.
	float helix = (UV.y + UV.x * twist - TIME * speed * 0.12) * strands;
	float strand = mod(floor(helix), strands);
	float off_line = abs(fract(helix) - 0.5) * girth / strands;
	float along = UV.x * (0.3 + hash(vec2(strand, 3.0)) * 0.3) - TIME * speed * (0.22 + hash(vec2(strand, 7.0)) * 0.25) + hash(vec2(strand, 1.0));
	float stroke = fract(along) / 0.6;
	// (fat in the middle of a stroke, nothing at its ends, and nothing at all between strokes)
	float fat = stroke < 1.0 ? sin(stroke * 3.14159) : 0.0;
	float wisp = step(off_line, thickness * swell * fat) * step(0.02, fat);
	// The rings: a band round the tube, sliding along it, of which only a scatter of grains
	// is drawn (most in its middle, few at its edges), so that it is faint and see-through.
	float from_ring = abs(fract(UV.x * 0.75 - TIME * speed * 0.5) - 0.5) * 8.0;
	float band = 1.0 - smoothstep(0.0, ring_width * 0.5 * swell, from_ring);
	float grain = grain_at(vec2(UV.x * 30.0 - TIME * speed * 9.0, UV.y * 48.0), 48.0);
	float ring = step(1.0 - band * ring_cover, grain) * step(0.001, band);
	// Bubbles carried along: one, or none, in each place of a grid that slides down the tube
	// a little faster than the wisps do.
	float rows = max(floor(girth / 0.9), 3.0);
	vec2 place = vec2(UV.x * 2.4 - TIME * speed * 1.3, UV.y * rows);
	vec2 cell = vec2(floor(place.x), mod(floor(place.y), rows));
	vec2 in_cell = fract(place) - vec2(0.25 + 0.5 * hash(cell + 11.0), 0.25 + 0.5 * hash(cell + 23.0));
	float size = (0.05 + 0.08 * hash(cell + 5.0)) * swell;
	float bubble = step(length(in_cell * vec2(2.5, girth / rows)), size) * step(1.0 - bubbles, hash(cell));
	// (nothing of it is drawn right up against the eye)
	if (max(max(wisp, ring), bubble) < 0.5 || far < clear) {
		discard;
	}
	// (the murk does not hide it, as it is there to be found: it only dims with distance)
	float bright = max(wisp, max(ring * 0.7, bubble * 0.85));
	ALBEDO = colour.rgb * strength * bright * mix(1.0, 0.45, smoothstep(20.0, 130.0, far));
}
