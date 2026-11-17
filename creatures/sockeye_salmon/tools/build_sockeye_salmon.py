"""Builds the sockeye salmon (creatures/sockeye_salmon) and exports it for Godot.

Run from the game's root:
    blender --background --python creatures/sockeye_salmon/tools/build_sockeye_salmon.py
    blender --background --python creatures/sockeye_salmon/tools/build_sockeye_salmon.py -- <preview folder>   # with pictures
    blender --background --python creatures/sockeye_salmon/tools/build_sockeye_salmon.py -- <preview folder> parr smolt   # only these

One shape for each stage of its life (STAGES: fry, parr, smolt, ocean, migrating, spawner, spawner_female). For
each it writes creatures/sockeye_salmon/models/sockeye_<stage>.glb (the full model, for close pictures) and
sockeye_<stage>_lo.glb (far off, phones, packs of fish), and the editable
creatures/sockeye_salmon/tools/sockeye_<stage>.blend (this folder has a .gdignore). Each model is one still mesh
with one surface: the shader (sockeye_salmon.gdshader) bends it to swim, works its jaw, gill covers and fins, and
draws every marking. It prints a WINDING line for each model: the check that nothing is inside out. With a preview
folder, each stage's pictures go into a folder of its own inside it.

Every stage is built to the same length, 0.6 m from snout to tail tip (SockeyeSalmon.SIZE says how long each
really is beside the adult), nose towards -Z, belly down, its origin at the middle of its length on the line
through snout and tail. Two shapes are written out in full, row by row: the OCEAN fish (streamlined, no hump, a
plain snout) and the spawning male, the SPAWNER (described below). The others are made from those by SHAPES: the
MIGRATING fish part of the way from the one to the other; the spawning female the ocean fish deeper in the belly;
the young (fry, parr, smolt) the ocean fish with a longer, taller head, a bigger eye, a slimmer body and fins and a
tail of their own. Built from the species' anatomy (the component's README names what was looked at). The spawning
male:

- THE BODY: one skin from snout to the root of the tail, flat-sided, its back humped: it rises behind the head to
  its highest just ahead of the dorsal fin, then narrows to the wrist of the tail and flares a little where the
  tail's rays begin; the gill cover a raised plate with a crescent rear edge.
- THE HEAD: long, a straight-topped cone. The upper head and snout are the front of the body's skin, flat
  underneath (the roof of the mouth), and the snout's tip turns down in a hook (the kype); the LOWER JAW is a part
  of its own whose tip turns up behind that hook, which fits up inside the upper lip and runs back into the throat
  (the shader swings it about its hinge behind the eye); a MAXILLA on each side, the plate along the upper lip,
  reaching back past the eye; EYES, small domes set in the sides of the head.
- THE FINS: thin closed solids, thick at the root and fine at the edge, with their rays as ridges: the dorsal
  (thirteen rays), the small fleshy adipose, the shallowly forked tail (nineteen), the long-based anal (fifteen),
  and a pair each of pelvic and pectoral fins held out and down like small wings.

What a point is, for the shader: vertex colour red the part, as a tenth (0 body, 0.1 lower jaw, 0.2
eye, 0.3 maxilla, 0.4 dorsal, 0.5 adipose, 0.6 tail, 0.7 anal, 0.8 pelvic, 0.9 pectoral). On the body: UV.x how far along the
fish (0 snout to 1 tail tip), UV.y how high on it (0 belly line to 1 back line); UV2.x how far round the skin from
the back line (metres, + on its right side, - on its left), UV2.y the whole way from back line to belly line there
(metres); green how much of the gill cover's moving edge it is, blue how much it is inside the mouth. On the jaw:
UV as the body's but UV.y from its keel (0) to its lip (1); UV2.x how far to the side (metres); blue the inside of
the mouth. On an eye: UV where a point is on its round face seen straight on (its middle at 0.5, 0.5; its rim 0.5 away). On a fin: UV.x along its rays (0 root to 1 edge),
UV.y across it counted in rays (0 its leading edge); UV2 and blue the way its flat side faces (x, y, and z as
z / 2 + 0.5), which is the way the shader waves it. (The glTF writer flips V: what is written here is 1 - v, so
that Godot reads v.)

Everything here is worked out in body lengths in Godot space (Y up, nose towards -Z) and written out in metres.
The numbers the shader and the script share (LENGTH, the jaw's hinge, the gill cover's edge) are kept in step by
hand: change one, change the others.
"""

import bisect
import math
import os
import sys

import bmesh
import bpy
from mathutils import Vector
from mathutils.bvhtree import BVHTree

HERE = os.path.dirname(os.path.abspath(__file__))
OUT = os.path.join(HERE, "..", "models")
ARGS = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
PREVIEW = ARGS[0] if ARGS else ""
STAGES = ["fry", "parr", "smolt", "ocean", "migrating", "spawner", "spawner_female"]
WANTED = [name for name in ARGS[1:] if name in STAGES] or STAGES

# Kept in step with sockeye_salmon.gd and sockeye_salmon.gdshader.
LENGTH = 0.6
TAU = math.tau
BODY, JAW, EYE, MAXILLA, DORSAL, ADIPOSE, TAIL, ANAL, PELVIC, PECTORAL = 0, 1, 2, 3, 4, 5, 6, 7, 8, 9


def to_b(p):
    return Vector((p.x, -p.z, p.y))


def smooth(a, b, x):
    t = max(0.0, min(1.0, (x - a) / (b - a)))
    return t * t * (3.0 - 2.0 * t)


def lerp(a, b, t):
    return a + (b - a) * t


def curve(points):
    """A smooth line through (x, y) points that never overshoots them."""
    xs = [p[0] for p in points]
    ys = [p[1] for p in points]
    n = len(xs)
    h = [xs[i + 1] - xs[i] for i in range(n - 1)]
    d = [(ys[i + 1] - ys[i]) / h[i] for i in range(n - 1)]
    m = [0.0] * n
    m[0], m[-1] = d[0], d[-1]
    for i in range(1, n - 1):
        if d[i - 1] * d[i] > 0.0:
            w1 = 2.0 * h[i] + h[i - 1]
            w2 = h[i] + 2.0 * h[i - 1]
            m[i] = (w1 + w2) / (w1 / d[i - 1] + w2 / d[i])

    def f(x):
        if x <= xs[0]:
            return ys[0]
        if x >= xs[-1]:
            return ys[-1]
        i = bisect.bisect_right(xs, x) - 1
        t = (x - xs[i]) / h[i]
        t2, t3 = t * t, t * t * t
        return ((2 * t3 - 3 * t2 + 1) * ys[i] + (t3 - 2 * t2 + t) * h[i] * m[i]
                + (-2 * t3 + 3 * t2) * ys[i + 1] + (t3 - t2) * h[i] * m[i + 1])
    return f


