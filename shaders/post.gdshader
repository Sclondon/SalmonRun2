// Screen post-process for the low-res 3D view: colour quantisation + Bayer dither + vignette.
shader_type canvas_item;

uniform float levels = 28.0;
uniform float vignette = 0.35;

const float BAYER[16] = float[16](0.0, 8.0, 2.0, 10.0, 12.0, 4.0, 14.0, 6.0,
		3.0, 11.0, 1.0, 9.0, 15.0, 7.0, 13.0, 5.0);

void fragment() {
	vec4 c = texture(TEXTURE, UV);
	ivec2 px = ivec2(mod(floor(UV / TEXTURE_PIXEL_SIZE), 4.0));
	float threshold = BAYER[px.y * 4 + px.x] / 16.0;
	c.rgb = floor(c.rgb * levels + threshold) / levels;
	vec2 d = UV - 0.5;
	c.rgb *= 1.0 - dot(d, d) * vignette * 2.0;
	COLOR = vec4(c.rgb, 1.0);
}
