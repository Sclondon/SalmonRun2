shader_type spatial;
// The sockeye salmon (sockeye_salmon.gd), at every stage of its life: it swims by a wave down its
// body, its jaw and gill covers work, its fins wave and scull; and every marking is drawn here,
// from the species (the component's README names the references): no texture files. What each
// point is comes from the model (tools/build_sockeye_salmon.py): COLOR.r the part, as a tenth (0
// body, 1 lower jaw, 2 eye, 3 maxilla, 4 dorsal, 5 adipose, 6 tail, 7 anal, 8 pelvic, 9 pectoral).
// On the body UV.x is how far along the fish (0 snout to 1 tail tip), UV.y how high (0 belly line
// to 1 back line), UV2.x how far round the skin from the back line (metres, + right, - left),
// UV2.y the whole way from back line to belly line; COLOR.g the gill cover's moving edge, COLOR.b
// the inside of the mouth. On a fin UV.x is along its rays (0 root to 1 edge), UV.y across it
// counted in rays; UV2 and COLOR.b the way its flat side faces. Nothing here needs more than GL
// Compatibility has.
//
// Everything that moves runs on `phase` (0..1 through one beat, set by SockeyeSalmon): the tail
// beats, the breaths and the fins' sculls each go a whole number of times a beat, so a picture of
// it comes round again exactly.
//
// What it costs (it is drawn on phones): the body's skin is the dear part of fragment(): the
// blotches (`mottle`: three soft-noise lookups), the scales (`scales`: two screen-space
// derivatives), the parr marks and the back's spots (one hash each). Each is skipped when its
// amount is 0, which is what SockeyeSalmon.new_material(stage, true) sets for fish in a pack.
render_mode cull_back, depth_draw_opaque;

// As the models are built: every stage is this long.
const float LENGTH = 0.6;
// How many body lengths one wave of the swimming bend is.
const float WAVE = 0.95;

// Where this stage's lower jaw hinges (how far along the fish, how high, in body lengths) and how
// far along its gill cover's rear edge reaches: the spawning male's by default; set for each stage
// from SockeyeSalmon.STAGES (the build script prints them).
uniform float hinge_s = 0.135;
uniform float hinge_y = -0.034;
uniform float gill_s = 0.236;

// How far through a beat it is (0..1), and how many times in a beat its tail beats, it breathes
// and its pectoral fins scull (whole numbers).
uniform float phase = 0.0;
// Turning (the user, 2026-11-17, of fish swimming tight rounds: "The fish need to bend more"):
// how far the body is bent round to one side behind the head, in radians from the gills to the
// tail (0 straight; more than 0 the tail comes round to +X, its left, as it turns left). The
// head stays as it is; set it from how tightly the fish is turning.
uniform float curl = 0.0;
// The same up and down, for a fish that rears or dives (a charge, a grab): how far the whole body
// is bent about its middle, in radians from snout to tail tip (0 straight; more than 0 its head
// and its tail both come up, less than 0 both go down).
uniform float arch = 0.0;
uniform float tail_beats = 3.0;
uniform float breaths = 2.0;
uniform float sculls = 2.0;
// How hard it is swimming: how far its tail swings (1 is a tenth of its length each way).
uniform float swim = 0.5;
// The mouth: how far open it is held (radians) and how much further each breath opens it. The
// gill covers: how far their edges lift with each breath (metres).
uniform float gape = 0.07;
uniform float gape_breath = 0.08;
uniform float gill_flare = 0.0045;
// How far the pectoral fins scull (1 as it holds its place).
uniform float scull = 1.0;
// For a game: `flash` adds white light to the whole fish (a hit); `rim` lights its edges with
// its own colour so that it stands out (0 none); `snap` (0 off, 1 full) rounds each point to a
// coarse grid on the screen, `snap_res` steps up the screen, as a PlayStation 1 did.
uniform float flash = 0.0;
uniform float rim = 0.0;
uniform float snap = 0.0;
uniform float snap_res = 200.0;