class Section:
    """A lofted skin: at each place along the fish (s, 0 snout to 1 tail tip) its top line, bottom line, half
    width, how far up from the bottom it is widest (0..1), and how boxy its upper and lower halves are (2 an
    ellipse, more is squarer). All in body lengths."""

    def __init__(self, rows):
        self.first = rows[0][0]
        self.last = rows[-1][0]
        self.f = [curve([(r[0], r[k]) for r in rows]) for k in range(1, 7)]

    def at(self, s):
        return [f(s) for f in self.f]

    def top(self, s):
        return self.f[0](s)

    def bot(self, s):
        return self.f[1](s)

    def x_at(self, s, y):
        """How far out the skin is at height y."""
        top, bot, hw, ycf, nt, nb = self.at(s)
        yc = bot + ycf * (top - bot)
        if y >= yc:
            u, n = (y - yc) / max(top - yc, 1e-9), nt
        else:
            u, n = (yc - y) / max(yc - bot, 1e-9), nb
        u = max(0.0, min(1.0, u))
        return hw * (1.0 - u ** n) ** (1.0 / n)

    def outline(self, s, half):
        """half + 1 points down its right side from the top line to the bottom line, evenly spaced along the
        skin: (x, y, how far round from the top)."""
        top, bot, hw, ycf, nt, nb = self.at(s)
        yc = bot + ycf * (top - bot)
        dense = []
        steps = 200
        for i in range(steps + 1):
            phi = math.pi * i / steps
            c, sn = math.cos(phi), max(math.sin(phi), 0.0)
            if c >= 0.0:
                dense.append((hw * sn ** (2.0 / nt), yc + (top - yc) * c ** (2.0 / nt)))
            else:
                dense.append((hw * sn ** (2.0 / nb), yc - (yc - bot) * (-c) ** (2.0 / nb)))
        dense[0] = (0.0, top)
        dense[-1] = (0.0, bot)
        acc = [0.0]
        for i in range(steps):
            acc.append(acc[-1] + math.hypot(dense[i + 1][0] - dense[i][0], dense[i + 1][1] - dense[i][1]))
        whole = acc[-1]
        out = []
        for j in range(half + 1):
            want = whole * j / half
            i = min(bisect.bisect_right(acc, want) - 1, steps - 1)
            span = acc[i + 1] - acc[i]
            t = (want - acc[i]) / span if span > 1e-12 else 0.0
            out.append((lerp(dense[i][0], dense[i + 1][0], t), lerp(dense[i][1], dense[i + 1][1], t), want))
        return out, whole


