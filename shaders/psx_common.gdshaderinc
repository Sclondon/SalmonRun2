// Shared PS1-style helpers: vertex snapping to a coarse screen grid ("wobble").
uniform float snap_res = 200.0;

vec4 psx_snap(vec4 clip, vec2 viewport) {
	vec2 grid = vec2(snap_res * viewport.x / viewport.y, snap_res) * 0.5;
	clip.xy = round(clip.xy / clip.w * grid) / grid * clip.w;
	return clip;
}

// Vertex colours are authored in sRGB.
vec3 srgb_to_linear(vec3 c) {
	return pow(c, vec3(2.2));
}
