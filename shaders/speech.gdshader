// A speech bubble: a flat card that always faces the eye, drawn as a rounded box with a
// dark edge and a little tail at its bottom left, pointing at whoever is speaking. Solid
// where it is drawn and cut away elsewhere. UV runs over the whole card; the box is its
// upper four fifths and the tail hangs in the rest.
shader_type spatial;
render_mode unshaded, cull_disabled, shadows_disabled, fog_disabled, depth_test_disabled;

uniform vec4 paper : source_color = vec4(1.0, 0.99, 0.94, 1.0);
uniform vec4 ink : source_color = vec4(0.06, 0.08, 0.18, 1.0);
// How wide the card is for its height (so that its corners are round, not squashed).
uniform float aspect = 3.0;

void vertex() {
	vec3 size = vec3(length(MODEL_MATRIX[0].xyz), length(MODEL_MATRIX[1].xyz), length(MODEL_MATRIX[2].xyz));
	MODELVIEW_MATRIX = VIEW_MATRIX * mat4(INV_VIEW_MATRIX[0] * size.x, INV_VIEW_MATRIX[1] * size.y, INV_VIEW_MATRIX[2] * size.z, MODEL_MATRIX[3]);
}

// How far inside a rounded box a point is (negative inside).
float box(vec2 p, vec2 half, float r) {
	vec2 q = abs(p) - half + r;
	return length(max(q, 0.0)) + min(max(q.x, q.y), 0.0) - r;
}

void fragment() {
	// (in units of the card's height, from the middle of the box)
	vec2 p = vec2((UV.x - 0.5) * aspect, UV.y - 0.4);
	float d = box(p, vec2(aspect * 0.5 - 0.04, 0.36), 0.2);
	// the tail: a wedge from the bottom of the box down to a point at the left
	vec2 t = vec2(p.x + aspect * 0.24, p.y - 0.3);
	float tail = max(max(-t.y - 0.06, t.y - 0.3), max(-0.6 * t.y - t.x, t.x - 0.3 + 1.4 * t.y));
	d = min(d, tail);
	if (d > 0.0) {
		discard;
	}
	ALBEDO = d > -0.055 ? ink.rgb : paper.rgb;
}