# The body and upper head: s, top, bottom, half width, widest at, boxiness above, below. The two shapes written
# out in full have their rows in step, one for one, so that a shape between them is each row part of the way.
# The fish at sea: streamlined, deepest at the middle, a plain blunt-pointed snout, the mouth to under the eye.
OCEAN_BODY = [
    (0.000, 0.008, -0.001, 0.000, 0.30, 2.0, 2.6),
    (0.004, 0.022, -0.007, 0.016, 0.30, 2.0, 2.6),
    (0.012, 0.031, -0.011, 0.024, 0.30, 2.0, 2.9),
    (0.024, 0.039, -0.014, 0.030, 0.29, 2.0, 3.1),
    (0.036, 0.045, -0.017, 0.034, 0.28, 2.0, 3.2),
    (0.052, 0.051, -0.020, 0.038, 0.27, 2.0, 3.2),
    (0.070, 0.057, -0.023, 0.042, 0.27, 2.1, 3.2),
    (0.088, 0.063, -0.027, 0.046, 0.27, 2.1, 3.2),
    (0.105, 0.068, -0.030, 0.049, 0.30, 2.2, 3.0),
    (0.131, 0.075, -0.062, 0.052, 0.45, 2.2, 2.6),
    (0.165, 0.083, -0.083, 0.055, 0.52, 2.2, 2.4),
    (0.205, 0.091, -0.096, 0.057, 0.56, 2.2, 2.3),
    (0.280, 0.102, -0.110, 0.059, 0.58, 2.2, 2.3),
    (0.360, 0.108, -0.117, 0.060, 0.58, 2.2, 2.3),
    (0.430, 0.108, -0.118, 0.059, 0.58, 2.2, 2.3),
    (0.500, 0.102, -0.112, 0.056, 0.58, 2.2, 2.3),
    (0.600, 0.086, -0.094, 0.048, 0.57, 2.2, 2.2),
    (0.700, 0.066, -0.070, 0.036, 0.55, 2.1, 2.1),
    (0.780, 0.050, -0.052, 0.026, 0.52, 2.0, 2.0),
    (0.830, 0.043, -0.044, 0.018, 0.50, 2.0, 2.0),
    (0.862, 0.045, -0.046, 0.0115, 0.50, 2.0, 2.0),
    (0.885, 0.049, -0.050, 0.0070, 0.50, 2.0, 2.0),
    (0.910, 0.052, -0.053, 0.0035, 0.50, 2.0, 2.0),
    (0.930, 0.046, -0.047, 0.0015, 0.50, 2.0, 2.0),
    (0.938, 0.030, -0.031, 0.000, 0.50, 2.0, 2.0),
]
# The spawning male.
SPAWNER_BODY = [
    # (the kype: the snout's tip hangs down in a hook, and the roof of the mouth rises again behind it)
    (0.000, 0.002, -0.016, 0.000, 0.50, 2.0, 2.0),
    (0.004, 0.018, -0.019, 0.010, 0.48, 2.0, 2.3),
    (0.012, 0.027, -0.017, 0.016, 0.45, 2.0, 2.5),
    (0.024, 0.032, -0.006, 0.021, 0.36, 2.0, 2.8),
    (0.040, 0.037, 0.001, 0.026, 0.30, 2.0, 3.0),
    (0.060, 0.043, -0.005, 0.031, 0.28, 2.0, 3.2),
    (0.085, 0.050, -0.014, 0.036, 0.27, 2.1, 3.2),
    (0.110, 0.058, -0.023, 0.041, 0.27, 2.1, 3.2),
    (0.135, 0.066, -0.034, 0.046, 0.30, 2.2, 3.0),
    (0.162, 0.076, -0.068, 0.050, 0.45, 2.2, 2.6),
    (0.195, 0.088, -0.090, 0.053, 0.52, 2.2, 2.4),
    (0.235, 0.104, -0.104, 0.055, 0.54, 2.1, 2.3),
    # (the hump: a narrow-topped rise to just ahead of the dorsal fin)
    (0.290, 0.130, -0.115, 0.056, 0.52, 1.9, 2.3),
    (0.360, 0.147, -0.121, 0.056, 0.50, 1.75, 2.3),
    (0.430, 0.148, -0.122, 0.055, 0.50, 1.75, 2.3),
    (0.500, 0.133, -0.116, 0.052, 0.52, 1.9, 2.3),
    (0.600, 0.101, -0.098, 0.044, 0.55, 2.1, 2.2),
    (0.700, 0.072, -0.073, 0.034, 0.55, 2.1, 2.1),
    (0.780, 0.051, -0.052, 0.026, 0.52, 2.0, 2.0),
    (0.830, 0.043, -0.044, 0.018, 0.50, 2.0, 2.0),
    (0.862, 0.045, -0.046, 0.0115, 0.50, 2.0, 2.0),
    (0.885, 0.049, -0.050, 0.0070, 0.50, 2.0, 2.0),
    (0.910, 0.052, -0.053, 0.0035, 0.50, 2.0, 2.0),
    (0.930, 0.046, -0.047, 0.0015, 0.50, 2.0, 2.0),
    (0.938, 0.030, -0.031, 0.000, 0.50, 2.0, 2.0),
]
# The lower jaw and throat, as the body's rows. LIP for a top means the lip line: just up inside the upper lip.
LIP = None
OCEAN_JAW = [
    (0.004, -0.010, -0.015, 0.000, 0.75, 3.5, 2.0),
    (0.008, LIP, -0.022, 0.013, 0.75, 3.5, 2.0),
    (0.021, LIP, -0.031, 0.022, 0.78, 3.5, 2.0),
    (0.042, LIP, -0.039, 0.028, 0.80, 3.5, 2.0),
    (0.073, LIP, -0.050, 0.034, 0.80, 3.5, 2.0),
    (0.105, LIP, -0.061, 0.039, 0.80, 3.0, 2.0),
    (0.131, -0.039, -0.070, 0.038, 0.70, 2.4, 2.1),
    (0.158, -0.059, -0.076, 0.023, 0.60, 2.2, 2.1),
    (0.175, -0.069, -0.076, 0.010, 0.50, 2.0, 2.0),
    (0.181, -0.072, -0.073, 0.000, 0.50, 2.0, 2.0),
]
# (the male's begins behind the hook of the snout and turns up, as the roof of the mouth does there)
SPAWNER_JAW = [
    (0.029, -0.004, -0.013, 0.000, 0.75, 3.5, 2.0),
    (0.033, LIP, -0.021, 0.009, 0.75, 3.5, 2.0),
    (0.044, LIP, -0.027, 0.016, 0.78, 3.5, 2.0),
    (0.064, LIP, -0.034, 0.022, 0.80, 3.5, 2.0),
    (0.096, LIP, -0.045, 0.030, 0.80, 3.5, 2.0),
    (0.135, LIP, -0.062, 0.037, 0.80, 3.0, 2.0),
    (0.165, -0.046, -0.076, 0.036, 0.70, 2.4, 2.1),
    (0.195, -0.072, -0.087, 0.022, 0.60, 2.2, 2.1),
    (0.212, -0.084, -0.090, 0.010, 0.50, 2.0, 2.0),
    (0.218, -0.088, -0.089, 0.000, 0.50, 2.0, 2.0),
]
# What else the two shapes written out in full have, each number part of the way for a shape between them:
# where the lower jaw hinges (how far along, how high), the gill cover's rearmost reach, where the eye is, where
# the maxilla begins and ends, how hooked the snout is, and the fins: the dorsal's and the anal's start, base,
# height at the leading edge, how much shorter the trailing edge is and the rake of their first and last rays
# (degrees); the adipose's start and height; the pelvic fins' start.
ENDS = {
    "ocean": {
        "hinge_s": 0.105, "hinge_y": -0.030, "gill_s": 0.205, "eye_s": 0.072, "eye_y": 0.024,
        "maxilla_from": 0.017, "maxilla_to": 0.124, "hook": 0.0,
        "dorsal": (0.455, 0.12, 0.105, 0.052, 66.0, 27.0), "anal": (0.668, 0.105, 0.086, 0.047, 60.0, 25.0),
        "adipose": (0.74, 0.034), "pelvic": 0.522,
    },
    "spawner": {
        "hinge_s": 0.135, "hinge_y": -0.034, "gill_s": 0.236, "eye_s": 0.112, "eye_y": 0.016,
        "maxilla_from": 0.042, "maxilla_to": 0.152, "hook": 1.0,
        "dorsal": (0.462, 0.125, 0.1, 0.05, 64.0, 24.0), "anal": (0.655, 0.12, 0.088, 0.05, 58.0, 22.0),
        "adipose": (0.728, 0.04), "pelvic": 0.512,
    },
}
# Each stage's shape. `mix`: how far it is from the ocean fish (0) to the spawning male (1). Then, for the young
# and the female: `head_k` how much longer the head is, `head_h` and `head_w` how much taller and wider, `depth`
# and `width` how deep and wide the body is, `belly` how much deeper its belly hangs; `eye`: the eyeball's radius,
# how far it stands out of the head, and how much of the dome's width shows (the rest is under the skin);
# `fin` how big its fins are; `tail`: the tail's middle rays, its longest rays (body lengths), how sharply the
# fork is cut (the power) and how far its lobes spread (degrees).
SHAPES = {
    "fry": {"mix": 0.0, "head_k": 1.2, "head_h": 1.14, "head_w": 1.0, "depth": 0.74, "width": 0.78, "belly": 1.0,
            "eye": (0.07, 0.009, 0.85), "eye_y": 0.023, "fin": 0.74, "tail": (0.102, 0.15, 1.3, 23.0)},
    "parr": {"mix": 0.0, "head_k": 1.13, "head_h": 1.08, "head_w": 1.0, "depth": 0.87, "width": 0.88, "belly": 1.0,
             "eye": (0.045, 0.007, 0.75), "eye_y": 0.022, "fin": 1.08, "tail": (0.076, 0.172, 1.4, 27.0)},
    "smolt": {"mix": 0.0, "head_k": 1.04, "head_h": 1.0, "head_w": 0.96, "depth": 0.8, "width": 0.84, "belly": 1.0,
              "eye": (0.036, 0.0055, 0.7), "fin": 1.0, "tail": (0.07, 0.18, 1.4, 27.0)},
    "ocean": {"mix": 0.0, "eye": (0.023, 0.0038, 0.644)},
    "migrating": {"mix": 0.45, "eye": (0.0235, 0.0038, 0.644)},
    "spawner": {"mix": 1.0, "eye": (0.024, 0.0039, 0.644)},
    "spawner_female": {"mix": 0.1, "depth": 1.0, "width": 1.02, "belly": 1.1, "eye": (0.023, 0.0038, 0.644)},
}

