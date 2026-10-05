// Screen post-process for the low-res 3D view: under water, a swimming picture in the colour
// of the water with shafts of light; then colour quantisation + Bayer dither + vignette.
shader_type canvas_item;

uniform float levels = 28.0;
// How much of the banded, dithered colour is mixed in (0 leaves the picture smooth).
uniform float dither = 0.5;
uniform float vignette = 0.2;
// How far under the water the camera is (0 above the surface, 1 below it), and the colour of
// the water it is in.
uniform float underwater = 0.0;
uniform vec4 water_tint : source_color = vec4(0.16, 0.7, 0.64, 1.0);
// Under water: how far the picture sways (in screen widths), how strongly it is tinted, and
// how bright the shafts of light from the surface are.
uniform float sway = 0.0045;
uniform float tint = 0.42;
uniform float shafts = 0.2;

const float BAYER[16] = float[16](0.0, 8.0, 2.0, 10.0, 12.0, 4.0, 14.0, 6.0,
		3.0, 11.0, 1.0, 9.0, 15.0, 7.0, 13.0, 5.0);

void fragment() {
	vec2 uv = UV;
	// the picture sways, as seen through moving water
	uv += vec2(sin(UV.y * 17.0 + TIME * 2.1), cos(UV.x * 13.0 + TIME * 1.6)) * sway * underwater;
	vec4 c = texture(TEXTURE, clamp(uv, vec2(0.001), vec2(0.999)));
	if (underwater > 0.001) {
		// brightened towards the colour of the water, a little washed out
		vec3 hue = normalize(water_tint.rgb + 0.05) * 1.35;
		float grey = dot(c.rgb, vec3(0.3, 0.5, 0.2));
		vec3 w = mix(c.rgb, vec3(grey), 0.1) * mix(vec3(1.0), hue, tint) + water_tint.rgb * 0.1;
		// slanting shafts of light, brightest at the top of the screen, that drift and flicker
		float across = UV.x + UV.y * 0.4;
		float ray = sin(across * 21.0 + TIME * 0.5) * sin(across * 8.5 - TIME * 0.35) + 0.25 * sin(across * 47.0 + TIME * 1.3);
		w += hue * smoothstep(0.25, 1.0, ray) * (1.0 - UV.y) * (1.0 - UV.y) * shafts;
		// and darker towards the edges and the depths
		vec2 e = UV - vec2(0.5, 0.35);
		w *= 1.0 - dot(e, e) * 0.7;
		c.rgb = mix(c.rgb, w, underwater);
	}
	ivec2 px = ivec2(mod(floor(UV / TEXTURE_PIXEL_SIZE), 4.0));
	float threshold = BAYER[px.y * 4 + px.x] / 16.0;
	c.rgb = mix(c.rgb, floor(c.rgb * levels + threshold) / levels, dither);
	vec2 d = UV - 0.5;
	c.rgb *= 1.0 - dot(d, d) * vignette * 2.0;
	COLOR = vec4(c.rgb, 1.0);
}
