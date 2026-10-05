// Polished platinum lettering, for a PERFECT! callout: the letters are lit like metal (pale
// above, a dark line of horizon across the middle, bright below it) and a gleam runs across
// them. It works in screen space, since the letters of a label share one atlas.
shader_type canvas_item;

// Where on the screen (0 to 1, down the screen) the middle of the lettering is, and how tall
// the lettering is as a share of the screen.
uniform float middle = 0.6;
uniform float tall = 0.08;

void fragment() {
	vec4 glyph = texture(TEXTURE, UV);
	// (the outline is dark: leave it alone, and only plate the face of the letters)
	float face = step(0.5, max(COLOR.r, max(COLOR.g, COLOR.b)));
	float v = clamp((SCREEN_UV.y - middle) / tall + 0.5, 0.0, 1.0);
	vec3 pale = vec3(0.97, 0.98, 1.0);
	vec3 steel = vec3(0.56, 0.6, 0.7);
	// sky above the horizon line, ground below it, as chrome is drawn
	vec3 metal = v < 0.52 ? mix(pale, vec3(0.74, 0.78, 0.86), v / 0.52) : mix(steel, pale, (v - 0.52) / 0.48);
	// the gleam: a slanting band of light that runs across
	float sweep = fract(SCREEN_UV.x * 0.9 - SCREEN_UV.y * 0.35 - TIME * 0.8);
	metal += vec3(1.0) * smoothstep(0.12, 0.0, abs(sweep - 0.5)) * 0.55;
	COLOR = vec4(mix(COLOR.rgb, metal, face), COLOR.a * glyph.a);
}