# The stage being built (set by `use`): its numbers, its skins, and the places the shader shares.
P = {}
BODY_SKIN = None
JAW_SKIN = None
HINGE_S = 0.0
HINGE_Y = 0.0
GILL_S = 0.0
HOOK = 0.0
EYE_AT = (0.0, 0.0)


def lip(s):
    """The lower jaw's lip line: just up inside the upper lip."""
    return BODY_SKIN.bot(s) + 0.002


def use(stage):
    """Makes `stage` the shape being built."""
    global P, BODY_SKIN, JAW_SKIN, HINGE_S, HINGE_Y, GILL_S, HOOK, EYE_AT
    shape = SHAPES[stage]
    t = shape["mix"]
    a, b = ENDS["ocean"], ENDS["spawner"]

    def between(key):
        if isinstance(a[key], tuple):
            return tuple(lerp(x, y, t) for x, y in zip(a[key], b[key]))
        return lerp(a[key], b[key], t)
    P = {key: between(key) for key in a}
    P.update({"head_k": 1.0, "head_h": 1.0, "head_w": 1.0, "depth": 1.0, "width": 1.0, "belly": 1.0, "fin": 1.0,
              "tail": (0.086, 0.178, 1.5, 27.0)})
    P.update(shape)
    P["stage"] = stage
    gill = P["gill_s"]
    head_k = P["head_k"]

    def along(s):
        """Where a place on the grown fish is on this one: the head longer, the body shorter to make room."""
        if s <= gill:
            return s * head_k
        if s < 0.83:
            return gill * head_k + (s - gill) * (0.83 - gill * head_k) / (0.83 - gill)
        return s
    GILL_S = gill * head_k

    def tall(s):
        return lerp(P["head_h"], P["depth"], smooth(0.6 * GILL_S, 1.25 * GILL_S, s))

    def wide(s):
        return lerp(P["head_w"], P["width"], smooth(0.6 * GILL_S, 1.25 * GILL_S, s))

    def hangs(s):
        return 1.0 + (P["belly"] - 1.0) * smooth(GILL_S + 0.05, 0.38, s) * (1.0 - smooth(0.56, 0.76, s))
    P["along"] = along
    rows = []
    for ra, rb in zip(OCEAN_BODY, SPAWNER_BODY):
        r = [lerp(x, y, t) for x, y in zip(ra, rb)]
        s = along(r[0])
        rows.append((s, r[1] * tall(s), r[2] * tall(s) * hangs(s), r[3] * wide(s), r[4], r[5], r[6]))
    BODY_SKIN = Section(rows)
    rows = []
    for ra, rb in zip(OCEAN_JAW, SPAWNER_JAW):
        s = along(lerp(ra[0], rb[0], t))
        top = lip(s) if ra[1] is LIP else lerp(ra[1], rb[1], t) * tall(s)
        r = [lerp(x, y, t) for x, y in zip(ra[2:], rb[2:])]
        rows.append((s, top, r[0] * tall(s), r[1] * wide(s), r[2], r[3], r[4]))
    JAW_SKIN = Section(rows)
    HINGE_S = along(P["hinge_s"])
    HINGE_Y = P["hinge_y"] * tall(HINGE_S)
    HOOK = P["hook"]
    eye_s = along(P["eye_s"])
    EYE_AT = (eye_s, shape.get("eye_y", P["eye_y"] * tall(eye_s)))
    print("SHAPE %s: hinge_s=%.4f hinge_y=%.4f gill_s=%.4f depth=%.4f width=%.4f" % (
        stage, HINGE_S, HINGE_Y, GILL_S,
        max(BODY_SKIN.top(i / 200.0) - BODY_SKIN.bot(i / 200.0) for i in range(40, 140)),
        2.0 * max(BODY_SKIN.at(i / 200.0)[2] for i in range(40, 140))))


def gill_edge(h):
    """Where the gill cover's rear edge is (s) at a height on the body (0 belly to 1 back): a crescent."""
    return GILL_S - 0.25 * (h - 0.45) ** 2


def gill_plate(s, h):
    """How far the gill cover stands out from the skin behind it (body lengths), and how much of its moving
    edge a point is (0..1)."""
    edge = gill_edge(h)
    band = smooth(0.06, 0.2, h) * (1.0 - smooth(0.78, 0.9, h))
    behind = 1.0 - smooth(edge - 0.004, edge + 0.008, s)
    raised = 0.006 * min(P["width"] + 0.1, 1.0) * smooth(GILL_S - 0.086, GILL_S - 0.018, s) * behind * band
    moving = smooth(GILL_S - 0.068, edge, s) * behind * band
    return raised, moving


def body_x(s, y):
    """How far out the body's skin is at height y, gill cover and all."""
    top, bot = BODY_SKIN.top(s), BODY_SKIN.bot(s)
    h = (y - bot) / max(top - bot, 1e-9)
    return BODY_SKIN.x_at(s, y) + gill_plate(s, h)[0]


def body_frame(s, y):
    """A place on the body's right side: the point, the way out of the skin there, and the way up along it."""
    e = 0.002
    x = body_x(s, y)
    dy = (body_x(s, y + e) - body_x(s, y - e)) / (2 * e)
    ds = (body_x(s + e, y) - body_x(s - e, y)) / (2 * e)
    return Vector((x, y, s - 0.5)), Vector((1.0, -dy, -ds)).normalized(), Vector((dy, 1.0, 0.0)).normalized()