// The colours (the spawning male's by default; SockeyeSalmon.stage sets them all). The body: its
// back, its side, its lower side, the strip along its belly. The head: its cheek and gill cover,
// its top, the snout and upper lip, the lower jaw and throat, the inside of the mouth.
uniform vec3 back : source_color = vec3(0.5, 0.05, 0.04);
uniform vec3 side : source_color = vec3(0.78, 0.07, 0.05);
uniform vec3 low : source_color = vec3(0.86, 0.2, 0.17);
uniform vec3 belly : source_color = vec3(0.92, 0.86, 0.82);
uniform vec3 head : source_color = vec3(0.4, 0.42, 0.13);
uniform vec3 head_top : source_color = vec3(0.17, 0.21, 0.07);
uniform vec3 snout : source_color = vec3(0.07, 0.08, 0.05);
uniform vec3 jaw_pale : source_color = vec3(0.92, 0.9, 0.84);
uniform vec3 mouth : source_color = vec3(0.8, 0.6, 0.58);
uniform vec3 parr : source_color = vec3(0.18, 0.24, 0.22);
uniform vec3 fin_dorsal : source_color = vec3(0.74, 0.2, 0.1);
uniform vec3 fin_adipose : source_color = vec3(0.8, 0.12, 0.08);
uniform vec3 fin_tail : source_color = vec3(0.4, 0.4, 0.16);
uniform vec3 fin_anal : source_color = vec3(0.72, 0.16, 0.1);
uniform vec3 fin_pelvic : source_color = vec3(0.66, 0.17, 0.11);
uniform vec3 fin_pectoral : source_color = vec3(0.42, 0.4, 0.3);
uniform vec3 fin_dark : source_color = vec3(0.1, 0.1, 0.07);
uniform vec3 eye_gold : source_color = vec3(0.88, 0.62, 0.2);
uniform vec3 sheen_colour : source_color = vec3(1.0, 0.72, 0.62);
// How high on the side the back's colour begins (0 belly line to 1 back line); how much the pale
// belly strip gives way to the side's colour towards the tail (1 as a spawner's does, 0 pale all
// the way); how blotchy the skin is; how clearly the scales show; how strong the parr marks (the
// young fish's row of dark ovals along the side) and the small dark spots on the back are; how
// streaked with dark the tail is and how dark its edge; how dark the fins get towards their edges;
// how strong the sheen is.
uniform float back_from = 0.62;
uniform float belly_fade = 1.0;
uniform float mottle = 1.0;
uniform float scales = 0.6;
uniform float parr_amount = 0.0;
uniform float spot_amount = 0.0;
uniform float tail_streaks = 0.75;
uniform float tail_edge = 0.5;
uniform float fin_dusk = 1.0;
uniform float sheen = 0.25;

varying vec3 rest;
varying float part;
varying vec2 extra;


float gill_edge(float h) {
	return gill_s - 0.25 * (h - 0.45) * (h - 0.45);
}


vec4 hash4(vec2 p) {
	vec4 q = fract(p.xyxy * vec4(0.1031, 0.1030, 0.0973, 0.1099));
	q += dot(q, q.wzxy + 33.33);
	return fract((q.xxyz + q.yzzw) * q.zywx);
}


// Soft patches, 0..1, a patch to each 1 of `p`: the skin is not one flat colour.
float cloud(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash4(i).x, hash4(i + vec2(1.0, 0.0)).x, f.x), mix(hash4(i + vec2(0.0, 1.0)).x, hash4(i + vec2(1.0, 1.0)).x, f.x), f.y);
}


// The body behind the head laid round an arc (see `curl`).
void curl_bend(inout vec3 v, inout vec3 n) {
	float from = -0.2 * LENGTH;
	float d = v.z - from;
	if (abs(curl) < 0.001 || d <= 0.0) {
		return;
	}
	float k = curl / (0.7 * LENGTH);
	float a = d * k;
	float r = 1.0 / k;
	float c = cos(a);
	float sn = sin(a);
	n = vec3(n.x * c + n.z * sn, n.y, -n.x * sn + n.z * c);
	v = vec3(r + (v.x - r) * c, v.y, from + (r - v.x) * sn);
}


