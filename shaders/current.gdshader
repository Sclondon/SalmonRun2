// An ocean current: a tube of bright streaks that run along it the way it flows. UV.x is
// metres along it (scaled), UV.y goes once round it.
shader_type spatial;
render_mode unshaded, blend_add, cull_disabled, depth_draw_never, shadows_disabled;

uniform vec4 colour : source_color = vec4(0.35, 0.95, 1.0, 1.0);
uniform float speed = 2.2;
uniform float strength = 1.1;

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

void fragment() {
	// streaks: each lane round the tube has dashes of its own length, sliding along
	float lane = floor(UV.y * 10.0);
	float along = UV.x * (0.6 + hash(vec2(lane, 3.0)) * 0.8) - TIME * speed * (0.7 + hash(vec2(lane, 7.0)) * 0.6);
	float dash = smoothstep(0.55, 0.95, fract(along + hash(vec2(lane, 1.0))));
	float across = abs(fract(UV.y * 10.0) - 0.5) * 2.0;
	float streak = dash * (1.0 - smoothstep(0.3, 0.9, across));
	// a faint body to the tube, so that it reads as one thing between the streaks
	float body = 0.07 + 0.04 * sin(UV.x * 3.0 - TIME * speed * 2.0);
	// (it fades out close to the eye, so that riding inside it does not white out the screen)
	float near = smoothstep(4.0, 16.0, -VERTEX.z);
	ALBEDO = colour.rgb * (streak + body) * strength * near;
}