class Part:
    """One closed piece of the fish: points (body lengths), what each is for the shader, and four-cornered
    faces. `done` welds it, turns every face outward and checks that."""

    def __init__(self, name):
        self.name = name
        self.verts = []
        self.data = []
        self.faces = []

    def add(self, p, uv, uv2, colour):
        self.verts.append(Vector(p))
        self.data.append((uv, uv2, colour))
        return len(self.verts) - 1

    def loft(self, rings):
        for a, b in zip(rings, rings[1:]):
            n = len(a)
            for j in range(n):
                self.faces.append((a[j], a[(j + 1) % n], b[(j + 1) % n], b[j]))

    def mirrored(self, name, flip):
        other = Part(name)
        for p, d in zip(self.verts, self.data):
            other.add((-p.x, p.y, p.z), *flip(d))
        other.faces = list(self.faces)
        return other

    @staticmethod
    def inside_out(bm):
        """How many of a closed solid's faces face inwards, and how many were looked at: a line out of a face,
        the way the face faces, comes out through the solid's skin an even number of times (none, for most)."""
        cut = bm.copy()
        bmesh.ops.triangulate(cut, faces=cut.faces)
        cut.normal_update()
        tree = BVHTree.FromBMesh(cut)
        wrong = 0
        counted = 0
        for f in cut.faces:
            if f.calc_area() > 1e-11:
                counted += 1
                at = f.calc_center_median() + f.normal * 2e-6
                hits = 0
                while hits < 40:
                    hit = tree.ray_cast(at, f.normal)
                    if hit[0] is None:
                        break
                    hits += 1
                    at = hit[0] + f.normal * 2e-6
                if hits % 2:
                    wrong += 1
        cut.free()
        return wrong, counted

    def done(self):
        """Returns (faces as lists of (point in Blender metres, uv, uv2, colour), faces wound wrongly, faces)."""
        bm = bmesh.new()
        uv = bm.loops.layers.uv.new("uv")
        uv2 = bm.loops.layers.uv.new("uv2")
        colour = bm.loops.layers.float_color.new("colour")
        made = [bm.verts.new(to_b(p * LENGTH)) for p in self.verts]
        for face in self.faces:
            # (a face that closes to a point at the end of a skin has corners in one place: the weld below
            # makes a triangle of it or drops it)
            try:
                f = bm.faces.new([made[i] for i in face])
            except ValueError:
                continue
            for loop, i in zip(f.loops, face):
                d = self.data[i]
                loop[uv].uv = d[0]
                loop[uv2].uv = d[1]
                loop[colour] = (d[2][0], d[2][1], d[2][2], 1.0)
        bmesh.ops.remove_doubles(bm, verts=bm.verts, dist=2e-6)
        # (where a skin closes to a line on the middle plane, or a fin on that plane thins to nothing at its
        # leading tip, a four-cornered face has three corners in that plane: cut it from its fourth corner, or whoever cuts it in two later may leave a triangle lying
        # flat in the plane, back to back with its twin from the other side)
        for f in list(bm.faces):
            if len(f.verts) == 4:
                off = [loop for loop in f.loops if abs(loop.vert.co.x) > 1e-8]
                if len(off) == 1:
                    bmesh.ops.connect_verts(bm, verts=[off[0].vert, off[0].link_loop_next.link_loop_next.vert])
        bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
        bm.normal_update()
        # The check, which does not trust the line above (it has turned a whole fin inside out before now).
        wrong, counted = self.inside_out(bm)
        if wrong * 2 > counted:
            bmesh.ops.reverse_faces(bm, faces=bm.faces)
            bm.normal_update()
            wrong, counted = self.inside_out(bm)
        out = []
        for f in bm.faces:
            out.append([(loop.vert.co.copy(), tuple(loop[uv].uv), tuple(loop[uv2].uv), tuple(loop[colour]))
                        for loop in f.loops])
        bm.free()
        return out, wrong, counted


def flip_body(d):
    return d[0], (-d[1][0], d[1][1]), d[2]


def flip_fin(d):
    return d[0], (-d[1][0], d[1][1]), d[2]


def skin(part, section, places, half, kind):
    """Lofts a Section into a Part. `kind` is BODY or JAW."""
    rings = []
    for s in places:
        side, whole = section.outline(s, half)
        top, bot = section.top(s), section.bot(s)
        ring = []
        ends = s <= section.first or s >= section.last
        # (down the right side and back up the left; the belly line is there twice, once for each side, so that
        # how far round the skin a point is does not run from one side's number to the other's across one face)
        for j in list(range(half + 1)) + list(range(half, 0, -1)):
            x, y, arc = side[j]
            sign = 1.0 if len(ring) <= half else -1.0
            h = (y - bot) / max(top - bot, 1e-9)
            if kind == BODY:
                raised, moving = gill_plate(s, h)
                x += raised * (0.0 if ends else 1.0)
                # the roof of the mouth: the flat underside of the upper head, ahead of the jaw's hinge
                yc = bot + section.at(s)[3] * (top - bot)
                # (and behind the hook of the snout, whose underside is skin)
                roof = (smooth(0.4, 0.12, (y - bot) / max(yc - bot, 1e-9)) * smooth(HINGE_S + 0.015, HINGE_S - 0.012, s)
                        * smooth(0.02 * HOOK, 0.036 * HOOK + 1e-4, s))
                ring.append(part.add((sign * x, y, s - 0.5), (s, 1.0 - h),
                                     (sign * arc * LENGTH, 1.0 - whole * LENGTH), (0.0, moving, roof)))
            else:
                yc = bot + section.at(s)[3] * (top - bot)
                inside = smooth(0.55, 0.92, (y - yc) / max(top - yc, 1e-9)) if y > yc else 0.0
                inside *= smooth(HINGE_S + 0.025, HINGE_S - 0.002, s)
                ring.append(part.add((sign * x, y, s - 0.5), (s, 1.0 - h),
                                     (sign * x * LENGTH, 1.0), (JAW / 10.0, 0.0, inside)))
        rings.append(ring)
    part.loft(rings)


def body_places(low):
    head = 20 if low else 80
    rest = 26 if low else 92
    behind = GILL_S + 0.014
    places = [behind * (i / head) ** 1.35 for i in range(head)]
    places += [lerp(behind, BODY_SKIN.last, i / rest) for i in range(rest + 1)]
    return places


