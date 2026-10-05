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

void sky() {
	float y = EYEDIR.y;
	float g = floor(smoothstep(0.0, 0.65, y) * bands) / bands;
	vec3 col = mix(horizon_color, top_color, g);
	col = mix(col, bottom_color, smoothstep(0.0, -0.15, y));
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
	COLOR = col;
}
