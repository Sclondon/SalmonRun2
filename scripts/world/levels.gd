extends RefCounted
## The journey home: every stage of the salmon run, from the open ocean up to the spawning
## grounds, and how the stages connect. Each entry is everything that makes a stage look and
## play differently;
## track.gd builds the course from it and world.gd the sky and light.
##
## profile: the bank, as [distance from the water's edge, height above the water, noise 1, noise 2]
##          points going outwards. bank_colors has one colour per segment between them.
## sea_from: open water carries on from this far past the edge (ocean, reef and lake levels).
## uphill:  swum upstream: the water climbs, and waterfalls are steps you have to leap up.
## spring:  settings that change on the way back down. The run up is late summer and autumn
##          (August to November); the young go to sea in spring.
## at:      where on Earth it is, as (latitude, longitude), for the globe.
## fact:    a true thing about a salmon at this point of the run home, shown on the level
##          select. (On the way back down the facts are about the young: see DOWN_FACTS.)
## tier:    which step of the journey it is (its row on the map, and its tune); order is its
##          place along that row.
## route:   "japan" for the stages of the Japan route, which splits off at step 4; the rest are
##          shared or North American.
## like:    borrow every setting of another stage (by name), replacing only what is listed.
## next:    the stages it leads to heading upstream. The first is the default; the others are
##          more advanced routes, opened by meeting this stage's objective.
## spacing: how much open water there is between one piece of the course and the next (1 is
##          the usual 45 to 80 m).
## floor:   open sea only: how far down the sea floor is (metres); it replaces the river bed
##          and banks with a sheet of hills way below the water.
## layers:  how many layers there are to dive to under the surface (1 if not given), and
##          layer_depth, how many metres apart they are (1.7).
## deep:    what is under the sea, in turn, all the way along: "currents" (a winding current
##          to ride like a rail), "launch" (one that rises to the surface and throws you into
##          the air), "surge" (a run of boost rings), "jellies" (sea nettles to keep clear of).
## ramps:   false for a stage with no jump ramps.
## shore:   for sea with land along one side only: -1 for the left, 1 for the right. The
##          other side is open water.
## murk:    how thick the water is when you are under it (fog density; 0.016 if not given).
## rock_word: what a bump into one of the stage's obstacles is called ("ROCKED!").
## meander: how much the course bends from side to side (1 if not given).
## water_*: any setting of the water shader (see shaders/water.gdshader), e.g. water_deep,
##          water_foam_amount, water_depth_range, water_rim_width.
## kinds:   what the course is made of ("ramps", "rails", "rocks", "rings", "predators").
## scatter: [mesh, chance, nearest, farthest, smallest, biggest, sink, mode] dressing rules;
##          mode "bank" sits on the bank, "water" floats, "far" is a backdrop every 40 m.