def maxilla(low):
    """The plate along the upper lip of the right side, from near the snout back past the eye."""
    part = Part("maxilla")
    stations = 8 if low else 26
    around = 6 if low else 12
    rings = []
    for i in range(stations + 1):
        u = i / stations
        s = lerp(P["along"](P["maxilla_from"]), P["along"](P["maxilla_to"]), u)
        # (along the lip, and on down the line of the mouth behind the jaw's hinge)
        y = BODY_SKIN.bot(min(s, HINGE_S - 0.006)) + 0.0045 - max(s - HINGE_S + 0.006, 0.0) * 0.3
        at, out, up = body_frame(s, y)
        ends = math.sin(math.pi * u) ** 0.5 if 0.0 < u < 1.0 else 0.0
        high = lerp(0.0035, 0.0095, smooth(0.0, 0.8, u)) * ends
        thick = 0.0042 * ends
        top, bot = BODY_SKIN.top(s), BODY_SKIN.bot(s)
        ring = []
        for k in range(around):
            q = TAU * k / around
            p = at - out * 0.0012 + up * (high * math.cos(q)) + out * (thick * math.sin(q))
            h = max(0.0, min(1.0, (p.y - bot) / (top - bot)))
            ring.append(part.add(p, (s, 1.0 - 0.5 * (1.0 + math.cos(q))), (0.0, 1.0), (MAXILLA / 10.0, 0.0, 0.0)))
        rings.append(ring)
    part.loft(rings)
    return part


def eye(low):
    """The right eye: a dome set in the side of the head (a rather small eye in the grown fish, a very big one
    in the young)."""
    part = Part("eye")
    at, out, up = body_frame(*EYE_AT)
    along = up.cross(out).normalized()
    ball, stands, shown = P["eye"]
    # (the dome goes on under the skin: what shows is `shown` of how far across it is made. Whatever that is,
    # the eye's drawn face is fitted to the part that shows: its dark rim falls where the eye meets the skin)
    seen = math.sqrt(1.0 - (1.0 - stands / ball) ** 2)
    reach = math.asin(min(seen / shown, 0.999))
    centre = at - out * (ball - stands)
    rows = 4 if low else 10
    around = 10 if low else 32
    rings = []
    for i in range(rows + 1):
        a = reach * i / rows
        ring = []
        for k in range(around):
            q = TAU * k / around
            p = centre + out * (ball * math.cos(a)) + (up * math.cos(q) + along * math.sin(q)) * (ball * math.sin(a))
            # (UV: where it is on the eye's round face, seen straight on: its middle at (0.5, 0.5), up towards +x)
            across = 0.5 * 0.644 * math.sin(a) / seen
            ring.append(part.add(p, (0.5 + across * math.cos(q), 1.0 - (0.5 + across * math.sin(q))), (0.0, 1.0),
                                 (EYE / 10.0, 0.0, 0.0)))
        rings.append(ring)
    # (closed behind, inside the head)
    back = centre + out * (ball * math.cos(reach) - 0.003)
    rings.append([part.add(back, (0.5 + 0.5 * math.cos(TAU * k / around), 0.5 - 0.5 * math.sin(TAU * k / around)),
                           (0.0, 1.0), (EYE / 10.0, 0.0, 0.0)) for k in range(around)])
    part.loft(rings)
    return part


def fin(name, kind, rays, base, direction, length, normal, thick, low, fleshy=False, ridge_from=0.0):
    """A fin: `rays` rays fanned from the line `base(t)` (t 0 its leading edge to 1 its trailing edge), each
    going the way `direction(t)` for `length(t)`; flat, facing `normal`; `thick` at its root."""
    part = Part(name)
    per_ray = 1 if low else 4
    rows = 3 if low else 12
    cols = max(rays * per_ray, 6)
    normal = normal.normalized()
    left, right = [], []
    for i in range(cols + 1):
        t = i / cols
        b, d, long = base(t), direction(t).normalized(), length(t)
        ridge = 0.5 + 0.5 * math.cos(TAU * (t * rays - 0.5)) if (rays > 1 and not low) else 0.0
        edge = min(1.0, t / 0.06) ** 0.5 * min(1.0, (1.0 - t) / 0.1) ** 0.5
        a, c = [], []
        for j in range(rows + 1):
            r = j / rows
            # (finer rows towards the edge, where it bends most)
            taper = 1.0 - r
            if fleshy:
                th = thick * edge * (taper ** 0.45)
            else:
                th = edge * (taper ** 0.5) * (thick * (0.1 + 0.9 * taper ** 1.6) + 0.0011 * ridge * smooth(ridge_from, ridge_from + 0.14, r))
            mid = b + d * (long * r)
            data = ((r, 1.0 - t * rays), (normal.x, 1.0 - normal.y), (kind / 10.0, 0.0, normal.z * 0.5 + 0.5))
            a.append(part.add(mid + normal * (th * 0.5), *data))
            c.append(part.add(mid - normal * (th * 0.5), *data))
        left.append(a)
        right.append(c)
    for i in range(cols):
        for j in range(rows):
            for sheet in (left, right):
                a, b, c, d = sheet[i][j], sheet[i + 1][j], sheet[i + 1][j + 1], sheet[i][j + 1]
                # (at the two corners of its edge three of a face's corners have no thickness: cut it from
                # the fourth, so that no triangle lies flat between the fin's two sides)
                if j == rows - 1 and i == 0:
                    part.faces += [(a, b, d), (b, c, d)]
                elif j == rows - 1 and i == cols - 1:
                    part.faces += [(a, b, c), (a, c, d)]
                else:
                    part.faces.append((a, b, c, d))
        # (closed at the root, inside the body)
        part.faces.append((left[i][0], right[i][0], right[i + 1][0], left[i + 1][0]))
    return part


def turn(d0, d1, t):
    """From one direction round to another."""
    d0, d1 = d0.normalized(), d1.normalized()
    angle = d0.angle(d1)
    return (d0 * math.sin((1.0 - t) * angle) + d1 * math.sin(t * angle)) / math.sin(angle)


def clearance(part, normal, reach):
    """The least gap (mm) between a paired fin and the body's side as the shader sculls it: every point of the
    fin from a third of the way out, pushed as far as it goes either way (`reach(r)`, body lengths: the shader's
    numbers), against the body's skin at its height (points under the belly have no body beside them)."""
    normal = normal.normalized()
    least = 1e9
    for p, d in zip(part.verts, part.data):
        r = d[0][0]
        if r < 0.35:
            continue
        for way in (-1.0, 1.0):
            q = p + normal * (way * reach(r))
            s = q.z + 0.5
            if BODY_SKIN.bot(s) < q.y < BODY_SKIN.top(s):
                least = min(least, (q.x - body_x(s, q.y)) * LENGTH * 1000.0)
    return least if least < 1e8 else float("inf")


