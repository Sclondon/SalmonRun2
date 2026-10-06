// An ocean current: a tube drawn as thin white lines that wind round it in a spiral, turning
// as they run the way it flows, with thin rings round it sliding the same way. UV.x is
// metres along it (scaled), UV.y goes once round it.
//
// It is solid where it is drawn at all, and cut away between the lines. (It was once a
// glow added on top of the picture, but then the water over it could not dim it, so it was
// brighter seen from above than from beside it under the sea, and it came and went as it was
// sorted in front of the water or behind.) Drawn solid, it is under the water like everything
// else down there, and the surface tints it from above.
shader_type spatial;
render_mode unshaded, cull_disabled, shadows_disabled, fog_disabled;

uniform vec4 colour : source_color = vec4(1.0, 1.0, 1.0, 1.0);
uniform float speed = 2.2;
uniform float strength = 1.0;
// How many lines wind round it, how many times each goes round in a stretch of 6 m, and how
// thick they and the rings are (as a part of the way round; they are drawn thicker far off,
// where they would otherwise be too thin to see).
uniform float strands = 3.0;
uniform float twist = 0.5;
uniform float thickness = 0.022;
// How near the eye it is cut away (metres): more while the salmon is riding inside it, so
// that the tube is not in the way of the view.
uniform float clear = 2.0;

void fragment() {
	float far = -VERTEX.z;
	float thick = thickness * (1.0 + far * 0.04);
	// the spiral: lines that go round the tube as they go along it, and turn as time passes
	float round_it = fract((UV.y + UV.x * twist - TIME * speed * 0.12) * strands);
	float line = step(abs(round_it - 0.5), thick * strands * 0.5);
	// rings round it, sliding along the way it flows
	float along = fract(UV.x * 0.75 - TIME * speed * 0.5);
	float ring = step(abs(along - 0.5), thick * 1.6);
	// (nothing of it is drawn right up against the eye)
	if (max(line, ring) < 0.5 || far < clear) {
		discard;
	}
	// (the murk does not hide it, as it is there to be found: it only dims with distance)
	ALBEDO = colour.rgb * strength * mix(1.0, 0.45, smoothstep(20.0, 130.0, far));
}