// The whole body laid round an arc that goes up and down, about its middle (see `arch`).
void arch_bend(inout vec3 v, inout vec3 n) {
	if (abs(arch) < 0.001) {
		return;
	}
	float k = arch / LENGTH;
	float a = v.z * k;
	float r = 1.0 / k;
	float c = cos(a);
	float sn = sin(a);
	n = vec3(n.x, n.y * c + n.z * sn, n.z * c - n.y * sn);
	v = vec3(v.x, r - (r - v.y) * c, (r - v.y) * sn);
}

void vertex() {
	rest = VERTEX;
	part = floor(COLOR.r * 10.0 + 0.5);
	extra = COLOR.gb;
	vec3 v = VERTEX;
	vec3 n = NORMAL;
	float s = v.z / LENGTH + 0.5;
	float side_is = v.x >= 0.0 ? 1.0 : -1.0;
	float breath = phase * TAU * breaths;
	float tail = phase * TAU * tail_beats;
	float wave = tail - TAU * clamp(s, 0.0, 1.05) / WAVE;
	if (part == 1.0) {
		// The lower jaw swings about its hinge behind the eye; the throat behind it stays.
		float a = (gape + gape_breath * (0.5 - 0.5 * cos(breath))) * smoothstep(hinge_s + 0.025, hinge_s - 0.022, s);
		vec2 hinge = vec2(hinge_y, hinge_s - 0.5) * LENGTH;
		vec2 d = v.yz - hinge;
		v.yz = hinge + vec2(d.x * cos(a) + d.y * sin(a), d.y * cos(a) - d.x * sin(a));
		n.yz = vec2(n.y * cos(a) + n.z * sin(a), n.z * cos(a) - n.y * sin(a));
	} else if (part == 0.0) {
		// The gill covers lift at their rear edges, a little after the mouth opens.
		v.x += side_is * COLOR.g * gill_flare * (0.5 - 0.5 * cos(breath - 1.3));
	} else if (part >= 4.0) {
		// A fin waves the way its flat side faces, more towards its edge.
		vec3 flat_way = normalize(vec3(UV2.x, UV2.y, COLOR.b * 2.0 - 1.0));
		float r = UV.x;
		float turn = phase * TAU * sculls;
		if (part == 9.0) {
			// the pectorals scull, one a little after the other, the stroke running out to the edge
			float a = turn + (side_is > 0.0 ? 0.0 : 1.3);
			// (more out from the body than in towards it: tools/build_sockeye_salmon.py measures the gap left)
			v += flat_way * LENGTH * 0.03 * scull * (r * (sin(a) + 0.35) + 0.7 * r * r * sin(a - 1.2));
		} else if (part == 8.0) {
			float a = turn + (side_is > 0.0 ? 2.2 : 3.3);
			v += flat_way * LENGTH * 0.012 * scull * r * r * sin(a - UV.y * 0.25);
		} else if (part == 6.0) {
			// (the tail's edge lags behind the bend that carries it)
			v.x += LENGTH * 0.022 * swim * r * r * sin(wave - 1.1);
		} else {
			v.x += LENGTH * 0.014 * swim * r * r * sin(wave - 1.0 - UV.y * 0.2);
		}
	}
	// The swimming bend: a wave that runs from head to tail, the head nearly still and the tail
	// swinging widest. Each place is carried sideways and turned to lie along the bent body, so
	// that the fins and the tail follow it.
	float sb = clamp(v.z / LENGTH + 0.5, 0.0, 1.05);
	float reach = 0.012 - 0.05 * sb + 0.14 * sb * sb;
	float reach_slope = -0.05 + 0.28 * sb;
	float w = tail - TAU * sb / WAVE;
	float off = LENGTH * swim * reach * sin(w);
	float slope = swim * (reach_slope * sin(w) - reach * TAU / WAVE * cos(w));
	vec3 along = normalize(vec3(slope, 0.0, 1.0));
	vec3 across = vec3(along.z, 0.0, -along.x);
	v = vec3(off, v.y, v.z) + across * v.x;
	n = across * n.x + vec3(0.0, n.y, 0.0) + along * n.z;
	VERTEX = v;
	NORMAL = normalize(n);
	vec3 curled = VERTEX;
	vec3 curled_normal = NORMAL;
	curl_bend(curled, curled_normal);
	arch_bend(curled, curled_normal);
	VERTEX = curled;
	NORMAL = curled_normal;
	// The coarse screen grid (see `snap`), as Salmon Run 2's psx_snap does it.
	vec4 clip = PROJECTION_MATRIX * (MODELVIEW_MATRIX * vec4(VERTEX, 1.0));
	vec2 grid = vec2(snap_res * VIEWPORT_SIZE.x / VIEWPORT_SIZE.y, snap_res) * 0.5;
	clip.xy = mix(clip.xy, round(clip.xy / clip.w * grid) / grid * clip.w, snap);
	POSITION = clip;
}