def fins(low):
    made = []
    along = P["along"]
    big = P["fin"]
    deep = P["depth"]
    # The dorsal fin: thirteen rays (the species has 11 to 16), on the hump's rear slope in the male, its leading
    # edge the tallest, raked back.
    ds, db, dh, dl, da0, da1 = P["dorsal"]
    ds, de = along(ds), along(ds + db)
    made.append(fin(
        "dorsal", DORSAL, 13,
        lambda t: Vector((0.0, BODY_SKIN.top(lerp(ds, de, t)) - 0.007 * deep, lerp(ds, de, t) - 0.5)),
        lambda t: Vector((0.0, math.sin(math.radians(lerp(da0, da1, t))), math.cos(math.radians(lerp(da0, da1, t))))),
        lambda t: big * (dh - dl * t ** 1.05) * (0.9 + 0.1 * smooth(0.0, 0.14, t)) * (1.0 - 0.14 * smooth(0.82, 1.0, t)),
        Vector((1.0, 0.0, 0.0)), 0.0085 * big, low))
    # The adipose fin: a small fleshy flap with no rays, over the rear of the anal fin.
    ad_s, ad_h = P["adipose"]
    ad_s = along(ad_s)
    made.append(fin(
        "adipose", ADIPOSE, 1,
        lambda t: Vector((0.0, BODY_SKIN.top(ad_s + 0.026 * t) - 0.004 * deep, ad_s + 0.026 * t - 0.5)),
        lambda t: Vector((0.0, math.sin(math.radians(lerp(54.0, 14.0, t))), math.cos(math.radians(lerp(54.0, 14.0, t))))),
        lambda t: big * ad_h * (0.72 + 0.28 * math.sin(math.pi * t ** 0.8)),
        Vector((1.0, 0.0, 0.0)), 0.0075 * big, low, True))
    # The tail: nineteen rays, forked (shallowly in the grown fish, deeply in the parr and smolt, hardly at all
    # in the fry), its lobes pointed.
    t_mid, t_long, t_power, t_spread = P["tail"]

    def tail_long(t):
        a = abs(2.0 * t - 1.0)
        long = lerp(t_mid, t_long, a ** t_power)
        if a > 0.9:
            long *= 1.0 - 0.14 * ((a - 0.9) / 0.1) ** 2
        return long
    made.append(fin(
        "tail", TAIL, 19,
        lambda t: Vector((0.0, lerp(0.045, -0.046, t) * deep, 0.864 - 0.024 * (2.0 * t - 1.0) ** 2 - 0.5)),
        lambda t: Vector((0.0, math.sin(math.radians(t_spread * (1.0 - 2.0 * t))), math.cos(math.radians(t_spread * (1.0 - 2.0 * t))))),
        tail_long, Vector((1.0, 0.0, 0.0)), 0.02 * min(big, 1.0), low, False, 0.3))
    # The anal fin: fifteen rays (the species has 13 to 18: a Pacific salmon's long-based anal fin).
    as_, ab, ah, al, aa0, aa1 = P["anal"]
    as_, ae = along(as_), along(as_ + ab)
    made.append(fin(
        "anal", ANAL, 15,
        lambda t: Vector((0.0, BODY_SKIN.bot(lerp(as_, ae, t)) + 0.007 * deep, lerp(as_, ae, t) - 0.5)),
        lambda t: Vector((0.0, -math.sin(math.radians(lerp(aa0, aa1, t))), math.cos(math.radians(lerp(aa0, aa1, t))))),
        lambda t: big * (ah - al * t ** 0.9) * (0.9 + 0.1 * smooth(0.0, 0.14, t)) * (1.0 - 0.14 * smooth(0.82, 1.0, t)),
        Vector((1.0, 0.0, 0.0)), 0.008 * big, low))

    # The paired fins, the right one of each (the left is its mirror picture).
    def on_body(s, up, sunk=0.004):
        y = BODY_SKIN.bot(s) + up * deep
        return Vector((body_x(s, y) - sunk * P["width"], y, s - 0.5))
    pv = along(P["pelvic"])
    p0, p1 = on_body(pv, 0.016), on_body(pv + 0.026, 0.009)
    d0, d1 = Vector((0.45, -0.75, 0.5)), Vector((0.25, -0.35, 0.9))
    pelvic = fin(
        "pelvic", PELVIC, 10, lambda t: p0.lerp(p1, t), lambda t: turn(d0, d1, t),
        lambda t: big * (0.084 - 0.038 * t ** 1.2) * (0.88 + 0.12 * smooth(0.0, 0.16, t)) * (1.0 - 0.12 * smooth(0.8, 1.0, t)),
        d0.cross(d1), 0.007 * big, low)
    made += [pelvic, pelvic.mirrored("pelvic_left", flip_fin)]
    print("CLEARANCE pelvic fin to body, sculling: %.1f mm" % clearance(pelvic, d0.cross(d1), lambda r: 0.012 * r * r))
    q0, q1 = on_body(GILL_S + 0.004, 0.036), on_body(GILL_S + 0.021, 0.017)
    e0, e1 = Vector((0.4, -0.3, 0.87)), Vector((0.2, -0.8, 0.55))
    pectoral = fin(
        "pectoral", PECTORAL, 15, lambda t: q0.lerp(q1, t), lambda t: turn(e0, e1, t),
        lambda t: big * (0.125 - 0.066 * t ** 1.15) * (0.88 + 0.12 * smooth(0.0, 0.14, t)) * (1.0 - 0.12 * smooth(0.8, 1.0, t)),
        e0.cross(e1), 0.0075 * big, low)
    made += [pectoral, pectoral.mirrored("pectoral_left", flip_fin)]
    print("CLEARANCE pectoral fin to body, sculling: %.1f mm" % clearance(pectoral, e0.cross(e1), lambda r: 0.03 * (0.65 * r + 0.7 * r * r)))
    return made


