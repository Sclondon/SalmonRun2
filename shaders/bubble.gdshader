// A bubble: a flat square that always faces the eye, drawn as a plain ring with a glint on
// it. Solid where it is drawn and cut away elsewhere, like everything else under the water.
shader_type spatial;
render_mode unshaded, cull_disabled, shadows_disabled, fog_disabled;

uniform vec4 colour : source_color = vec4(0.88, 0.97, 1.0, 1.0);
// How thick the ring is, as a part of the bubble's radius.
uniform float rim = 0.26;

void vertex() {
	// (turned to face the eye, and kept the size it was set down at)
	vec3 size = vec3(length(MODEL_MATRIX[0].xyz), length(MODEL_MATRIX[1].xyz), length(MODEL_MATRIX[2].xyz));
	MODELVIEW_MATRIX = VIEW_MATRIX * mat4(INV_VIEW_MATRIX[0] * size.x, INV_VIEW_MATRIX[1] * size.y, INV_VIEW_MATRIX[2] * size.z, MODEL_MATRIX[3]);
}

void fragment() {
	vec2 from_middle = (UV - 0.5) * 2.0;
	float d = length(from_middle);
	float ring = step(d, 1.0) * step(1.0 - rim, d);
	float glint = step(length(from_middle - vec2(-0.32, -0.32)), 0.2);
	if (max(ring, glint) < 0.5) {
		discard;
	}
	ALBEDO = colour.rgb * mix(1.0, 0.5, smoothstep(25.0, 120.0, -VERTEX.z));
}
