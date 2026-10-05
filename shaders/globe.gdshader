// The globe scene: the Earth (a real satellite picture wrapped on a sphere) hanging in space,
// under a drifting layer of cloud and a soft glow of atmosphere, all drawn in big pixels.
// It fills whatever it is given: zooming is the camera closing in, so the globe just gets
// bigger than the picture and nothing is cut off round its edge.
shader_type canvas_item;

uniform sampler2D earth : filter_nearest, repeat_enable;
// Turns the Earth so the place of interest faces the viewer (camera-from-world).
uniform mat3 view = mat3(1.0);
// Size of the picture, where the middle of the globe is in it and how big it is, in pixels.
uniform vec2 rect_size = vec2(400.0);
uniform vec2 center = vec2(200.0);
uniform float globe_radius = 170.0;
// How big the picture's pixels are drawn.
uniform float pixel = 3.0;
// How close the camera is (1 is the whole globe in view): thins the clouds out up close.
uniform float zoom = 1.0;
uniform vec3 space : source_color = vec3(0.012, 0.016, 0.045);
uniform vec3 air : source_color = vec3(0.4, 0.75, 1.0);
uniform float cloud_cover = 0.42;
uniform float cloud_speed = 0.045;
uniform float storm_speed = 0.014;
// How far above the ground the clouds float: the radius of their sphere, with the Earth's as 1.
uniform float cloud_height = 1.07;

const vec3 SUN = vec3(-0.35, 0.4, 0.85);

// A hash built from small multiplications rather than the sine of a big number: the sine
// trick loses its precision on phones and leaves seams and blocks in the noise.
float hash(vec3 p) {
	p = fract(p * 0.3183099 + vec3(0.1, 0.2, 0.3));
	p *= 17.0;
	return fract(p.x * p.y * p.z * (p.x + p.y + p.z));
}

float noise(vec3 p) {
	vec3 i = floor(p);
	vec3 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	return mix(
			mix(mix(hash(i), hash(i + vec3(1, 0, 0)), f.x), mix(hash(i + vec3(0, 1, 0)), hash(i + vec3(1, 1, 0)), f.x), f.y),
			mix(mix(hash(i + vec3(0, 0, 1)), hash(i + vec3(1, 0, 1)), f.x), mix(hash(i + vec3(0, 1, 1)), hash(i + vec3(1, 1, 1)), f.x), f.y),
			f.z);
}

// Hurricanes: where each one sits as (latitude, longitude, size), all in radians. They turn
// anticlockwise north of the equator and clockwise south of it, and track slowly west.
const int STORMS = 3;
const vec3 STORM[3] = {vec3(0.33, 2.36, 0.4), vec3(0.3, -1.6, 0.36), vec3(-0.32, -2.9, 0.38)};

// How far a point is from a storm's eye, in storm radii.
float storm_distance(vec3 world, vec3 storm) {
	float lon = storm.y - TIME * storm_speed;
	vec3 centre = vec3(cos(storm.x) * sin(lon), sin(storm.x), cos(storm.x) * cos(lon));
	return acos(clamp(dot(world, centre), -1.0, 1.0)) / storm.z;
}

float storm_at(vec3 world, vec3 storm) {
	float lon = storm.y - TIME * storm_speed;
	vec3 centre = vec3(cos(storm.x) * sin(lon), sin(storm.x), cos(storm.x) * cos(lon));
	float d = acos(clamp(dot(world, centre), -1.0, 1.0)) / storm.z;
	if (d > 1.15) {
		return 0.0;
	}
	vec3 east = normalize(cross(vec3(0.0, 1.0, 0.0), centre));
	vec3 north = cross(centre, east);
	float angle = atan(dot(world, north), dot(world, east));
	float spin = sign(storm.x);
	// Rough it up: the noise turns with the storm, pushing the bands in and out and tearing
	// holes in them, so it reads as weather rather than a drawn spiral.
	float turn = spin * TIME * 0.12;
	vec2 local = vec2(cos(angle + turn), sin(angle + turn)) * d;
	float rough = noise(vec3(local * 5.0, storm.y * 3.0) + 9.0);
	float fine = noise(vec3(local * 13.0, storm.y * 7.0) + 4.0);
	d += (rough - 0.5) * 0.18;
	// two arms winding in towards a dense middle with a small clear eye
	float arms = sin(angle * 2.0 + spin * (log(max(d, 0.0) + 0.04) * 4.5 - TIME * 0.5) + (rough - 0.5) * 1.4);
	float body = smoothstep(1.0, 0.35, d);
	float core = smoothstep(0.5, 0.22, d);
	float eye = smoothstep(0.04, 0.1, d);
	float cloud = max(smoothstep(-0.2, 0.6, arms) * body, core) * eye;
	return cloud * smoothstep(0.1, 0.42, fine + core * 0.6);
}