def make(name, low):
    parts = []
    body = Part("body")
    skin(body, BODY_SKIN, body_places(low), 9 if low else 30, BODY)
    parts.append(body)
    jaw = Part("jaw")
    jaw_rings = 14 if low else 44
    skin(jaw, JAW_SKIN, [lerp(JAW_SKIN.first, JAW_SKIN.last, (i / jaw_rings) ** 1.25) for i in range(jaw_rings + 1)],
         5 if low else 14, JAW)
    parts.append(jaw)
    plate = maxilla(low)
    parts += [plate, plate.mirrored("maxilla_left", flip_body)]
    ball = eye(low)
    parts += [ball, ball.mirrored("eye_left", lambda d: d)]
    parts += fins(low)

    verts, faces, corners = [], [], []
    told = []
    wrong_all = 0
    for part in parts:
        out, wrong, counted = part.done()
        told.append("%s %d/%d wrong" % (part.name, wrong, counted))
        wrong_all += wrong
        for face in out:
            first = len(verts)
            for co, uv, uv2, colour in face:
                verts.append(co)
                corners.append((uv, uv2, colour))
            faces.append(list(range(first, first + len(face))))
    mesh = bpy.data.meshes.new(name)
    mesh.from_pydata(verts, [], faces)
    # (every layer made first, then each looked up by name: making one moves the others)
    mesh.uv_layers.new(name="UVMap")
    mesh.uv_layers.new(name="UV2")
    mesh.color_attributes.new(name="Color", type="FLOAT_COLOR", domain="CORNER")
    uv = mesh.uv_layers["UVMap"].data
    uv2 = mesh.uv_layers["UV2"].data
    colour = mesh.color_attributes["Color"].data
    for poly in mesh.polygons:
        for corner, vi in enumerate(poly.vertices):
            d = corners[vi]
            uv[poly.loop_start + corner].uv = d[0]
            uv2[poly.loop_start + corner].uv = d[1]
            colour[poly.loop_start + corner].color = d[2]
    mesh.color_attributes.active_color = mesh.color_attributes["Color"]
    mesh.color_attributes.render_color_index = mesh.color_attributes.find("Color")
    material = bpy.data.materials.get("salmon") or bpy.data.materials.new("salmon")
    material.use_nodes = True
    bsdf = next(n for n in material.node_tree.nodes if n.type == "BSDF_PRINCIPLED")
    bsdf.inputs["Base Color"].default_value = (0.62, 0.62, 0.52, 1.0)
    material.diffuse_color = (0.62, 0.62, 0.52, 1.0)
    mesh.materials.append(material)
    for poly in mesh.polygons:
        poly.use_smooth = True
    mesh.update()
    # (every face was made with corners of its own; the same point with the same data is one point again)
    obj = bpy.data.objects.new(name, mesh)
    bpy.context.collection.objects.link(obj)
    bpy.context.view_layer.objects.active = obj
    bpy.ops.object.select_all(action="DESELECT")
    obj.select_set(True)
    bpy.ops.object.mode_set(mode="EDIT")
    bpy.ops.mesh.select_all(action="SELECT")
    bpy.ops.mesh.remove_doubles(threshold=1e-7)
    bpy.ops.object.mode_set(mode="OBJECT")
    tris = sum(len(p.vertices) - 2 for p in mesh.polygons)
    print("BUILT %s verts=%d tris=%d" % (name, len(mesh.vertices), tris))
    print("WINDING %s: %s: %s" % (name, "ok" if wrong_all == 0 else "INSIDE OUT", ", ".join(told)))
    return obj


def export_one(obj, path):
    bpy.ops.object.select_all(action="DESELECT")
    obj.select_set(True)
    bpy.ops.export_scene.gltf(
        filepath=path, export_format="GLB", export_yup=True, use_selection=True,
        export_animations=False, export_vertex_color="ACTIVE", export_texcoords=True,
    )


def render(folder, made):
    scene = bpy.context.scene
    scene.render.engine = "BLENDER_WORKBENCH"
    scene.display.shading.light = "STUDIO"
    scene.display.shading.color_type = "MATERIAL"
    scene.display.shading.show_cavity = True
    scene.render.resolution_x, scene.render.resolution_y = 1400, 800
    scene.world = bpy.data.worlds.new("World")
    scene.world.color = (0.02, 0.05, 0.3)
    camera = bpy.data.objects.new("Camera", bpy.data.cameras.new("Camera"))
    camera.data.type = "ORTHO"
    camera.data.clip_end = 100.0
    scene.collection.objects.link(camera)
    scene.camera = camera
    # (Blender space: the nose is towards +Y, up is +Z)
    views = [("right", (1, 0, 0), (0, 0, 0), 0.46), ("left", (-1, 0, 0), (0, 0, 0), 0.46),
             ("top", (0, -0.001, 1), (0, 0, 0), 0.46), ("under", (0, 0.001, -1), (0, 0, 0), 0.46),
             ("front", (0, 1, 0), (0, 0, 0), 0.24), ("back", (0, -1, 0), (0, 0, 0), 0.24),
             ("quarter", (0.7, 0.6, 0.35), (0, 0, 0), 0.44), ("low_quarter", (0.6, 0.6, -0.5), (0, 0, 0), 0.44),
             ("head", (1, 0.15, 0.05), (0, 0.15, 0), 0.16), ("head_under", (0.5, 0.5, -0.7), (0, 0.15, -0.01), 0.16),
             ("tail", (1, -0.2, 0.1), (0, -0.15, 0), 0.2)]
    for low, obj in ((False, made[0]), (True, made[1])):
        for other in made:
            other.hide_render = other is not obj
        for view, direction, target, frame in views:
            if low and view not in ("right", "quarter"):
                continue
            # (the views are laid out for a fish 0.4 m long)
            size = LENGTH / 0.4
            offset = Vector(direction).normalized() * 10.0
            camera.data.ortho_scale = frame * size
            camera.location = Vector(target) * size + offset
            camera.rotation_euler = (-offset).to_track_quat("-Z", "X" if view in ("top", "under") else "Y").to_euler()
            scene.render.filepath = os.path.join(folder, "%s%s.png" % ("lo_" if low else "", view))
            bpy.ops.render.render(write_still=True)


def main():
    os.makedirs(OUT, exist_ok=True)
    for stage in WANTED:
        bpy.ops.wm.read_factory_settings(use_empty=True)
        bpy.context.preferences.filepaths.save_version = 0
        use(stage)
        name = "sockeye_" + stage
        full = make(name, False)
        low = make(name + "_lo", True)
        export_one(full, os.path.join(OUT, name + ".glb"))
        export_one(low, os.path.join(OUT, name + "_lo.glb"))
        low.location.x = 0.5
        bpy.ops.wm.save_as_mainfile(filepath=os.path.join(HERE, name + ".blend"))
        low.location.x = 0.0
        if PREVIEW:
            folder = os.path.join(PREVIEW, stage)
            os.makedirs(folder, exist_ok=True)
            render(folder, [full, low])


if __name__ == "__main__":
    main()
