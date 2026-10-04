extends RefCounted
## The journey home, one level per stage of the salmon run: out of the deep ocean, over the
## shallows, into the river mouth, up through the jungle and the mountains to the lake where
## it all started. Each entry is everything that makes a level look and play differently;
## track.gd builds the course from it and world.gd the sky and light.
##
## profile: the bank, as [distance from the water's edge, height above the water, noise 1, noise 2]
##          points going outwards. bank_colors has one colour per segment between them.
## sea_from: open water carries on from this far past the edge (ocean, reef and lake levels).
## uphill:  swum upstream: the water climbs, and waterfalls are steps you have to leap up.
## spring:  settings that change on the way back down. The run up is late summer and autumn
##          (August to November); the young go to sea in spring.
## at:      where on Earth it is, as (latitude, longitude), for the globe.
## kinds:   what the course is made of ("ramps", "rails", "rocks", "rings", "predators").
## scatter: [mesh, chance, nearest, farthest, smallest, biggest, sink, mode] dressing rules;
##          mode "bank" sits on the bank, "water" floats, "far" is a backdrop every 40 m.

const JUNGLE := 3

const LIST: Array[Dictionary] = [
	{
		"name": "DEEP OCEAN", "at": Vector2(40, -175), "tier": 0, "lane": 0, "salt": true,
		"objective": {"type": "rings", "n": 12},
		"tagline": "SOMETHING IS CALLING YOU HOME",
		"seed": 4101, "length": 2600.0,
		"width": 27.0, "slope": 0.0, "curve": 0.3,
		"kinds": ["ramps", "rings", "rocks", "predators", "ramps", "rails"],
		"falls_every": 0.0, "predator": "shark", "predator_word": "CHOMPED!",
		"profile": [[-0.5, -1.2, 0, 0], [4.0, -3.0, 0, 0], [60.0, -3.0, 0, 0], [170.0, -3.0, 0, 0]],
		"bank_colors": [Color(0.02, 0.06, 0.14), Color(0.02, 0.05, 0.12), Color(0.02, 0.05, 0.12)],
		"bed": Color(0.02, 0.07, 0.15), "cliff": Color(0.3, 0.35, 0.42),
		"sea_from": 0.8, "markers": [Color(0.9, 0.2, 0.15), Color(1.0, 0.5, 0.2)],
		"rock": Color(0.78, 0.9, 1.0), "rock_cap": Color(1.0, 1.0, 1.0),
		"ramp": Color(0.05, 0.25, 0.45), "ramp_top": Color(0.75, 0.93, 1.0),
		"rail": Color(0.85, 0.5, 0.15), "rail_node": Color(0.95, 0.95, 0.9),
		"arch": Color(0.5, 0.62, 0.72), "ruins": false,
		"scatter": [
			["floe", 0.35, 3.0, 60.0, 0.6, 1.8, 0.0, "water"],
			["iceberg", 0.07, 22.0, 120.0, 0.8, 2.6, 0.0, "water"],
			["iceberg", 0.5, 110.0, 160.0, 2.5, 5.0, 0.0, "far"],
		],
		"sky_top": Color(0.01, 0.02, 0.10), "sky_horizon": Color(0.10, 0.34, 0.48),
		"sky_bottom": Color(0.03, 0.12, 0.20), "sun": Color(0.85, 0.95, 1.0), "sun_dir": Vector3(0.25, 0.3, -1.0),
		"fog": Color(0.06, 0.2, 0.3), "fog_density": 0.011,
		"ambient": Color(0.35, 0.5, 0.8), "ambient_energy": 0.85,
		"light": Color(0.65, 0.8, 1.0), "light_energy": 0.9,
		"water_deep": Color(0.01, 0.06, 0.18), "water_shallow": Color(0.04, 0.24, 0.42),
		"water_beat": Color(0.2, 0.7, 1.0), "swell": 3.0,
		"motes": Color(0.4, 0.9, 1.0),
	},
	{
		"name": "SHALLOW SEA", "at": Vector2(58, -170), "tier": 1, "lane": 0, "salt": true,
		"objective": {"type": "on_beat", "n": 5},
		"tagline": "WARM WATER, BRIGHT REEF",
		"seed": 5202, "length": 2800.0,
		"width": 26.0, "slope": 0.0, "curve": 0.5,
		"kinds": ["rings", "rocks", "ramps", "rails", "predators", "ramps"],
		"falls_every": 0.0, "predator": "shark", "predator_word": "CHOMPED!",
		"profile": [[-0.5, -1.2, 0, 0], [3.0, 0.4, 0.3, 0], [8.0, 1.3, 0.5, 0.4], [14.0, 0.1, 0.3, 0],
				[22.0, -1.6, 0, 0], [170.0, -2.2, 0, 0]],
		"bank_colors": [Color(0.86, 0.8, 0.58), Color(0.95, 0.9, 0.68), Color(0.9, 0.84, 0.62),
				Color(0.62, 0.72, 0.56), Color(0.5, 0.68, 0.58)],
		"bed": Color(0.7, 0.74, 0.55), "cliff": Color(0.7, 0.66, 0.55),
		"sea_from": 14.5,
		"rock": Color(1.0, 0.45, 0.5), "rock_cap": Color(1.0, 0.75, 0.3),
		"ramp": Color(0.8, 0.72, 0.52), "ramp_top": Color(1.0, 0.55, 0.5),
		"rail": Color(0.75, 0.6, 0.4), "rail_node": Color(0.5, 0.38, 0.25),
		"arch": Color(0.88, 0.8, 0.62), "ruins": false,
		"scatter": [
			["palm", 0.14, 4.0, 11.0, 0.7, 1.1, -0.3, "bank"],
			["grass", 0.3, 3.0, 12.0, 0.7, 1.2, -0.1, "bank"],
			["coral", 0.5, -2.5, 0.5, 0.7, 1.4, -0.9, "water"],
			["coral", 0.4, 17.0, 50.0, 1.0, 2.2, -0.9, "water"],
			["stack", 0.08, 30.0, 110.0, 0.9, 2.4, -1.0, "water"],
			["stack", 0.5, 100.0, 160.0, 2.0, 4.0, -1.0, "far"],
		],
		"sky_top": Color(0.08, 0.32, 0.85), "sky_horizon": Color(0.65, 0.93, 0.96),
		"sky_bottom": Color(0.2, 0.7, 0.72), "sun": Color(1.0, 0.97, 0.8), "sun_dir": Vector3(-0.3, 0.5, -1.0),
		"fog": Color(0.6, 0.9, 0.93), "fog_density": 0.008,
		"ambient": Color(0.75, 0.88, 0.95), "ambient_energy": 0.95,
		"light": Color(1.0, 0.97, 0.88), "light_energy": 1.35,
		"water_deep": Color(0.02, 0.45, 0.58), "water_shallow": Color(0.3, 0.92, 0.82),
		"water_beat": Color(0.5, 1.0, 0.9), "swell": 1.5,
		"motes": Color(1.0, 1.0, 0.8),
	},
	{
		"name": "THE COAST", "at": Vector2(57, -135), "tier": 2, "lane": 0, "salt": false,
		"objective": {"type": "clean", "n": 2},
		"tagline": "YOU CAN SMELL THE RIVER FROM HERE",
		"seed": 6303, "length": 3000.0,
		"width": 25.0, "slope": 0.004, "curve": 0.7, "uphill": true,
		"kinds": ["ramps", "rails", "rocks", "rings", "predators", "rails"],
		"falls_every": 0.0, "predator": "shark", "predator_word": "CHOMPED!",
		"profile": [[-0.5, -1.2, 0, 0], [4.0, 0.4, 0.2, 0], [15.0, 1.3, 0.4, 0.5], [28.0, 3.8, 1.5, 1.5],
				[42.0, 6.5, 1.0, 3.0], [72.0, 17.0, 0, 6.0]],
		"bank_colors": [Color(0.78, 0.7, 0.5), Color(0.94, 0.86, 0.62), Color(0.9, 0.82, 0.58),
				Color(0.62, 0.68, 0.36), Color(0.36, 0.52, 0.26)],
		"bed": Color(0.6, 0.56, 0.4), "cliff": Color(0.6, 0.55, 0.45),
		"rock": Color(0.42, 0.4, 0.4), "rock_cap": Color(0.25, 0.42, 0.3),
		"ramp": Color(0.5, 0.38, 0.26), "ramp_top": Color(0.72, 0.58, 0.4),
		"rail": Color(0.62, 0.52, 0.42), "rail_node": Color(0.4, 0.32, 0.25),
		"arch": Color(0.8, 0.72, 0.58), "ruins": false,
		"scatter": [
			["palm", 0.45, 6.0, 30.0, 0.8, 1.3, -0.3, "bank"],
			["grass", 0.8, 9.0, 34.0, 0.8, 1.5, -0.1, "bank"],
			["umbrella", 0.12, 4.0, 13.0, 0.9, 1.2, 0.0, "bank"],
			["driftwood", 0.15, 1.0, 9.0, 0.7, 1.4, 0.1, "bank"],
			["rock", 0.1, 0.0, 5.0, 0.6, 1.6, -0.3, "bank"],
			["bush", 0.5, 28.0, 60.0, 0.9, 1.8, -0.3, "bank"],
			["tree", 0.3, 40.0, 66.0, 0.9, 1.5, -0.4, "bank"],
			["grass", 0.3, -1.5, 0.5, 0.8, 1.2, 0.0, "water"],
			["hill", 0.6, 80.0, 170.0, 1.0, 1.0, 0.0, "far"],
		],
		"hill": Color(0.3, 0.42, 0.22),
		"sky_top": Color(0.2, 0.3, 0.62), "sky_horizon": Color(1.0, 0.72, 0.42),
		"sky_bottom": Color(0.5, 0.42, 0.3), "sun": Color(1.0, 0.86, 0.5), "sun_dir": Vector3(0.0, 0.2, -1.0),
		"fog": Color(0.96, 0.72, 0.5), "fog_density": 0.005,
		"ambient": Color(0.7, 0.62, 0.6), "ambient_energy": 0.8,
		"light": Color(1.0, 0.88, 0.68), "light_energy": 1.25,
		"water_deep": Color(0.04, 0.3, 0.42), "water_shallow": Color(0.3, 0.72, 0.68),
		"water_beat": Color(1.0, 0.8, 0.4), "swell": 1.2,
		"motes": Color(1.0, 0.9, 0.6),
	},
	{
		"name": "JUNGLE FALLS", "at": Vector2(47.5, -123.5), "tier": 3, "lane": 0, "salt": false,
		"objective": {"type": "rings", "n": 14},
		"tagline": "UPSTREAM NOW. LEAP THE FALLS, MIND THE BEARS",
		"seed": 1987, "length": 3400.0,
		"width": 24.0, "slope": 0.03, "curve": 1.0,
		"kinds": ["ramps", "rails", "rocks", "rings", "ramps", "rails"],
		"falls_every": 420.0, "uphill": true, "predator": "bear", "predator_word": "BEAR'D!",
		"profile": [[-0.5, -1.2, 0, 0], [2.5, 0.6, 0.4, 0], [7.0, 2.4, 1.5, 1.0], [15.0, 4.0, 0, 3.0],
				[27.0, 7.0, 2.0, 5.0], [46.0, 18.0, 0, 6.0]],
		"bank_colors": [Color(0.38, 0.29, 0.18), Color(0.42, 0.48, 0.2), Color(0.22, 0.46, 0.15),
				Color(0.16, 0.38, 0.13), Color(0.11, 0.3, 0.12)],
		"bed": Color(0.34, 0.3, 0.22), "cliff": Color(0.42, 0.4, 0.38),
		"rock": Color(0.46, 0.44, 0.40), "rock_cap": Color(0.28, 0.48, 0.18),
		"ramp": Color(0.48, 0.44, 0.38), "ramp_top": Color(0.32, 0.5, 0.22),
		"rail": Color(0.5, 0.66, 0.22), "rail_node": Color(0.36, 0.5, 0.16),
		"arch": Color(0.55, 0.52, 0.44), "ruins": true,
		"scatter": [
			["tree", 0.85, 7.0, 42.0, 0.8, 1.4, -0.4, "bank"],
			["tree", 0.5, 40.0, 46.0, 1.5, 2.1, -0.4, "bank"],
			["palm", 0.3, 2.5, 9.0, 0.8, 1.2, -0.3, "bank"],
			["fern", 0.9, 1.5, 10.0, 0.8, 1.4, -0.1, "bank"],
			["bush", 0.5, 5.0, 25.0, 0.8, 1.5, -0.3, "bank"],
			["rock", 0.12, 0.0, 4.0, 0.6, 1.8, -0.3, "bank"],
			["flower", 0.3, 2.0, 14.0, 0.9, 1.4, 0.0, "bank"],
			["shroom", 0.15, 3.0, 20.0, 0.8, 1.6, 0.0, "bank"],
			["reeds", 0.35, -1.5, 0.5, 0.8, 1.3, 0.0, "water"],
			["lily", 0.1, -5.0, -1.5, 0.8, 1.4, 0.04, "water"],
			["hill", 0.6, 70.0, 160.0, 1.0, 1.0, 0.0, "far"],
		],
		"hill": Color(0.08, 0.26, 0.14),
		"sky_top": Color(0.10, 0.05, 0.24), "sky_horizon": Color(1.0, 0.42, 0.36),
		"sky_bottom": Color(0.04, 0.16, 0.12), "sun": Color(1.0, 0.82, 0.35), "sun_dir": Vector3(0.0, 0.12, -1.0),
		"fog": Color(0.85, 0.5, 0.55), "fog_density": 0.0055,
		"ambient": Color(0.55, 0.5, 0.7), "ambient_energy": 0.7,
		"light": Color(1.0, 0.86, 0.7), "light_energy": 1.15,
		"water_deep": Color(0.03, 0.30, 0.36), "water_shallow": Color(0.16, 0.70, 0.64),
		"water_beat": Color(0.25, 1.0, 0.8), "swell": 1.0,
		"motes": Color(0.8, 1.0, 0.4),
	},
	{
		"name": "ALPINE RUN", "at": Vector2(52, -117), "tier": 4, "lane": 0, "salt": false,
		"objective": {"type": "rings", "n": 14},
		"tagline": "COLD, FAST AND STEEP",
		"seed": 7405, "length": 3200.0,
		"width": 21.0, "slope": 0.045, "curve": 1.15,
		"kinds": ["rocks", "ramps", "rails", "rocks", "rings", "ramps"],
		"falls_every": 300.0, "uphill": true, "predator": "bear", "predator_word": "BEAR'D!",
		"profile": [[-0.5, -1.2, 0, 0], [1.5, 1.0, 0.5, 0], [5.0, 4.5, 2.0, 1.0], [12.0, 9.0, 2.0, 3.0],
				[26.0, 16.0, 3.0, 6.0], [52.0, 34.0, 0, 10.0]],
		# the run up is late summer into autumn: gold grass, larches turning, bare peaks
		"bank_colors": [Color(0.44, 0.44, 0.46), Color(0.5, 0.5, 0.52), Color(0.62, 0.54, 0.26),
				Color(0.52, 0.38, 0.18), Color(0.46, 0.46, 0.5)],
		"bed": Color(0.36, 0.38, 0.42), "cliff": Color(0.5, 0.5, 0.54),
		"rock": Color(0.52, 0.52, 0.56), "rock_cap": Color(0.62, 0.56, 0.3),
		"ramp": Color(0.5, 0.5, 0.54), "ramp_top": Color(0.66, 0.6, 0.42),
		"rail": Color(0.45, 0.32, 0.2), "rail_node": Color(0.3, 0.22, 0.14),
		"arch": Color(0.52, 0.52, 0.56), "ruins": false,
		"scatter": [
			["pine", 0.65, 6.0, 46.0, 0.8, 1.4, -0.5, "bank"],
			["larch", 0.45, 5.0, 46.0, 0.7, 1.3, -0.5, "bank"],
			["pine", 0.5, 40.0, 52.0, 1.3, 1.9, -0.5, "bank"],
			["rock", 0.4, 0.0, 9.0, 0.8, 2.6, -0.4, "bank"],
			["bush", 0.25, 4.0, 22.0, 0.6, 1.1, -0.3, "bank"],
			["mountain", 0.7, 90.0, 190.0, 1.0, 1.0, 0.0, "far"],
		],
		"hill": Color(0.4, 0.42, 0.48), "peak": Color(0.6, 0.6, 0.66), "snow": 0.0,
		# the way back down is spring: snowmelt, new green, flowers, snow still on the tops
		"spring": {
			"bank_colors": [Color(0.44, 0.44, 0.46), Color(0.5, 0.5, 0.52), Color(0.36, 0.56, 0.3),
					Color(0.26, 0.44, 0.3), Color(0.82, 0.86, 0.92)],
			"rock_cap": Color(0.95, 0.97, 1.0), "ramp_top": Color(0.4, 0.6, 0.34),
			"scatter": [
				["pine", 0.9, 6.0, 46.0, 0.8, 1.4, -0.5, "bank"],
				["pine", 0.5, 40.0, 52.0, 1.3, 1.9, -0.5, "bank"],
				["rock", 0.4, 0.0, 9.0, 0.8, 2.6, -0.4, "bank"],
				["bush", 0.3, 4.0, 22.0, 0.6, 1.1, -0.3, "bank"],
				["flower", 0.7, 2.0, 16.0, 0.8, 1.3, 0.0, "bank"],
				["mountain", 0.7, 90.0, 190.0, 1.0, 1.0, 0.0, "far"],
			],
			"peak": Color(0.94, 0.96, 1.0), "snow": 0.3,
			"water_shallow": Color(0.66, 0.88, 0.88), "motes": Color(1.0, 1.0, 1.0),
		},
		"sky_top": Color(0.10, 0.28, 0.78), "sky_horizon": Color(0.78, 0.9, 1.0),
		"sky_bottom": Color(0.3, 0.4, 0.46), "sun": Color(1.0, 1.0, 0.9), "sun_dir": Vector3(0.35, 0.42, -1.0),
		"fog": Color(0.76, 0.86, 0.96), "fog_density": 0.006,
		"ambient": Color(0.62, 0.72, 0.9), "ambient_energy": 0.85,
		"light": Color(1.0, 0.98, 0.92), "light_energy": 1.3,
		"water_deep": Color(0.05, 0.26, 0.42), "water_shallow": Color(0.5, 0.84, 0.88),
		"water_beat": Color(0.6, 0.95, 1.0), "swell": 1.0,
		"motes": Color(1.0, 1.0, 1.0),
	},
	{
		"name": "THE HOME LAKE", "at": Vector2(44, -115), "tier": 5, "lane": 0, "salt": false,
		"tagline": "WHERE IT ALL BEGAN",
		"seed": 8506, "length": 2400.0,
		"width": 28.0, "slope": 0.0, "curve": 0.3,
		"kinds": ["rings", "ramps", "rails", "ramps", "rings", "rails"],
		"falls_every": 0.0, "predator": "", "predator_word": "",
		"profile": [[-0.5, -1.2, 0, 0], [4.0, -2.0, 0, 0], [58.0, -2.0, 0, 0], [66.0, 0.6, 0.4, 0.5],
				[84.0, 5.0, 2.0, 3.0], [125.0, 24.0, 0, 8.0]],
		"bank_colors": [Color(0.3, 0.32, 0.4), Color(0.28, 0.3, 0.4), Color(0.5, 0.48, 0.5),
				Color(0.56, 0.46, 0.24), Color(0.46, 0.42, 0.46)],
		"bed": Color(0.4, 0.4, 0.46), "cliff": Color(0.5, 0.5, 0.54),
		"sea_from": 0.8, "sea_to": 64.0, "markers": [Color(0.42, 0.3, 0.2), Color(1.0, 0.8, 0.4)],
		"rock": Color(0.5, 0.5, 0.55), "rock_cap": Color(0.6, 0.54, 0.32),
		"ramp": Color(0.42, 0.3, 0.2), "ramp_top": Color(0.62, 0.48, 0.32),
		"rail": Color(0.45, 0.32, 0.2), "rail_node": Color(0.3, 0.22, 0.14),
		"arch": Color(0.55, 0.52, 0.56), "ruins": false,
		"scatter": [
			["pine", 0.6, 66.0, 120.0, 0.9, 1.6, -0.5, "bank"],
			["larch", 0.45, 66.0, 110.0, 0.8, 1.4, -0.5, "bank"],
			["rock", 0.25, 62.0, 80.0, 0.8, 2.4, -0.4, "bank"],
			["lily", 0.12, 3.0, 40.0, 0.9, 1.6, 0.04, "water"],
			["reeds", 0.2, 4.0, 60.0, 0.8, 1.4, 0.0, "water"],
			["mountain", 0.9, 130.0, 210.0, 1.0, 1.0, 0.0, "far"],
		],
		"hill": Color(0.36, 0.34, 0.46), "peak": Color(0.62, 0.58, 0.68), "snow": 0.0,
		"spring": {
			"bank_colors": [Color(0.3, 0.32, 0.4), Color(0.28, 0.3, 0.4), Color(0.5, 0.48, 0.5),
					Color(0.3, 0.5, 0.32), Color(0.8, 0.82, 0.92)],
			"rock_cap": Color(0.95, 0.97, 1.0),
			"scatter": [
				["pine", 0.8, 66.0, 120.0, 0.9, 1.6, -0.5, "bank"],
				["flower", 0.5, 62.0, 80.0, 0.9, 1.4, 0.0, "bank"],
				["rock", 0.25, 62.0, 80.0, 0.8, 2.4, -0.4, "bank"],
				["lily", 0.12, 3.0, 40.0, 0.9, 1.6, 0.04, "water"],
				["reeds", 0.2, 4.0, 60.0, 0.8, 1.4, 0.0, "water"],
				["mountain", 0.9, 130.0, 210.0, 1.0, 1.0, 0.0, "far"],
			],
			"peak": Color(0.94, 0.96, 1.0), "snow": 0.3,
			"sky_top": Color(0.12, 0.3, 0.75), "sky_horizon": Color(0.78, 0.9, 1.0),
			"sky_bottom": Color(0.3, 0.4, 0.5), "sun": Color(1.0, 1.0, 0.9), "sun_dir": Vector3(-0.3, 0.4, -1.0),
			"fog": Color(0.76, 0.86, 0.96), "ambient": Color(0.65, 0.74, 0.9), "light": Color(1.0, 0.98, 0.92),
			"water_deep": Color(0.06, 0.24, 0.42), "water_shallow": Color(0.5, 0.8, 0.88), "water_beat": Color(0.6, 0.95, 1.0),
			"motes": Color(1.0, 1.0, 1.0),
		},
		"sky_top": Color(0.14, 0.1, 0.36), "sky_horizon": Color(1.0, 0.62, 0.72),
		"sky_bottom": Color(0.22, 0.2, 0.36), "sun": Color(1.0, 0.82, 0.72), "sun_dir": Vector3(0.0, 0.16, -1.0),
		"fog": Color(0.82, 0.62, 0.78), "fog_density": 0.0055,
		"ambient": Color(0.62, 0.55, 0.78), "ambient_energy": 0.8,
		"light": Color(1.0, 0.82, 0.8), "light_energy": 1.15,
		"water_deep": Color(0.08, 0.12, 0.36), "water_shallow": Color(0.5, 0.5, 0.82),
		"water_beat": Color(1.0, 0.5, 0.8), "swell": 0.6,
		"motes": Color(1.0, 0.8, 0.9),
	},
	# ---------------------------------------------------------------- the other way home
	{
		"name": "SHIPPING LANE", "at": Vector2(30, -150), "tier": 1, "lane": 1, "salt": true,
		"objective": {"type": "flow", "n": 4},
		"tagline": "DIESEL, RUST AND VERY BIG SHIPS",
		"seed": 5909, "length": 2800.0,
		"width": 26.0, "slope": 0.0, "curve": 0.3,
		"kinds": ["rocks", "ramps", "rails", "predators", "rocks", "rings"],
		"falls_every": 0.0, "predator": "shark", "predator_word": "CHOMPED!",
		"profile": [[-0.5, -1.2, 0, 0], [4.0, -3.0, 0, 0], [60.0, -3.0, 0, 0], [170.0, -3.0, 0, 0]],
		"bank_colors": [Color(0.05, 0.09, 0.09), Color(0.04, 0.08, 0.08), Color(0.04, 0.08, 0.08)],
		"bed": Color(0.05, 0.1, 0.1), "cliff": Color(0.3, 0.32, 0.34),
		"sea_from": 0.8, "markers": [Color(0.15, 0.55, 0.25), Color(0.3, 1.0, 0.4)],
		"rock": Color(0.75, 0.32, 0.15), "rock_cap": Color(0.75, 0.32, 0.15), "rock_mesh": "crate",
		"ramp": Color(0.3, 0.32, 0.36), "ramp_top": Color(0.9, 0.75, 0.2),
		"rail": Color(0.58, 0.6, 0.64), "rail_node": Color(0.3, 0.32, 0.36),
		"arch": Color(0.4, 0.42, 0.46), "ruins": false,
		"scatter": [
			["crate", 0.1, 4.0, 70.0, 1.2, 2.4, -0.6, "water"],
			["ship", 0.012, 55.0, 120.0, 1.0, 1.0, 0.0, "water"],
			["ship", 0.5, 110.0, 165.0, 1.0, 1.6, 0.0, "far"],
		],
		"sky_top": Color(0.2, 0.2, 0.3), "sky_horizon": Color(0.86, 0.6, 0.4),
		"sky_bottom": Color(0.2, 0.22, 0.22), "sun": Color(1.0, 0.6, 0.3), "sun_dir": Vector3(0.2, 0.14, -1.0),
		"fog": Color(0.5, 0.42, 0.36), "fog_density": 0.011,
		"ambient": Color(0.55, 0.5, 0.52), "ambient_energy": 0.8,
		"light": Color(1.0, 0.8, 0.65), "light_energy": 1.0,
		"water_deep": Color(0.04, 0.11, 0.11), "water_shallow": Color(0.2, 0.34, 0.3),
		"water_beat": Color(1.0, 0.6, 0.2), "swell": 2.0,
		"motes": Color(1.0, 0.7, 0.4),
	},
	{
		"name": "THE HARBOR", "at": Vector2(33.7, -118.3), "tier": 2, "lane": 1, "salt": false,
		"objective": {"type": "score", "n": 60000},
		"tagline": "QUAYS, CRANES AND SODIUM LIGHT",
		"seed": 6910, "length": 3000.0,
		"width": 22.0, "slope": 0.004, "curve": 0.5, "uphill": true,
		"kinds": ["rails", "rocks", "ramps", "rails", "rings", "predators"],
		"falls_every": 0.0, "predator": "shark", "predator_word": "CHOMPED!",
		"profile": [[-0.5, -1.2, 0, 0], [0.4, 2.4, 0, 0], [8.0, 2.5, 0, 0.2], [24.0, 2.7, 0, 0.5],
				[45.0, 3.0, 0, 1.0], [75.0, 6.0, 0, 3.0]],
		"bank_colors": [Color(0.36, 0.37, 0.4), Color(0.5, 0.5, 0.52), Color(0.22, 0.22, 0.25),
				Color(0.2, 0.2, 0.23), Color(0.25, 0.27, 0.3)],
		"bed": Color(0.14, 0.17, 0.2), "cliff": Color(0.4, 0.4, 0.44),
		"rock": Color(0.2, 0.5, 0.75), "rock_cap": Color(0.2, 0.5, 0.75), "rock_mesh": "crate",
		"ramp": Color(0.3, 0.32, 0.36), "ramp_top": Color(0.9, 0.75, 0.2),
		"rail": Color(0.58, 0.6, 0.64), "rail_node": Color(0.3, 0.32, 0.36),
		"arch": Color(0.45, 0.46, 0.5), "ruins": false,
		"scatter": [
			["piling", 0.5, -1.2, 0.2, 0.8, 1.3, 0.0, "water"],
			["lamp", 0.2, 1.5, 3.0, 1.0, 1.2, 0.0, "bank"],
			["crate", 0.5, 4.0, 40.0, 1.6, 3.2, 0.0, "bank"],
			["shed", 0.12, 14.0, 60.0, 1.0, 1.8, 0.0, "bank"],
			["crane", 0.035, 8.0, 30.0, 1.0, 1.3, 0.0, "bank"],
			["shed", 0.5, 78.0, 150.0, 3.0, 6.0, -4.0, "far"],
		],
		"sky_top": Color(0.02, 0.03, 0.1), "sky_horizon": Color(0.9, 0.45, 0.2),
		"sky_bottom": Color(0.05, 0.06, 0.1), "sun": Color(1.0, 0.7, 0.4), "sun_dir": Vector3(0.0, 0.08, -1.0),
		"fog": Color(0.3, 0.2, 0.2), "fog_density": 0.007,
		"ambient": Color(0.42, 0.44, 0.62), "ambient_energy": 0.85,
		"light": Color(1.0, 0.75, 0.55), "light_energy": 0.9,
		"water_deep": Color(0.02, 0.06, 0.1), "water_shallow": Color(0.1, 0.25, 0.3),
		"water_beat": Color(1.0, 0.7, 0.2), "swell": 0.8,
		"motes": Color(1.0, 0.7, 0.3),
	},
	{
		"name": "THE FISH LADDER", "at": Vector2(30.8, 111), "tier": 4, "lane": 2, "salt": false,
		"objective": {"type": "on_beat", "n": 6},
		"tagline": "A DAM IN THE WAY. ONE STEP AT A TIME",
		"seed": 7911, "length": 3000.0,
		"width": 20.0, "slope": 0.03, "curve": 0.25, "uphill": true,
		"kinds": ["ramps", "rings", "rails", "rocks", "rings", "ramps"],
		"falls_every": 170.0, "predator": "", "predator_word": "",
		"profile": [[-0.5, -1.2, 0, 0], [0.5, 3.0, 0, 0], [5.0, 3.2, 0, 0], [9.0, 7.0, 0.5, 1.0],
				[30.0, 12.0, 2.0, 4.0], [55.0, 26.0, 0, 8.0]],
		"bank_colors": [Color(0.5, 0.5, 0.52), Color(0.62, 0.62, 0.64), Color(0.46, 0.46, 0.48),
				Color(0.2, 0.36, 0.26), Color(0.14, 0.28, 0.2)],
		"bed": Color(0.4, 0.4, 0.42), "cliff": Color(0.56, 0.56, 0.58),
		"rock": Color(0.5, 0.5, 0.52), "rock_cap": Color(0.36, 0.44, 0.3),
		"ramp": Color(0.5, 0.5, 0.52), "ramp_top": Color(0.9, 0.75, 0.2),
		"rail": Color(0.58, 0.6, 0.64), "rail_node": Color(0.3, 0.32, 0.36),
		"arch": Color(0.56, 0.56, 0.58), "ruins": false,
		"scatter": [
			["lamp", 0.25, 1.5, 4.0, 1.0, 1.2, 0.0, "bank"],
			["shed", 0.04, 1.8, 3.2, 0.5, 0.7, 0.0, "bank"],
			["pine", 0.65, 11.0, 52.0, 0.8, 1.5, -0.5, "bank"],
			["larch", 0.35, 11.0, 52.0, 0.7, 1.3, -0.5, "bank"],
			["rock", 0.2, 9.0, 22.0, 0.8, 2.2, -0.4, "bank"],
			["hill", 0.6, 70.0, 160.0, 1.0, 1.0, 0.0, "far"],
		],
		"hill": Color(0.2, 0.3, 0.26),
		"sky_top": Color(0.4, 0.45, 0.56), "sky_horizon": Color(0.8, 0.83, 0.86),
		"sky_bottom": Color(0.3, 0.32, 0.36), "sun": Color(0.96, 0.96, 0.9), "sun_dir": Vector3(0.2, 0.5, -1.0),
		"fog": Color(0.7, 0.73, 0.78), "fog_density": 0.007,
		"ambient": Color(0.66, 0.7, 0.78), "ambient_energy": 0.9,
		"light": Color(0.95, 0.95, 0.92), "light_energy": 1.0,
		"water_deep": Color(0.08, 0.24, 0.3), "water_shallow": Color(0.5, 0.7, 0.7),
		"water_beat": Color(0.9, 0.9, 0.5), "swell": 1.0,
		"motes": Color(0.9, 0.95, 1.0),
	},
	{
		"name": "THE FISH FARM", "at": Vector2(44, -86), "tier": 5, "lane": 1, "salt": false,
		"tagline": "NOT QUITE HOME, BUT THERE ARE PELLETS",
		"seed": 8912, "length": 2400.0,
		"width": 26.0, "slope": 0.0, "curve": 0.3,
		"kinds": ["rings", "ramps", "rocks", "rails", "rings", "ramps"],
		"falls_every": 0.0, "predator": "", "predator_word": "",
		"profile": [[-0.5, -1.2, 0, 0], [4.0, -2.0, 0, 0], [58.0, -2.0, 0, 0], [66.0, 0.6, 0.4, 0.5],
				[84.0, 5.0, 2.0, 3.0], [125.0, 24.0, 0, 8.0]],
		"bank_colors": [Color(0.14, 0.2, 0.18), Color(0.12, 0.18, 0.16), Color(0.42, 0.42, 0.4),
				Color(0.22, 0.34, 0.26), Color(0.3, 0.36, 0.34)],
		"bed": Color(0.16, 0.22, 0.2), "cliff": Color(0.5, 0.5, 0.52),
		"sea_from": 0.8, "sea_to": 64.0, "markers": [Color(1.0, 0.5, 0.1), Color(1.0, 0.9, 0.3)],
		"rock": Color(0.2, 0.45, 0.8), "rock_cap": Color(0.2, 0.45, 0.8), "rock_mesh": "crate",
		"ramp": Color(0.36, 0.38, 0.4), "ramp_top": Color(0.9, 0.75, 0.2),
		"rail": Color(0.58, 0.6, 0.64), "rail_node": Color(0.3, 0.32, 0.36),
		"arch": Color(0.5, 0.5, 0.52), "ruins": false,
		"scatter": [
			["pen", 0.09, 8.0, 54.0, 1.0, 1.7, 0.0, "water"],
			["shed", 0.02, 10.0, 50.0, 0.7, 1.0, 0.3, "water"],
			["pine", 0.8, 66.0, 120.0, 0.9, 1.6, -0.5, "bank"],
			["shed", 0.1, 64.0, 80.0, 1.0, 1.6, 0.0, "bank"],
			["lamp", 0.15, 62.0, 70.0, 1.0, 1.3, 0.0, "bank"],
			["mountain", 0.7, 130.0, 210.0, 1.0, 1.0, 0.0, "far"],
		],
		"hill": Color(0.32, 0.36, 0.38),
		"sky_top": Color(0.3, 0.34, 0.46), "sky_horizon": Color(0.76, 0.73, 0.7),
		"sky_bottom": Color(0.24, 0.3, 0.3), "sun": Color(1.0, 0.9, 0.75), "sun_dir": Vector3(0.0, 0.2, -1.0),
		"fog": Color(0.62, 0.64, 0.66), "fog_density": 0.008,
		"ambient": Color(0.6, 0.64, 0.7), "ambient_energy": 0.85,
		"light": Color(1.0, 0.92, 0.82), "light_energy": 1.0,
		"water_deep": Color(0.05, 0.17, 0.15), "water_shallow": Color(0.3, 0.5, 0.4),
		"water_beat": Color(1.0, 0.6, 0.2), "swell": 0.6,
		"motes": Color(0.9, 0.9, 0.8),
	},
	# ---------------------------------------------------------------- the southern route
	{
		"name": "OCEAN TRENCH", "at": Vector2(11, 142), "tier": 1, "lane": 2, "salt": true,
		"objective": {"type": "on_beat", "n": 5},
		"tagline": "NOTHING BUT DARK WATER AND LIVING LIGHT",
		"seed": 5313, "length": 2800.0,
		"width": 26.0, "slope": 0.0, "curve": 0.4,
		"kinds": ["rings", "rocks", "predators", "ramps", "rails", "rings"],
		"falls_every": 0.0, "predator": "shark", "predator_word": "CHOMPED!",
		"profile": [[-0.5, -1.2, 0, 0], [4.0, -3.0, 0, 0], [60.0, -3.0, 0, 0], [170.0, -3.0, 0, 0]],
		"bank_colors": [Color(0.02, 0.02, 0.06), Color(0.01, 0.01, 0.05), Color(0.01, 0.01, 0.05)],
		"bed": Color(0.02, 0.02, 0.07), "cliff": Color(0.2, 0.2, 0.28),
		"sea_from": 0.8, "markers": [Color(0.3, 0.2, 0.6), Color(0.3, 1.0, 0.9)],
		"rock": Color(0.16, 0.14, 0.24), "rock_cap": Color(0.3, 1.0, 0.9, 0.3),
		"ramp": Color(0.14, 0.12, 0.22), "ramp_top": Color(0.4, 0.3, 0.7),
		"rail": Color(0.3, 0.9, 0.8, 0.5), "rail_node": Color(0.5, 0.3, 0.8),
		"arch": Color(0.24, 0.22, 0.34), "ruins": false,
		"scatter": [
			["jelly", 0.3, 3.0, 70.0, 0.7, 2.0, 0.0, "water"],
			["spire", 0.05, 20.0, 110.0, 0.8, 2.0, -1.0, "water"],
			["spire", 0.5, 100.0, 160.0, 2.0, 4.0, -1.0, "far"],
		],
		"sky_top": Color(0.0, 0.0, 0.03), "sky_horizon": Color(0.14, 0.06, 0.3),
		"sky_bottom": Color(0.01, 0.02, 0.07), "sun": Color(0.6, 0.7, 1.0), "sun_dir": Vector3(-0.4, 0.5, -1.0),
		"fog": Color(0.03, 0.03, 0.12), "fog_density": 0.012,
		"ambient": Color(0.3, 0.35, 0.7), "ambient_energy": 0.8,
		"light": Color(0.5, 0.6, 1.0), "light_energy": 0.7,
		"water_deep": Color(0.0, 0.01, 0.08), "water_shallow": Color(0.04, 0.1, 0.3),
		"water_beat": Color(0.3, 1.0, 0.9), "swell": 2.5,
		"motes": Color(0.3, 1.0, 0.9),
	},
	{
		"name": "CORAL REEF", "at": Vector2(-1, 130), "tier": 2, "lane": 2, "salt": true,
		"objective": {"type": "rings", "n": 14},
		"tagline": "A GARDEN UNDER GLASS",
		"seed": 6314, "length": 3000.0,
		"width": 25.0, "slope": 0.0, "curve": 0.9,
		"kinds": ["rocks", "rings", "ramps", "rocks", "predators", "rails"],
		"falls_every": 0.0, "predator": "shark", "predator_word": "CHOMPED!",
		"profile": [[-0.5, -1.2, 0, 0], [4.0, -1.6, 0.2, 0], [30.0, -1.4, 0.3, 0.3], [170.0, -2.0, 0, 0]],
		"bank_colors": [Color(0.8, 0.86, 0.7), Color(0.72, 0.84, 0.7), Color(0.5, 0.74, 0.7)],
		"bed": Color(0.8, 0.84, 0.66), "cliff": Color(0.7, 0.66, 0.55),
		"sea_from": 0.8, "markers": [Color(1.0, 0.45, 0.55), Color(1.0, 0.8, 0.4)],
		"rock": Color(1.0, 0.5, 0.6), "rock_cap": Color(0.6, 0.4, 1.0),
		"ramp": Color(0.85, 0.6, 0.55), "ramp_top": Color(1.0, 0.8, 0.5),
		"rail": Color(0.4, 0.8, 0.5), "rail_node": Color(0.25, 0.55, 0.35),
		"arch": Color(0.9, 0.8, 0.7), "ruins": false,
		"scatter": [
			["coral", 0.8, 1.0, 40.0, 0.9, 2.4, -0.9, "water"],
			["coral", 0.5, 30.0, 90.0, 1.8, 3.6, -0.9, "water"],
			["stack", 0.4, 100.0, 160.0, 1.5, 3.0, -1.0, "far"],
		],
		"sky_top": Color(0.3, 0.3, 0.75), "sky_horizon": Color(1.0, 0.72, 0.75),
		"sky_bottom": Color(0.3, 0.75, 0.75), "sun": Color(1.0, 0.85, 0.75), "sun_dir": Vector3(0.3, 0.22, -1.0),
		"fog": Color(0.85, 0.75, 0.82), "fog_density": 0.007,
		"ambient": Color(0.8, 0.78, 0.9), "ambient_energy": 0.9,
		"light": Color(1.0, 0.9, 0.85), "light_energy": 1.25,
		"water_deep": Color(0.05, 0.5, 0.6), "water_shallow": Color(0.45, 0.95, 0.85),
		"water_beat": Color(1.0, 0.6, 0.8), "swell": 1.0,
		"motes": Color(1.0, 0.8, 0.9),
	},
	{
		"name": "MANGROVE DELTA", "at": Vector2(10, 106), "tier": 3, "lane": 2, "salt": false,
		"objective": {"type": "flow", "n": 4},
		"tagline": "STILT ROOTS, LANTERNS AND LIMESTONE TOWERS",
		"seed": 7315, "length": 3200.0,
		"width": 23.0, "slope": 0.008, "curve": 1.2, "uphill": true,
		"kinds": ["rails", "rocks", "ramps", "rings", "predators", "rails"],
		"falls_every": 0.0, "predator": "shark", "predator_word": "SNAPPED!",
		"profile": [[-0.5, -1.2, 0, 0], [3.0, 0.2, 0.2, 0], [10.0, 0.6, 0.3, 0.3], [22.0, 1.2, 0.5, 1.0],
				[40.0, 3.0, 1.0, 2.0], [70.0, 9.0, 0, 4.0]],
		"bank_colors": [Color(0.3, 0.26, 0.18), Color(0.34, 0.34, 0.2), Color(0.2, 0.4, 0.2),
				Color(0.14, 0.34, 0.2), Color(0.1, 0.28, 0.2)],
		"bed": Color(0.26, 0.24, 0.16), "cliff": Color(0.5, 0.5, 0.46),
		"rock": Color(0.36, 0.34, 0.3), "rock_cap": Color(0.24, 0.46, 0.22),
		"ramp": Color(0.42, 0.3, 0.2), "ramp_top": Color(0.6, 0.48, 0.3),
		"rail": Color(0.5, 0.66, 0.22), "rail_node": Color(0.36, 0.5, 0.16),
		"arch": Color(0.5, 0.36, 0.26), "ruins": false,
		"scatter": [
			["mangrove", 0.75, -1.5, 3.0, 0.8, 1.3, -0.4, "water"],
			["mangrove", 0.7, 3.0, 40.0, 0.9, 1.6, -0.3, "bank"],
			["fern", 0.5, 2.0, 20.0, 0.8, 1.4, -0.1, "bank"],
			["hut", 0.06, 3.0, 12.0, 0.9, 1.2, 0.0, "bank"],
			["lily", 0.12, -5.0, -1.5, 0.8, 1.4, 0.04, "water"],
			["karst", 0.9, 75.0, 190.0, 1.0, 1.0, 0.0, "far"],
			["karst", 0.04, 30.0, 70.0, 0.4, 0.7, -2.0, "bank"],
		],
		"hill": Color(0.5, 0.52, 0.5),
		"sky_top": Color(0.1, 0.22, 0.34), "sky_horizon": Color(0.8, 0.86, 0.7),
		"sky_bottom": Color(0.12, 0.24, 0.2), "sun": Color(1.0, 0.92, 0.7), "sun_dir": Vector3(-0.2, 0.2, -1.0),
		"fog": Color(0.62, 0.74, 0.62), "fog_density": 0.009,
		"ambient": Color(0.55, 0.68, 0.6), "ambient_energy": 0.85,
		"light": Color(1.0, 0.94, 0.78), "light_energy": 1.0,
		"water_deep": Color(0.1, 0.2, 0.12), "water_shallow": Color(0.36, 0.5, 0.3),
		"water_beat": Color(1.0, 0.8, 0.3), "swell": 0.7,
		"motes": Color(1.0, 0.8, 0.3),
	},
	{
		"name": "PLAINS RIVER", "at": Vector2(41, -100), "tier": 4, "lane": 1, "salt": false,
		"objective": {"type": "score", "n": 70000},
		"tagline": "HARVEST TIME. BIG SKY, SLOW BENDS",
		"seed": 8316, "length": 3200.0,
		"width": 26.0, "slope": 0.012, "curve": 1.5, "uphill": true,
		"kinds": ["ramps", "rails", "rings", "rocks", "ramps", "rings"],
		"falls_every": 0.0, "predator": "", "predator_word": "",
		"profile": [[-0.5, -1.2, 0, 0], [2.0, 0.8, 0.2, 0], [6.0, 1.6, 0.3, 0.3], [20.0, 2.0, 0.3, 0.6],
				[45.0, 2.4, 0.3, 1.0], [80.0, 4.0, 0, 2.0]],
		"bank_colors": [Color(0.4, 0.32, 0.2), Color(0.5, 0.52, 0.24), Color(0.86, 0.7, 0.26),
				Color(0.82, 0.66, 0.24), Color(0.7, 0.58, 0.26)],
		"bed": Color(0.36, 0.3, 0.2), "cliff": Color(0.5, 0.44, 0.34),
		"rock": Color(0.5, 0.46, 0.4), "rock_cap": Color(0.5, 0.52, 0.24),
		"ramp": Color(0.5, 0.36, 0.24), "ramp_top": Color(0.8, 0.66, 0.3),
		"rail": Color(0.5, 0.36, 0.22), "rail_node": Color(0.34, 0.24, 0.16),
		"arch": Color(0.6, 0.3, 0.24), "ruins": false,
		"scatter": [
			["grass", 0.9, 1.0, 8.0, 0.8, 1.5, -0.1, "bank"],
			["larch", 0.14, 3.0, 10.0, 0.6, 0.9, -0.5, "bank"],
			["bale", 0.3, 8.0, 70.0, 0.9, 1.3, 0.0, "bank"],
			["barn", 0.03, 16.0, 60.0, 1.0, 1.4, 0.0, "bank"],
			["windmill", 0.03, 12.0, 70.0, 1.0, 1.5, 0.0, "bank"],
			["reeds", 0.4, -1.5, 0.5, 0.8, 1.3, 0.0, "water"],
			["hill", 0.5, 110.0, 190.0, 0.5, 0.8, 0.0, "far"],
		],
		"hill": Color(0.62, 0.52, 0.24),
		"spring": {
			"bank_colors": [Color(0.4, 0.32, 0.2), Color(0.36, 0.56, 0.24), Color(0.4, 0.66, 0.26),
					Color(0.36, 0.6, 0.26), Color(0.3, 0.52, 0.26)],
			"scatter": [
				["grass", 0.9, 1.0, 8.0, 0.8, 1.5, -0.1, "bank"],
				["bush", 0.14, 3.0, 10.0, 0.8, 1.2, -0.3, "bank"],
				["flower", 0.6, 2.0, 30.0, 0.9, 1.5, 0.0, "bank"],
				["barn", 0.03, 16.0, 60.0, 1.0, 1.4, 0.0, "bank"],
				["windmill", 0.03, 12.0, 70.0, 1.0, 1.5, 0.0, "bank"],
				["reeds", 0.4, -1.5, 0.5, 0.8, 1.3, 0.0, "water"],
				["hill", 0.5, 110.0, 190.0, 0.5, 0.8, 0.0, "far"],
			],
			"hill": Color(0.3, 0.5, 0.26), "motes": Color(1.0, 1.0, 0.9),
		},
		"sky_top": Color(0.14, 0.36, 0.8), "sky_horizon": Color(0.96, 0.86, 0.66),
		"sky_bottom": Color(0.5, 0.44, 0.26), "sun": Color(1.0, 0.92, 0.66), "sun_dir": Vector3(0.3, 0.28, -1.0),
		"fog": Color(0.9, 0.82, 0.64), "fog_density": 0.0045,
		"ambient": Color(0.72, 0.7, 0.66), "ambient_energy": 0.9,
		"light": Color(1.0, 0.92, 0.74), "light_energy": 1.3,
		"water_deep": Color(0.1, 0.24, 0.3), "water_shallow": Color(0.42, 0.6, 0.56),
		"water_beat": Color(1.0, 0.85, 0.4), "swell": 0.8,
		"motes": Color(1.0, 0.85, 0.4),
	},
	{
		"name": "DESERT RIVER BED", "at": Vector2(36, -112), "tier": 3, "lane": 1, "salt": false,
		"objective": {"type": "rings", "n": 12},
		"tagline": "A THREAD OF WATER THROUGH RED ROCK",
		"seed": 8317, "length": 3000.0,
		"width": 19.0, "slope": 0.02, "curve": 1.2, "uphill": true,
		"kinds": ["rocks", "ramps", "rings", "rocks", "rails", "ramps"],
		"falls_every": 520.0, "predator": "", "predator_word": "",
		"profile": [[-0.5, -1.2, 0, 0], [2.0, 0.6, 0.3, 0], [7.0, 1.6, 0.6, 0.5], [12.0, 11.0, 2.0, 3.0],
				[26.0, 15.0, 2.0, 5.0], [52.0, 30.0, 0, 8.0]],
		"bank_colors": [Color(0.8, 0.66, 0.44), Color(0.86, 0.72, 0.48), Color(0.8, 0.42, 0.24),
				Color(0.7, 0.34, 0.2), Color(0.62, 0.3, 0.2)],
		"bed": Color(0.72, 0.6, 0.42), "cliff": Color(0.74, 0.4, 0.26),
		"rock": Color(0.74, 0.4, 0.26), "rock_cap": Color(0.86, 0.6, 0.4),
		"ramp": Color(0.7, 0.4, 0.26), "ramp_top": Color(0.9, 0.74, 0.5),
		"rail": Color(0.6, 0.5, 0.4), "rail_node": Color(0.4, 0.32, 0.26),
		"arch": Color(0.78, 0.46, 0.3), "ruins": false,
		"scatter": [
			["cactus", 0.3, 2.0, 9.0, 0.8, 1.4, -0.2, "bank"],
			["cactus", 0.3, 14.0, 50.0, 0.9, 1.6, -0.2, "bank"],
			["rock", 0.4, 0.0, 9.0, 0.8, 2.4, -0.4, "bank"],
			["grass", 0.3, 1.0, 8.0, 0.6, 1.0, -0.1, "bank"],
			["mesa", 0.7, 80.0, 190.0, 1.0, 1.8, 0.0, "far"],
		],
		"hill": Color(0.72, 0.38, 0.24),
		"spring": {
			"scatter": [
				["cactus", 0.3, 2.0, 9.0, 0.8, 1.4, -0.2, "bank"],
				["cactus", 0.3, 14.0, 50.0, 0.9, 1.6, -0.2, "bank"],
				["rock", 0.4, 0.0, 9.0, 0.8, 2.4, -0.4, "bank"],
				["flower", 0.7, 1.0, 9.0, 0.8, 1.3, 0.0, "bank"],
				["grass", 0.5, 1.0, 8.0, 0.7, 1.2, -0.1, "bank"],
				["mesa", 0.7, 80.0, 190.0, 1.0, 1.8, 0.0, "far"],
			],
			"water_shallow": Color(0.5, 0.74, 0.7),
		},
		"sky_top": Color(0.12, 0.2, 0.6), "sky_horizon": Color(1.0, 0.6, 0.3),
		"sky_bottom": Color(0.5, 0.3, 0.2), "sun": Color(1.0, 0.8, 0.45), "sun_dir": Vector3(0.0, 0.16, -1.0),
		"fog": Color(0.95, 0.62, 0.42), "fog_density": 0.005,
		"ambient": Color(0.7, 0.58, 0.6), "ambient_energy": 0.85,
		"light": Color(1.0, 0.82, 0.62), "light_energy": 1.3,
		"water_deep": Color(0.08, 0.3, 0.34), "water_shallow": Color(0.4, 0.7, 0.62),
		"water_beat": Color(1.0, 0.7, 0.3), "swell": 0.7,
		"motes": Color(1.0, 0.8, 0.5),
	},
]