// How much cloud there is over a point (a direction from the centre of the Earth).
float cloud_at(vec3 world) {
	// noise on the sphere itself rather than on a flat map, drifting east; kept away from the
	// origin, where the lattice mirrors itself
	float a = TIME * cloud_speed;
	vec3 c = vec3(world.x * cos(a) - world.z * sin(a), world.y * 1.6, world.x * sin(a) + world.z * cos(a)) + 23.0;
	float n = noise(c * 3.2) * 0.6 + noise(c * 7.0 + 11.0) * 0.3 + noise(c * 15.0 + 5.0) * 0.1;
	float cloud = smoothstep(1.0 - cloud_cover, 1.0 - cloud_cover + 0.16, n);
	for (int i = 0; i < STORMS; i++) {
		// a storm sweeps the sky around it clear, so it stands out as one system
		cloud *= smoothstep(0.75, 1.35, storm_distance(world, STORM[i]));
		cloud = max(cloud, storm_at(world, STORM[i]));
	}
	return cloud;
}

void fragment() {
	vec2 cell = floor(UV * rect_size / pixel);
	vec2 px = (cell + 0.5) * pixel;
	vec2 p = (px - center) / globe_radius;
	p.y = -p.y;
	float r2 = dot(p, p);
	mat3 to_world = transpose(view);
	vec3 sun = normalize(SUN);
	// space, with a scatter of stars that stay put as the globe turns
	float star = hash(vec3(cell, 7.0));
	vec3 col = space + vec3(0.9, 0.95, 1.0) * step(0.9965, star) * (0.4 + 0.6 * hash(vec3(cell, 3.0)));
	if (r2 > 1.0) {
		// outside the globe: the atmosphere fading out into space
		float d = (sqrt(r2) - 1.0) * zoom / 0.14;
		col = mix(col, air, pow(clamp(1.0 - d, 0.0, 1.0), 2.5) * 0.55);
	} else {
		vec3 cam = vec3(p, sqrt(1.0 - r2));
		vec3 world = to_world * cam;
		float lat = asin(clamp(world.y, -1.0, 1.0));
		float lon = atan(world.x, world.z);
		vec3 ground = texture(earth, vec2(lon / TAU + 0.5, 0.5 - lat / PI)).rgb;
		// the clouds are up in the air, so their shadows fall away from the sun
		ground *= 1.0 - 0.45 * cloud_at(to_world * normalize(cam * cloud_height + sun * (cloud_height - 1.0) * 2.0));
		// day side towards the top left, and the air thickening towards the edge
		ground *= 0.45 + 0.75 * clamp(dot(cam, sun), 0.0, 1.0);
		col = mix(ground, air, pow(1.0 - cam.z, 2.5) * 0.5);
	}
	// the cloud layer: a bigger sphere than the Earth, so it stands clear of the ground and
	// carries on past the edge of the globe
	float h2 = cloud_height * cloud_height;
	if (r2 < h2) {
		vec3 cam = vec3(p, sqrt(h2 - r2)) / cloud_height;
		// up close the clouds thin out so the map underneath stays readable
		float cloud = cloud_at(to_world * cam) * mix(0.85, 0.3, smoothstep(1.0, 5.0, zoom));
		vec3 white = vec3(1.0) * (0.55 + 0.6 * clamp(dot(cam, sun), 0.0, 1.0));
		col = mix(col, white, cloud);
	}
	COLOR = vec4(col, 1.0);
}