// The colour of the body's skin at a place: `s` along, `h` up.
vec3 skin(float s, float h) {
	// (the pale strip along the belly runs from the throat to the anal fin)
	float pale = 1.0 - belly_fade * smoothstep(0.6, 0.78, s);
	vec3 c = mix(mix(low, belly, pale), low, smoothstep(0.03, 0.13, h));
	c = mix(c, side, smoothstep(0.1, 0.36, h));
	c = mix(c, back, smoothstep(back_from, back_from + 0.3, h));
	return c;
}


void fragment() {
	vec3 c = side;
	float rough = 0.36;
	float glint = sheen;
	float seen = clamp(dot(normalize(NORMAL), normalize(VIEW)), 0.0, 1.0);
	if (part < 0.5) {
		float s = UV.x;
		float h = UV.y;
		float girth = max(UV2.y, 0.001);
		vec2 p = vec2(rest.z, UV2.x);
		float round_it = abs(UV2.x) / girth;
		float edge = gill_edge(h);
		float on_head = 1.0 - smoothstep(edge - 0.003, edge + 0.002, s);
		c = skin(s, h);
		if (mottle > 0.0) {
			// (blotched a little, in big soft patches and small ones)
			float patches = 0.62 * cloud(p / 0.045) + 0.38 * cloud(p / 0.013 + 7.3);
			c *= mix(1.0, 0.8 + 0.34 * patches, mottle * (1.0 - smoothstep(0.8, 0.95, round_it)));
		}
		// The lateral line.
		float along_body = smoothstep(gill_s, gill_s + 0.05, s) * (1.0 - smoothstep(0.8, 0.87, s));
		c *= 1.0 - 0.1 * along_body * (1.0 - smoothstep(0.003, 0.007, abs(h - 0.5)));
		if (parr_amount > 0.0) {
			// The parr marks: a row of short dark upright ovals, uneven in height and place, lying
			// mostly above the lateral line.
			float from = gill_s + 0.045;
			float pitch = (0.83 - from) / 9.0;
			float mark = clamp(floor((s - from) / pitch + 0.5), 0.0, 9.0);
			vec4 mr = hash4(vec2(mark, 7.0));
			vec2 md = vec2((s - from - mark * pitch - (mr.x - 0.5) * 0.3 * pitch) / (pitch * (0.2 + 0.1 * mr.y)), (h - 0.57 - (mr.z - 0.5) * 0.09) / (0.13 + 0.07 * mr.w));
			c = mix(c, parr, parr_amount * (1.0 - smoothstep(0.3, 1.0, dot(md, md))));
		}
		if (spot_amount > 0.0) {
			// Small dark spots scattered over the back.
			float cell = 0.011;
			vec2 id = floor(p / cell);
			vec4 r = hash4(id);
			float away = length(p - (id + 0.5 + (r.xy - 0.5) * 0.4) * cell);
			float size = cell * (0.15 + 0.1 * r.w);
			float there = step(r.z, 0.55) * smoothstep(0.66, 0.8, h) * smoothstep(gill_s - 0.06, gill_s + 0.02, s) * (1.0 - smoothstep(0.8, 0.86, s));
			c = mix(c, parr, spot_amount * there * (1.0 - smoothstep(size * 0.7, size, away)));
		}
		if (scales > 0.0) {
			// The scales: in rows, seen only close.
			vec2 sc = p / 0.0032;
			sc.x += 0.5 * mod(floor(sc.y), 2.0);
			// (each a crescent: the free rear edge of a scale)
			vec2 in_scale = fract(sc) - 0.5;
			float scale_edge = smoothstep(0.28, 0.5, length(in_scale)) * smoothstep(-0.25, 0.25, in_scale.x);
			float fine = 1.0 - smoothstep(0.25, 0.7, fwidth(sc.x) + fwidth(sc.y));
			float scaled = scales * (1.0 - smoothstep(0.82, 0.95, round_it)) * fine * (1.0 - smoothstep(0.85, 0.875, s)) * (1.0 - on_head);
			c *= 1.0 - 0.09 * scale_edge * scaled;
			rough += 0.08 * scale_edge * scaled;
		}
		// The head: dark on top, dark over the snout and along the upper lip, pale under the
		// throat; it ends at the gill cover's rear edge, a dark crescent, where the body's colour
		// begins.
		vec3 hc = mix(head, head_top, smoothstep(0.5, 0.86, h));
		// (the throat, under the gill covers)
		hc = mix(hc, jaw_pale, smoothstep(hinge_s + 0.012, hinge_s + 0.04, s) * (1.0 - smoothstep(0.07, 0.2, h)));
		// (the snout, and the upper lip back to the corner of the mouth)
		float dark = 1.0 - smoothstep(0.22 * hinge_s, 0.63 * hinge_s, s);
		dark = max(dark, (1.0 - smoothstep(0.1, 0.34, h)) * (1.0 - smoothstep(hinge_s - 0.02, hinge_s + 0.01, s)));
		hc = mix(hc, snout, 0.85 * dark);
		// (the line of the cheek plate ahead of the gill cover)
		hc *= 1.0 - 0.3 * exp(-pow((s - edge + 0.21 * gill_s + 0.03 * (h - 0.45)) / 0.003, 2.0)) * smoothstep(0.14, 0.24, h) * (1.0 - smoothstep(0.55, 0.68, h));
		c = mix(c, hc, on_head);
		c *= 1.0 - 0.6 * exp(-pow((s - edge - 0.002) / 0.003, 2.0)) * smoothstep(0.06, 0.18, h) * (1.0 - smoothstep(0.78, 0.92, h));
		// (where the skin runs out over the root of the tail it takes the tail's colour, as the tail does there)
		c = mix(c, fin_tail, smoothstep(0.871, 0.915, s));
		// The inside of the mouth.
		c = mix(c, mouth, extra.y);
		glint *= smoothstep(0.1, 0.3, h) * (1.0 - extra.y);
	} else if (part < 1.5) {
		// The lower jaw: pale, dark along the lip and over its tip.
		float s = UV.x;
		float h = UV.y;
		float dark = smoothstep(0.62, 0.95, h) * (1.0 - smoothstep(hinge_s - 0.01, hinge_s + 0.02, s));
		dark = max(dark, 0.6 * (1.0 - smoothstep(0.23 * hinge_s, 0.385 * hinge_s, s)));
		c = mix(jaw_pale, snout, 0.7 * dark);
		c = mix(c, mouth, extra.y);
		glint *= 0.3;
	} else if (part < 2.5) {
		// An eye: a dark pupil in a gold ring, dark at the rim.
		vec2 on_eye = UV * 2.0 - 1.0;
		float r = length(on_eye);
		// (the gold darker above, and brightest next to the pupil)
		float above = smoothstep(-0.3, 0.9, on_eye.x / max(r, 0.001));
		c = mix(eye_gold, eye_gold * 0.45, 0.6 * above * smoothstep(0.4, 0.58, r));
		c = mix(c, vec3(0.04, 0.035, 0.03), smoothstep(0.6, 0.7, r));
		c = mix(c, vec3(1.0, 0.92, 0.62), 0.45 * (1.0 - smoothstep(0.38, 0.48, r)));
		c = mix(c, vec3(0.01), 1.0 - smoothstep(0.32, 0.36, r));
		rough = 0.06;
		glint = 0.0;
	} else if (part < 3.5) {
		// A maxilla, the plate along the upper lip: dark as the snout, paler along its lower edge.
		c = mix(mix(jaw_pale, head, 0.6), mix(head, snout, 0.75), smoothstep(0.2, 0.7, UV.y));
		glint *= 0.5;
	} else {
		// A fin: its rays as fine lines that fork towards the edge.
		float r = UV.x;
		float ty = UV.y;
		float between = abs(fract(ty) - 0.5) * 2.0;
		float between_fine = abs(fract(ty * 2.0) - 0.5) * 2.0;
		float lines = mix(smoothstep(0.55, 1.0, between), smoothstep(0.5, 1.0, between_fine), smoothstep(0.45, 0.7, r));
		lines *= smoothstep(0.03, 0.25, r) * (part > 5.5 && part < 6.5 ? smoothstep(0.2, 0.5, r) : 1.0);
		if (part > 8.5) {
			// The pectoral fins: paler at the root, darkest towards the edge.
			c = mix(mix(fin_pectoral, jaw_pale, 0.35), fin_pectoral, smoothstep(0.0, 0.3, r));
			c = mix(c, fin_dark, 0.6 * fin_dusk * smoothstep(0.35, 1.0, r));
		} else if (part > 7.5) {
			// The pelvic fins.
			c = mix(mix(fin_pelvic, jaw_pale, 0.3), fin_pelvic, smoothstep(0.0, 0.3, r));
			c = mix(c, fin_dark, 0.4 * fin_dusk * smoothstep(0.45, 1.0, r));
		} else if (part > 6.5) {
			// The anal fin: dusky towards its edge and its rear.
			c = mix(low, fin_anal, smoothstep(0.0, 0.3, r));
			c = mix(c, fin_dark, 0.45 * fin_dusk * smoothstep(0.5, 1.0, r) * smoothstep(1.0, 7.0, ty));
		} else if (part > 5.5) {
			// The tail: the colour of the body at its root, then its own, streaked with dark
			// along its rays, dark at its edge.
			float t = ty / 19.0;
			c = mix(skin(0.9, 1.0 - t), fin_tail, smoothstep(0.1, 0.45, r));
			if (tail_streaks > 0.0) {
				float streak = 0.6 * cloud(vec2(r * 3.6, ty * 1.9 + 3.0)) + 0.4 * cloud(vec2(r * 9.0 + 5.0, ty * 3.1));
				c = mix(c, fin_dark, tail_streaks * smoothstep(0.42, 0.7, streak) * smoothstep(0.2, 0.5, r));
			}
			c = mix(c, fin_dark, min(tail_edge, 1.0) * smoothstep(0.92 - 0.12 * tail_edge, 1.0, r));
		} else if (part > 4.5) {
			// The adipose fin: dark at its edge.
			c = mix(back, fin_adipose, smoothstep(0.0, 0.4, r));
			c = mix(c, fin_adipose * 0.45, smoothstep(0.75, 0.98, r));
			lines = 0.0;
		} else {
			// The dorsal fin: the back's colour at its root, dusky towards its edge.
			c = mix(back, fin_dorsal, smoothstep(0.0, 0.35, r));
			c = mix(c, fin_dark, 0.35 * fin_dusk * smoothstep(0.55, 1.0, r));
		}
		c *= 1.0 - 0.25 * lines;
		rough = 0.45;
		glint *= 0.4;
	}
	// The sheen: the skin's shine where it is seen aslant.
	float aslant = pow(1.0 - seen, 3.0);
	c += sheen_colour * glint * aslant;
	ALBEDO = c;
	ROUGHNESS = rough;
	SPECULAR = 0.5;
	EMISSION = c * (rim * 0.8 * aslant) + vec3(flash);
}