const LIST: Array[Dictionary] = [
	{
		"name": "OPEN OCEAN", "at": Vector2(22, -165), "tier": 0, "salt": true,
		"next": ["SHALLOW SEA", "OCEAN TRENCH"],
		"objective": {"type": "rings", "n": 12},
		"tagline": "SOMETHING IS CALLING YOU HOME",
		"fact": "A SOCKEYE SPENDS ABOUT TWO YEARS FEEDING AT SEA BEFORE IT TURNS FOR HOME.",
		"seed": 4101, "length": 2600.0,
		# the gentlest start: open water five times the width of a river, long empty stretches, and almost
		# nothing to hit (no rock fields; a pair of sharks now and then)
		"width": 140.0, "slope": 0.0, "curve": 0.3, "spacing": 2.2,
		"kinds": ["rings", "rails", "rings", "predators"],
		# no ramps out here: the way into the air is a current that rises to the surface
		"ramps": false,
		# under the sea, laid out on its own: currents to ride, ones that launch you, runs of
		# boost rings and drifts of sea nettles
		"deep": ["currents", "surge", "launch", "jellies"],
		# the deepest water there is: six layers under the surface
		"layers": 6, "layer_depth": 3.6,
		"falls_every": 0.0, "predator": "shark", "predator_word": "CHOMPED!",
		"profile": [[-0.5, -1.2, 0, 0], [4.0, -3.0, 0, 0], [60.0, -3.0, 0, 0], [170.0, -3.0, 0, 0]],
		"bank_colors": [Color(0.02, 0.06, 0.14), Color(0.02, 0.05, 0.12), Color(0.02, 0.05, 0.12)],
		"bed": Color(0.1, 0.24, 0.4), "cliff": Color(0.3, 0.35, 0.42),
		"sea_from": 0.8, "markers": [Color(0.9, 0.2, 0.15), Color(1.0, 0.5, 0.2)],
		"rock": Color(0.75, 0.32, 0.15), "rock_cap": Color(0.75, 0.32, 0.15), "rock_mesh": "crate",
		"ramp": Color(0.05, 0.25, 0.45), "ramp_top": Color(0.75, 0.93, 1.0),
		"rail": Color(0.85, 0.5, 0.15), "rail_node": Color(0.95, 0.95, 0.9),
		"arch": Color(0.5, 0.62, 0.72), "ruins": false,
		"scatter": [
			# nothing out here but swell, the odd lost container and ships on the horizon
			["crate", 0.04, 4.0, 70.0, 1.2, 2.4, -0.6, "water"],
			["ship", 0.006, 70.0, 130.0, 1.0, 1.0, 0.0, "water"],
			["ship", 0.25, 120.0, 165.0, 1.0, 1.4, 0.0, "far"],
		],
		"sky_top": Color(0.01, 0.02, 0.10), "sky_horizon": Color(0.10, 0.34, 0.48),
		"sky_bottom": Color(0.03, 0.12, 0.20), "sun": Color(0.85, 0.95, 1.0), "sun_dir": Vector3(0.25, 0.3, -1.0),
		"fog": Color(0.06, 0.2, 0.3), "fog_density": 0.011,
		"ambient": Color(0.35, 0.5, 0.8), "ambient_energy": 0.85,
		"light": Color(0.65, 0.8, 1.0), "light_energy": 0.9,
		"water_deep": Color(0.01, 0.06, 0.18), "water_shallow": Color(0.04, 0.24, 0.42),
		"water_beat": Color(0.2, 0.7, 1.0), "swell": 3.0,
		# deep blue water, and no bottom to be seen (a floor this deep is not drawn)
		"floor": 160.0, "water_depth_range": 26.0, "water_alpha_deep": 1.0, "water_foam_amount": 0.14,
		"murk": 0.035,
		"motes": Color(0.4, 0.9, 1.0),
	},
	{
		"name": "SHALLOW SEA", "at": Vector2(58.3, -147.5), "tier": 1, "salt": true,
		"next": ["COASTLINE", "THE HARBOR"],
		"objective": {"type": "on_beat", "n": 5},
		"tagline": "COLD GREEN WATER, AND THE SEA FLOOR IN SIGHT",
		"fact": "AT SEA A SALMON IS SILVER: DARK ABOVE AND PALE BELOW, HARD TO SPOT FROM EITHER SIDE.",
		"seed": 5202, "length": 2800.0,
		# the continental shelf off Alaska: open water still, not as wide as the ocean, with the
		# floor in sight under it, the fishing fleet about, and things in the way at last
		"width": 90.0, "slope": 0.0, "curve": 0.4, "spacing": 1.4,
		"kinds": ["rings", "rocks", "ramps", "rails", "rocks", "predators", "ramps"],
		# two layers down, over a floor not far under them
		"layers": 2, "layer_depth": 2.6,
		"deep": ["surge", "jellies", "currents", "jellies", "launch"],
		"falls_every": 0.0, "predator": "shark", "predator_word": "CHOMPED!",
		"profile": [[-0.5, -1.2, 0, 0], [4.0, -3.0, 0, 0], [60.0, -3.0, 0, 0], [170.0, -3.0, 0, 0]],
		"bank_colors": [Color(0.2, 0.3, 0.3), Color(0.2, 0.3, 0.3), Color(0.2, 0.3, 0.3)],
		# (grey sand and shingle)
		"bed": Color(0.4, 0.45, 0.42), "cliff": Color(0.4, 0.42, 0.42),
		"sea_from": 0.8, "markers": [Color(0.95, 0.5, 0.1), Color(1.0, 0.9, 0.3)],
		# what is in the way: the floats of crab pots, in strings. They float, so a dive passes
		# under them
		"rock": Color(0.95, 0.4, 0.12), "rock_cap": Color(1.0, 0.9, 0.3), "rock_mesh": "buoy", "rocks_float": true,
		"rock_word": "TANGLED!",
		"ramp": Color(0.3, 0.42, 0.45), "ramp_top": Color(0.85, 0.95, 0.95),
		"rail": Color(0.8, 0.55, 0.2), "rail_node": Color(0.95, 0.95, 0.9),
		"arch": Color(0.6, 0.66, 0.68), "ruins": false,
		"peak": Color(0.95, 0.97, 1.0), "hill": Color(0.3, 0.38, 0.42),
		"scatter": [
			# the fishing fleet, near and far; a freighter or two further out; and the
			# mountains of the coast along the horizon
			["boat", 0.07, 6.0, 60.0, 0.9, 1.3, 0.0, "water"],
			["boat", 0.1, 60.0, 130.0, 1.0, 1.6, 0.0, "water"],
			["driftwood", 0.05, 4.0, 50.0, 0.8, 1.4, -0.1, "water"],
			["ship", 0.012, 90.0, 140.0, 1.0, 1.0, 0.0, "water"],
			["mountain", 0.5, 150.0, 190.0, 1.0, 1.8, -4.0, "far"],
		],
		"sky_top": Color(0.08, 0.24, 0.5), "sky_horizon": Color(0.52, 0.74, 0.84),
		"sky_bottom": Color(0.3, 0.48, 0.52), "sun": Color(1.0, 0.96, 0.84), "sun_dir": Vector3(-0.3, 0.42, -1.0),
		"fog": Color(0.46, 0.66, 0.76), "fog_density": 0.004,
		"ambient": Color(0.62, 0.74, 0.8), "ambient_energy": 0.95,
		"light": Color(1.0, 0.96, 0.88), "light_energy": 1.15,
		"water_deep": Color(0.02, 0.15, 0.26), "water_shallow": Color(0.1, 0.42, 0.48),
		"water_beat": Color(0.5, 1.0, 0.9), "swell": 2.0,
		# clear enough to see the floor, some way down
		"floor": 17.0, "water_depth_range": 16.0, "water_alpha_shallow": 0.35, "water_alpha_deep": 0.72, "water_foam_amount": 0.14,
		"motes": Color(0.8, 1.0, 0.95),
	},
	{
		"name": "COASTLINE", "at": Vector2(51, -129.5), "tier": 2, "order": 0, "salt": false,
		"next": ["THE FISH LADDER", "DRY RIVERBED"],
		"objective": {"type": "clean", "n": 2},
		"tagline": "YOU CAN SMELL THE RIVER FROM HERE",
		"fact": "CLOSE TO SHORE, SCENT LEADS A SALMON BACK TO THE VERY STREAM WHERE IT HATCHED.",
		"seed": 6303, "length": 3000.0,
		# still the sea: wide water with the beach along one side only, and the open Pacific
		# on the other
		"width": 70.0, "slope": 0.004, "curve": 0.7, "uphill": true, "shore": 1.0,
		"sea_from": 0.8, "markers": [Color(0.9, 0.3, 0.15), Color(1.0, 0.85, 0.4)],
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
		"name": "RAINFOREST FALLS", "at": Vector2(47.0, -122.05), "tier": 4, "order": 0, "salt": false,
		"next": ["ALPINE LAKE"],
		"objective": {"type": "rings", "n": 14},
		"tagline": "MOSS, MIST AND GIANT CEDARS. LEAP THE FALLS",
		"fact": "A SALMON CAN LEAP A WATERFALL AROUND TWO METRES HIGH.",
		"seed": 1987, "length": 3400.0,
		"width": 19.0, "slope": 0.03, "curve": 1.0,
		"kinds": ["ramps", "rails", "rocks", "rings", "ramps", "rails"],
		"falls_every": 420.0, "uphill": true, "predator": "bear", "predator_word": "BEAR'D!",
		"profile": [[-0.5, -1.2, 0, 0], [2.5, 0.6, 0.4, 0], [7.0, 2.4, 1.5, 1.0], [15.0, 4.0, 0, 3.0],
				[27.0, 7.0, 2.0, 5.0], [46.0, 18.0, 0, 6.0]],
		"bank_colors": [Color(0.34, 0.3, 0.24), Color(0.3, 0.44, 0.2), Color(0.2, 0.42, 0.18),
				Color(0.14, 0.34, 0.18), Color(0.1, 0.26, 0.16)],
		"bed": Color(0.34, 0.3, 0.22), "cliff": Color(0.42, 0.4, 0.38),
		"rock": Color(0.4, 0.4, 0.38), "rock_cap": Color(0.3, 0.52, 0.2),
		"ramp": Color(0.4, 0.3, 0.2), "ramp_top": Color(0.3, 0.5, 0.22),
		"rail": Color(0.42, 0.3, 0.2), "rail_node": Color(0.3, 0.48, 0.2),
		"arch": Color(0.42, 0.32, 0.22), "ruins": false,
		"scatter": [
			# a temperate rainforest: big conifers, a few mossy broadleaves, ferns everywhere
			["pine", 0.9, 6.0, 42.0, 1.3, 2.3, -0.5, "bank"],
			["pine", 0.6, 40.0, 46.0, 2.0, 2.8, -0.5, "bank"],
			["tree", 0.2, 5.0, 30.0, 0.7, 1.1, -0.4, "bank"],
			["larch", 0.08, 4.0, 20.0, 0.5, 0.8, -0.5, "bank"],
			["fern", 1.0, 1.0, 14.0, 0.9, 1.7, -0.1, "bank"],
			["fern", 0.6, 10.0, 30.0, 1.0, 1.8, -0.1, "bank"],
			["bush", 0.4, 4.0, 25.0, 0.8, 1.4, -0.3, "bank"],
			["rock", 0.25, 0.0, 6.0, 0.7, 2.2, -0.3, "bank"],
			["driftwood", 0.14, 0.5, 6.0, 1.0, 1.8, 0.1, "bank"],
			["shroom", 0.2, 2.0, 20.0, 0.8, 1.6, 0.0, "bank"],
			["reeds", 0.2, -1.5, 0.5, 0.8, 1.3, 0.0, "water"],
			["hill", 0.6, 70.0, 160.0, 1.0, 1.0, 0.0, "far"],
		],
		"hill": Color(0.1, 0.26, 0.2), "snow": 0.0,
		"sky_top": Color(0.3, 0.4, 0.46), "sky_horizon": Color(0.82, 0.88, 0.82),
		"sky_bottom": Color(0.16, 0.26, 0.22), "sun": Color(1.0, 0.96, 0.82), "sun_dir": Vector3(0.2, 0.3, -1.0),
		"fog": Color(0.7, 0.8, 0.74), "fog_density": 0.009,
		"ambient": Color(0.56, 0.68, 0.62), "ambient_energy": 0.85,
		"light": Color(0.96, 1.0, 0.9), "light_energy": 1.0,
		"water_deep": Color(0.04, 0.24, 0.26), "water_shallow": Color(0.3, 0.62, 0.54),
		"water_beat": Color(0.25, 1.0, 0.8), "swell": 1.0,
		"motes": Color(0.85, 1.0, 0.8),
	},
	{
		"name": "MOUNTAIN RIVER", "at": Vector2(46.9, -121.4), "tier": 4, "order": 1, "salt": false,
		"next": ["ALPINE LAKE"],
		"objective": {"type": "rings", "n": 14},
		"tagline": "COLD, FAST AND STEEP",
		"fact": "MALES GROW A HOOKED JAW, THE KYPE, TO FIGHT FOR A PLACE TO SPAWN.",
		"seed": 7405, "length": 3200.0,
		"width": 17.0, "slope": 0.045, "curve": 1.15,
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
		"name": "ALPINE LAKE", "at": Vector2(46.55, -121.75), "tier": 5, "order": 0, "salt": false,
		"ending": "HOME AT LAST. SPAWNED!",
		"tagline": "WHERE IT ALL BEGAN",
		"fact": "THE FEMALE DIGS A NEST IN THE GRAVEL WITH HER TAIL. IT IS CALLED A REDD.",
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
	# ---------------------------------------------------------------- the other ways home
	{
		"name": "ARCTIC WATERS", "at": Vector2(66, -168), "tier": 2, "order": 3, "salt": true,
		"next": ["MEANDERING RIVER", "NEON HARBOR"],
		"objective": {"type": "rings", "n": 12},
		"tagline": "PACK ICE UNDER THE NORTHERN LIGHTS",
		"fact": "SALMON NEED COLD WATER, AND ARE TURNING UP FURTHER NORTH AS THE SEAS WARM.",
		"seed": 5909, "length": 2800.0,
		"width": 100.0, "slope": 0.0, "curve": 0.6, "spacing": 1.4,
		"kinds": ["rocks", "ramps", "rings", "predators", "rocks", "rails"],
		"falls_every": 0.0, "predator": "shark", "predator_word": "CHOMPED!",
		"profile": [[-0.5, -1.2, 0, 0], [4.0, -3.0, 0, 0], [60.0, -3.0, 0, 0], [170.0, -3.0, 0, 0]],
		"bank_colors": [Color(0.02, 0.08, 0.14), Color(0.02, 0.07, 0.12), Color(0.02, 0.07, 0.12)],
		"bed": Color(0.1, 0.3, 0.36), "cliff": Color(0.3, 0.35, 0.42),
		"sea_from": 0.8, "markers": [Color(0.9, 0.2, 0.15), Color(0.4, 1.0, 0.7)],
		"rock": Color(0.78, 0.9, 1.0), "rock_cap": Color(1.0, 1.0, 1.0),
		"ramp": Color(0.6, 0.8, 0.95), "ramp_top": Color(0.92, 0.97, 1.0),
		"rail": Color(0.7, 0.9, 1.0), "rail_node": Color(0.95, 0.98, 1.0),
		"arch": Color(0.7, 0.84, 0.94), "ruins": false,
		"scatter": [
			["floe", 0.7, 2.0, 70.0, 0.8, 2.6, 0.0, "water"],
			["iceberg", 0.16, 16.0, 120.0, 0.8, 2.8, 0.0, "water"],
			["iceberg", 0.8, 100.0, 160.0, 2.5, 5.5, 0.0, "far"],
		],
		"sky_top": Color(0.0, 0.03, 0.1), "sky_horizon": Color(0.16, 0.86, 0.6),
		"sky_bottom": Color(0.03, 0.14, 0.2), "sun": Color(0.8, 1.0, 0.92), "sun_dir": Vector3(-0.3, 0.2, -1.0),
		"fog": Color(0.1, 0.34, 0.36), "fog_density": 0.01,
		"ambient": Color(0.4, 0.66, 0.74), "ambient_energy": 0.9,
		"light": Color(0.7, 0.95, 0.9), "light_energy": 0.95,
		"water_deep": Color(0.01, 0.1, 0.16), "water_shallow": Color(0.1, 0.4, 0.44),
		"water_beat": Color(0.3, 1.0, 0.7), "swell": 1.6,
		"floor": 38.0, "water_depth_range": 22.0, "water_alpha_deep": 0.9, "water_foam_amount": 0.2,
		"motes": Color(0.9, 1.0, 1.0),
	},
	{
		"name": "THE HARBOR", "at": Vector2(47.25, -122.5), "tier": 2, "order": 1, "salt": false,
		"next": ["THE FISH FARM", "THE FISH LADDER"],
		"objective": {"type": "score", "n": 60000},
		"tagline": "QUAYS, CRANES AND SODIUM LIGHT",
		"fact": "WHERE RIVER MEETS SEA, A SALMON'S BODY READJUSTS FROM SALT WATER TO FRESH.",
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
		"name": "THE FISH LADDER", "at": Vector2(47.67, -122.4), "tier": 3, "order": 2, "salt": false,
		"next": ["MOUNTAIN RIVER", "ALPINE LAKE"],
		"objective": {"type": "on_beat", "n": 6},
		"tagline": "A DAM IN THE WAY. ONE STEP AT A TIME",
		"fact": "A FISH LADDER IS A STAIRCASE OF POOLS THAT LETS SALMON CLIMB PAST A DAM.",
		"seed": 7911, "length": 3000.0,
		"meander": 0.35, "width": 17.0, "slope": 0.03, "curve": 0.25, "uphill": true,
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
		"name": "THE FISH FARM", "at": Vector2(48.4, -122.75), "tier": 3, "order": 3, "salt": false, "farm": true,
		"ending": "SPAWNED... IN A FISH FARM",
		"tagline": "THE SHORT WAY: NOT HOME, BUT THERE ARE PELLETS",
		"fact": "MOST ATLANTIC SALMON SOLD AS FOOD IS FARMED, RAISED IN NET PENS LIKE THESE.",
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
	{
		"name": "OCEAN TRENCH", "at": Vector2(11, 142), "tier": 1, "salt": true,
		"next": ["CORAL REEF", "ARCTIC WATERS"],
		"objective": {"type": "on_beat", "n": 5},
		"tagline": "NOTHING BUT DARK WATER AND LIVING LIGHT",
		"fact": "SALMON ARE THOUGHT TO FIND THEIR WAY ACROSS OPEN OCEAN BY THE EARTH'S MAGNETIC FIELD.",
		"seed": 5313, "length": 2800.0,
		"width": 110.0, "slope": 0.0, "curve": 0.4, "spacing": 1.5,
		"layers": 3, "layer_depth": 3.6,
		"deep": ["jellies", "currents", "surge", "jellies", "launch"],
		"kinds": ["rings", "rocks", "predators", "ramps", "rails", "rings"],
		"falls_every": 0.0, "predator": "shark", "predator_word": "CHOMPED!",
		"profile": [[-0.5, -1.2, 0, 0], [4.0, -3.0, 0, 0], [60.0, -3.0, 0, 0], [170.0, -3.0, 0, 0]],
		"bank_colors": [Color(0.02, 0.02, 0.06), Color(0.01, 0.01, 0.05), Color(0.01, 0.01, 0.05)],
		"bed": Color(0.1, 0.08, 0.26), "cliff": Color(0.2, 0.2, 0.28),
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
		"floor": 90.0, "water_depth_range": 40.0, "water_alpha_deep": 0.9, "water_foam_amount": 0.1,
		"motes": Color(0.3, 1.0, 0.9),
	},
	{
		"name": "CORAL REEF", "at": Vector2(26.3, 127.8), "tier": 2, "order": 2, "salt": true,
		"next": ["NEON HARBOR", "MEANDERING RIVER", "DRY RIVERBED"],
		"objective": {"type": "rings", "n": 14},
		"tagline": "A GARDEN UNDER GLASS",
		"fact": "SOME SALMON RANGE THOUSANDS OF MILES ACROSS THE NORTH PACIFIC BEFORE THEY RETURN.",
		"seed": 6314, "length": 3000.0,
		# wide water over the reef, with a beach along one side only
		"width": 70.0, "slope": 0.0, "curve": 0.9, "shore": -1.0,
		"kinds": ["rocks", "rings", "ramps", "rocks", "predators", "rails"],
		"falls_every": 0.0, "predator": "shark", "predator_word": "CHOMPED!",
		"profile": [[-0.5, -1.2, 0, 0], [3.0, 0.4, 0.3, 0], [10.0, 1.3, 0.5, 0.4], [24.0, 2.4, 0.6, 1.0],
				[60.0, 5.0, 1.0, 2.5], [170.0, 7.0, 0, 4.0]],
		"bank_colors": [Color(0.9, 0.86, 0.68), Color(0.97, 0.93, 0.76), Color(0.93, 0.88, 0.7),
				Color(0.5, 0.7, 0.4), Color(0.36, 0.58, 0.34)],
		"bed": Color(0.8, 0.84, 0.66), "cliff": Color(0.7, 0.66, 0.55),
		"sea_from": 0.8, "markers": [Color(1.0, 0.45, 0.55), Color(1.0, 0.8, 0.4)],
		"rock": Color(1.0, 0.5, 0.6), "rock_cap": Color(0.6, 0.4, 1.0),
		"ramp": Color(0.85, 0.6, 0.55), "ramp_top": Color(1.0, 0.8, 0.5),
		"rail": Color(0.4, 0.8, 0.5), "rail_node": Color(0.25, 0.55, 0.35),
		"arch": Color(0.9, 0.8, 0.7), "ruins": false,
		"scatter": [
			["palm", 0.3, 5.0, 26.0, 0.8, 1.3, -0.3, "bank"],
			["grass", 0.5, 8.0, 40.0, 0.8, 1.4, -0.1, "bank"],
			["umbrella", 0.06, 4.0, 10.0, 0.9, 1.2, 0.0, "bank"],
			["bush", 0.4, 24.0, 60.0, 0.9, 1.8, -0.3, "bank"],
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
		# clear water over white sand a few metres down
		"floor": 6.0, "water_depth_range": 9.0, "water_alpha_shallow": 0.3, "water_alpha_deep": 0.7, "water_foam_amount": 0.12,
		"motes": Color(1.0, 0.8, 0.9),
	},
	{
		"name": "BAMBOO RIVER", "at": Vector2(43.6, 142.8), "tier": 4, "order": 2, "route": "japan", "salt": false,
		"next": ["THE CRATER LAKE"],
		"objective": {"type": "flow", "n": 4},
		"tagline": "A MOUNTAIN STREAM UNDER BAMBOO AND RED MAPLES",
		"fact": "JAPAN HAS A SALMON OF ITS OWN: THE MASU, FOUND ONLY IN THE WESTERN PACIFIC.",
		"seed": 7315, "length": 3200.0,
		"width": 17.0, "slope": 0.035, "curve": 1.1, "uphill": true,
		"kinds": ["rails", "rocks", "ramps", "rings", "rails", "ramps"],
		"falls_every": 380.0, "predator": "bear", "predator_word": "BEAR'D!",
		"profile": [[-0.5, -1.2, 0, 0], [2.0, 0.8, 0.4, 0], [6.0, 2.6, 1.2, 1.0], [14.0, 6.0, 1.0, 3.0],
				[28.0, 11.0, 2.0, 5.0], [50.0, 26.0, 0, 8.0]],
		"bank_colors": [Color(0.4, 0.4, 0.38), Color(0.34, 0.46, 0.26), Color(0.26, 0.46, 0.22),
				Color(0.2, 0.4, 0.22), Color(0.16, 0.32, 0.22)],
		"bed": Color(0.36, 0.36, 0.34), "cliff": Color(0.46, 0.46, 0.46),
		"rock": Color(0.46, 0.46, 0.44), "rock_cap": Color(0.3, 0.5, 0.2),
		"ramp": Color(0.46, 0.44, 0.4), "ramp_top": Color(0.34, 0.5, 0.24),
		"rail": Color(0.5, 0.66, 0.22), "rail_node": Color(0.36, 0.5, 0.16),
		"arch": Color(0.72, 0.16, 0.12), "ruins": false,
		# autumn on the way up: the maples have turned
		"scatter": [
			["bamboo", 0.9, 2.0, 30.0, 0.8, 1.4, -0.3, "bank"],
			["maple", 0.3, 4.0, 40.0, 0.8, 1.4, -0.4, "bank"],
			["pine", 0.4, 24.0, 50.0, 0.9, 1.5, -0.5, "bank"],
			["fern", 0.5, 1.5, 10.0, 0.8, 1.3, -0.1, "bank"],
			["rock", 0.25, 0.0, 6.0, 0.7, 2.0, -0.3, "bank"],
			["lantern", 0.06, 1.5, 4.0, 1.0, 1.2, 0.0, "bank"],
			["torii", 0.025, 3.0, 9.0, 1.0, 1.2, 0.0, "bank"],
			["mountain", 0.7, 90.0, 190.0, 1.0, 1.0, 0.0, "far"],
		],
		"hill": Color(0.22, 0.36, 0.32), "peak": Color(0.36, 0.48, 0.44), "snow": 0.0,
		"leaf": Color(0.86, 0.22, 0.12), "leaf2": Color(0.95, 0.55, 0.12),
		# spring on the way down: cherry blossom, and snow still on the peaks
		"spring": {
			"leaf": Color(1.0, 0.72, 0.82), "leaf2": Color(1.0, 0.86, 0.9),
			"peak": Color(0.94, 0.96, 1.0), "motes": Color(1.0, 0.75, 0.85),
			"water_beat": Color(1.0, 0.7, 0.85),
		},
		"sky_top": Color(0.3, 0.46, 0.7), "sky_horizon": Color(0.96, 0.9, 0.84),
		"sky_bottom": Color(0.3, 0.38, 0.34), "sun": Color(1.0, 0.92, 0.8), "sun_dir": Vector3(-0.3, 0.3, -1.0),
		"fog": Color(0.86, 0.88, 0.85), "fog_density": 0.0075,
		"ambient": Color(0.66, 0.72, 0.72), "ambient_energy": 0.9,
		"light": Color(1.0, 0.94, 0.84), "light_energy": 1.1,
		"water_deep": Color(0.06, 0.26, 0.3), "water_shallow": Color(0.4, 0.74, 0.68),
		"water_beat": Color(1.0, 0.6, 0.3), "swell": 1.0,
		"motes": Color(1.0, 0.5, 0.2),
	},
	{
		"name": "MEANDERING RIVER", "at": Vector2(47.55, -121.8), "tier": 3, "order": 0, "salt": false,
		"next": ["RAINFOREST FALLS", "MOUNTAIN RIVER"],
		"objective": {"type": "score", "n": 70000},
		"tagline": "FARMLAND, BIG SKY AND SLOW BENDS",
		"fact": "ONCE A SALMON REACHES FRESH WATER IT STOPS FEEDING. THE REST IS DONE ON RESERVES.",
		"seed": 8316, "length": 3200.0,
		"width": 21.0, "slope": 0.012, "curve": 1.5, "uphill": true,
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
		"name": "DRY RIVERBED", "at": Vector2(44.05, -121.3), "tier": 3, "order": 1, "salt": false,
		"next": ["MOUNTAIN RIVER", "ALPINE LAKE"],
		"objective": {"type": "rings", "n": 12},
		"tagline": "A THREAD OF WATER THROUGH RED ROCK",
		"fact": "LOW, WARM WATER CAN STOP A RUN: SALMON HOLD IN DEEP POOLS AND WAIT FOR RAIN.",
		"seed": 8317, "length": 3000.0,
		"width": 16.0, "slope": 0.02, "curve": 1.2, "uphill": true,
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
	# ---------------------------------------------------------------- the Japan route's own harbor and endings
	# ("like" borrows every setting of another stage; anything listed here replaces it. The two
	# endings only replace looks, so they play exactly like the North American ones.)
	{
		"name": "NEON HARBOR", "like": "THE HARBOR", "at": Vector2(35.45, 139.85), "tier": 3, "order": 4,
		"route": "japan", "salt": false,
		"next": ["THE HATCHERY", "BAMBOO RIVER"],
		"objective": {"type": "score", "n": 60000},
		"tagline": "A PORT CITY THAT NEVER GOES DARK",
		"fact": "JAPAN'S HATCHERIES RELEASE MORE THAN A BILLION YOUNG CHUM SALMON EVERY YEAR.",
		"seed": 6920,
		# the same quays and cranes, under pink and violet city light instead of sodium orange
		"sky_top": Color(0.04, 0.02, 0.12), "sky_horizon": Color(0.9, 0.3, 0.62),
		"sky_bottom": Color(0.08, 0.04, 0.12), "sun": Color(1.0, 0.6, 0.85),
		"fog": Color(0.32, 0.14, 0.32), "ambient": Color(0.5, 0.42, 0.7),
		"light": Color(1.0, 0.7, 0.9),
		"water_deep": Color(0.04, 0.03, 0.12), "water_shallow": Color(0.26, 0.14, 0.36),
		"water_beat": Color(1.0, 0.3, 0.7), "motes": Color(1.0, 0.5, 0.85),
		"rock": Color(0.8, 0.25, 0.55), "rock_cap": Color(0.8, 0.25, 0.55),
	},
	{
		"name": "THE CRATER LAKE", "like": "ALPINE LAKE", "at": Vector2(42.75, 141.35), "tier": 5, "order": 2,
		"route": "japan", "salt": false,
		"ending": "HOME AT LAST. SPAWNED!",
		"tagline": "STILL WATER IN AN OLD VOLCANO",
		"fact": "AFTER SPAWNING BOTH PARENTS DIE, AND THEIR BODIES FEED THE RIVER.",
		"arch": Color(0.72, 0.16, 0.12),
		"scatter": [
			["pine", 0.5, 66.0, 120.0, 0.9, 1.6, -0.5, "bank"],
			["maple", 0.5, 64.0, 110.0, 0.9, 1.5, -0.4, "bank"],
			["bamboo", 0.3, 63.0, 90.0, 0.8, 1.3, -0.3, "bank"],
			["torii", 0.02, 62.0, 68.0, 1.2, 1.6, 0.0, "bank"],
			["lantern", 0.05, 62.0, 68.0, 1.0, 1.3, 0.0, "bank"],
			["rock", 0.25, 62.0, 80.0, 0.8, 2.4, -0.4, "bank"],
			["lily", 0.14, 3.0, 40.0, 0.9, 1.6, 0.04, "water"],
			["reeds", 0.2, 4.0, 60.0, 0.8, 1.4, 0.0, "water"],
			["mountain", 0.9, 130.0, 210.0, 1.0, 1.0, 0.0, "far"],
		],
		"leaf": Color(0.86, 0.22, 0.12), "leaf2": Color(0.95, 0.55, 0.12),
		"hill": Color(0.26, 0.34, 0.36), "peak": Color(0.5, 0.5, 0.58),
		"spring": {
			"leaf": Color(1.0, 0.72, 0.82), "leaf2": Color(1.0, 0.86, 0.9),
			"peak": Color(0.94, 0.96, 1.0), "motes": Color(1.0, 0.75, 0.85),
			"sky_top": Color(0.12, 0.3, 0.75), "sky_horizon": Color(0.9, 0.86, 0.92),
			"sky_bottom": Color(0.3, 0.4, 0.5), "sun": Color(1.0, 1.0, 0.9), "sun_dir": Vector3(-0.3, 0.4, -1.0),
			"fog": Color(0.84, 0.84, 0.92), "ambient": Color(0.68, 0.72, 0.86), "light": Color(1.0, 0.97, 0.92),
			"water_deep": Color(0.06, 0.24, 0.42), "water_shallow": Color(0.5, 0.8, 0.88), "water_beat": Color(1.0, 0.7, 0.85),
		},
	},
	{
		"name": "THE HATCHERY", "like": "THE FISH FARM", "at": Vector2(39.6, 141.9), "tier": 4, "order": 3,
		"route": "japan", "salt": false,
		"ending": "SPAWNED... IN A HATCHERY",
		"tagline": "NEAT PENS, CLEAN WATER, NO WAY OUT",
		"fact": "A HATCHERY TAKES EGGS FROM RETURNING ADULTS AND RAISES THE YOUNG FOR RELEASE.",
		"markers": [Color(0.85, 0.2, 0.15), Color(1.0, 0.9, 0.8)],
		"scatter": [
			["pen", 0.1, 8.0, 54.0, 1.0, 1.7, 0.0, "water"],
			["shed", 0.02, 10.0, 50.0, 0.7, 1.0, 0.3, "water"],
			["pine", 0.5, 66.0, 120.0, 0.9, 1.6, -0.5, "bank"],
			["bamboo", 0.5, 64.0, 100.0, 0.8, 1.3, -0.3, "bank"],
			["shed", 0.1, 64.0, 80.0, 1.0, 1.6, 0.0, "bank"],
			["lamp", 0.15, 62.0, 70.0, 1.0, 1.3, 0.0, "bank"],
			["mountain", 0.7, 130.0, 210.0, 1.0, 1.0, 0.0, "far"],
		],
	},
]

## Where a run starts, and the stage the training course borrows its look from.
const START := 0

## A true thing about a young salmon at each step of the way down, from the open ocean (step
## 1) back to the lake (step 6). From the National Park Service's account of the life cycle.
const DOWN_FACTS := [
	"SOME SALMON STAY AT SEA EIGHTEEN MONTHS, OTHERS AS LONG AS EIGHT YEARS.",
	"OUT AT SEA, A YOUNG SALMON DOES LITTLE BUT FEED AND GROW.",
	"ESTUARIES, AT THE MOUTH OF THE RIVER, ARE CRUCIAL TO THE SURVIVAL OF YOUNG SMOLTS.",
	"HEADING FOR THE SEA, A YOUNG SALMON'S SCALES GROW AND TURN SILVER: IT IS NOW A SMOLT.",
	"AT NIGHT, TO AVOID PREDATORS, SMALL FRY LET THE RIVER CARRY THEM DOWNSTREAM TAIL FIRST.",
	"YOUNG SOCKEYE SPEND A YEAR OR TWO IN A LAKE BEFORE THEY LEAVE FOR THE SEA.",
]
const RAINFOREST := 3


## Everything about a stage, with whatever it borrows from another ("like") filled in.
static func settings(id: int) -> Dictionary:
	var own: Dictionary = LIST[id]
	if not own.has("like"):
		return own.duplicate()
	var out: Dictionary = LIST[find(own.like)].duplicate()
	out.merge(own, true)
	return out


static func find(stage_name: String) -> int:
	for i in LIST.size():
		if LIST[i].name == stage_name:
			return i
	return -1


## The stages this one leads to heading upstream, the default first (see "next").
static func next_of(id: int) -> Array[int]:
	var out: Array[int] = []
	for stage_name: String in LIST[id].get("next", []):
		var stage := find(stage_name)
		if stage != -1:
			out.append(stage)
	return out


## True for the stages a run up ends on (the spawning grounds).
static func is_end(id: int) -> bool:
	return next_of(id).is_empty()


## True when the way on from this stage forks (so its goal matters).
static func forks(id: int) -> bool:
	return next_of(id).size() > 1


## Where you can go next heading upstream. The default is always open; meeting the stage's
## goal opens its other, more advanced ways on as well.
static func next_up(id: int, met: bool) -> Array[int]:
	var all := next_of(id)
	if met or all.size() <= 1:
		return all
	return [all[0]] as Array[int]


## The stages that lead to this one, those it is the default for first.
static func before(id: int) -> Array[int]:
	var out: Array[int] = []
	for i in LIST.size():
		var onward := next_of(i)
		if not onward.is_empty() and onward[0] == id:
			out.append(i)
	for i in LIST.size():
		if next_of(i).has(id) and not out.has(i):
			out.append(i)
	return out


## The next stage heading back downstream: the way you came up if we know it, otherwise a
## stage that leads here.
static func prev_down(id: int, route: Array[int]) -> int:
	var from := before(id)
	for r in route:
		if from.has(r):
			return r
	return from[0] if not from.is_empty() else -1


## A way up to this stage from the start, ending with the stage itself.
static func path_to(id: int) -> Array[int]:
	var out: Array[int] = [id]
	while not before(out[0]).is_empty() and out.size() < LIST.size():
		out.push_front(before(out[0])[0])
	return out


## The way down to this stage from the spawning grounds above it, ending with the stage itself.
static func path_from_top(id: int) -> Array[int]:
	var out: Array[int] = [id]
	while not is_end(out[0]) and out.size() < LIST.size():
		out.push_front(next_of(out[0])[0])
	return out


## The stages on one tier of the map, left to right.
static func on_tier(tier: int) -> Array[int]:
	var out: Array[int] = []
	for i in LIST.size():
		if int(LIST[i].tier) == tier:
			out.append(i)
	out.sort_custom(func(a: int, b: int) -> bool: return int(LIST[a].get("order", a)) < int(LIST[b].get("order", b)))
	return out


static func tiers() -> int:
	var top := 0
	for stage: Dictionary in LIST:
		top = maxi(top, int(stage.tier))
	return top + 1


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