const LAST_TIER := 5
## Lane 0 is the northern wild route, lane 2 the southern one and lane 1 the man-made one.
const MADE := 1


## The stage at a place on the map; -1 if there is none.
static func at(tier: int, lane: int) -> int:
	for i in LIST.size():
		if LIST[i].tier == tier and LIST[i].lane == lane:
			return i
	return -1


## True when the way on from this stage forks (so its goal matters).
static func forks(id: int) -> bool:
	var tier := int(LIST[id].tier) + 1
	var count := 0
	for lane in 3:
		if at(tier, lane) != -1:
			count += 1
	return count > 1


## Where you can go next heading upstream, best first. Meeting the stage's goal keeps you
## wild: your own route first if it carries on, and the other natural route as a choice.
## Missing it sweeps you onto the man-made route.
static func next_up(id: int, met: bool) -> Array[int]:
	var tier := int(LIST[id].tier) + 1
	var made := at(tier, MADE)
	var wild: Array[int] = []
	for lane: int in [int(LIST[id].lane), 0, 2]:
		var stage := at(tier, lane)
		if lane != MADE and stage != -1 and not wild.has(stage):
			wild.append(stage)
	var out: Array[int] = []
	if not met and made != -1:
		out.append(made)
	elif wild.is_empty():
		if made != -1:
			out.append(made)
	else:
		out = wild
		if out.size() == 1 and made != -1:
			out.append(made)
	return out


