// An ocean current: a tube of bright streaks that run along it the way it flows, with hoops
// round it. UV.x is metres along it (scaled), UV.y goes once round it.
//
// It is solid where it is drawn at all, and cut away between the streaks. (It was once a
// glow added on top of the picture, but then the water over it could not dim it, so it was
// brighter seen from above than from beside it under the sea, and it came and went as it was
// sorted in front of the water or behind.) Drawn solid, it is under the water like everything
// else down there, and the surface tints it from above.
shader_type spatial;
render_mode unshaded, cull_disabled, shadows_disabled, fog_disabled;

uniform vec4 colour : source_color = vec4(0.35, 0.95, 1.0, 1.0);
uniform float speed = 2.2;
uniform float strength = 1.0;
// How near the eye it is cut away (metres): more while the salmon is riding inside it, so
// that the tube is not in the way of the view.
uniform float clear = 2.0;

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

void fragment() {
	// streaks: each lane round the tube has dashes of its own length, sliding along
	float lane = floor(UV.y * 8.0);
	float along = UV.x * (0.6 + hash(vec2(lane, 3.0)) * 0.8) - TIME * speed * (0.7 + hash(vec2(lane, 7.0)) * 0.6);
	float dash = step(0.5, fract(along + hash(vec2(lane, 1.0))));
	float across = abs(fract(UV.y * 8.0) - 0.5) * 2.0;
	float streak = dash * step(across, 0.5);
	// hoops round it, sliding the same way, so that it reads as one tube between the streaks
	float hoop = step(0.9, fract(UV.x * 0.75 - TIME * speed * 0.5));
	// (nothing of it is drawn right up against the eye)
	if (max(streak, hoop) < 0.5 || -VERTEX.z < clear) {
		discard;
	}
	// (the murk does not hide it, as it is there to be found: it only dims with distance)
	ALBEDO = colour.rgb * strength * mix(0.6, 1.0, streak) * mix(1.0, 0.4, smoothstep(20.0, 130.0, -VERTEX.z));
}