## The next stage heading back downstream: the way you came up if we know it, otherwise the
## same route's stage one tier down.
static func prev_down(id: int, route: Array[int]) -> int:
	var tier := int(LIST[id].tier) - 1
	if tier < 0:
		return -1
	for r in route:
		if LIST[r].tier == tier:
			return r
	var same := at(tier, LIST[id].lane)
	return same if same != -1 else at(tier, 0)


static func objective_text(id: int) -> String:
	if not LIST[id].has("objective") or not forks(id):
		return ""
	var o: Dictionary = LIST[id].objective
	match o.type:
		"rings":
			return "COLLECT %d RINGS" % o.n
		"on_beat":
			return "LAND %d TRICKS ON THE BEAT" % o.n
		"flow":
			return "REACH FLOW x%d" % o.n
		"score":
			return "SCORE %dK" % (int(o.n) / 1000)
		"clean":
			return "NO MORE THAN %d WIPEOUTS" % o.n
	return ""


## The stages leading up to this one along its own route (the northern one where its own has
## nothing on a tier), ending with the stage itself.
static func path_to(id: int) -> Array[int]:
	var out: Array[int] = []
	for tier in int(LIST[id].tier):
		var stage := at(tier, LIST[id].lane)
		out.append(stage if stage != -1 else at(tier, 0))
	out.append(id)
	return out


## The same, coming the other way: from the spawning grounds down to this stage.
static func path_from_top(id: int) -> Array[int]:
	var out: Array[int] = []
	for tier in range(LAST_TIER, int(LIST[id].tier), -1):
		var stage := at(tier, LIST[id].lane)
		out.append(stage if stage != -1 else at(tier, 0))
	out.append(id)
	return out
