class_name Biomes
extends RefCounted
## Biome definitions. The map's biome changes every GameConfig.BIOME_WAVES waves and
## cycles after the last one. Every biome shares one art style (soft-shaded shapes lit
## from the top left, with soft shadows) and the same path palette; the ground texture,
## lakes, decorations and ambient particles change. Each biome buffs every tower a little
## and one favored tower type more. Fields:
##   name                     display name
##   ground, ground_alt       the two ground tones the terrain shader blends between
##   grid                     build-mode grid line color (with alpha)
##   style                    terrain shader detail style (see shaders/terrain.gdshader)
##   detail, detail2          style-specific detail colors (grass tips, ripples, cracks...)
##   feature                  what the map's lakes are in this biome ("pond", "lava pool"...)
##   water_style              0 water, 1 ice, 2 lava, 3 bog
##   water_deep, water_shallow, shore   lake colors
##   fog                      color of the unexplored land beyond the map's edge
##   clouds                   strength of the drifting cloud shadows (0-1)
##   particles                ambient particle kind (see Atmosphere)
##   decorations              Array of [kind, weight] on open ground (see DecorLayer)
##   shore_decorations        Array of [kind, weight] for land tiles beside a lake
##   deco_colors              named colors used by that biome's decorations
##   deco_density             chance that a free ground tile gets a decoration
##   buff                     effect -> fraction for every tower ("range", "attack_speed", "damage")
##   favored                  tower type id that gets `favored_buff` on top
##   favored_buff             effect -> fraction for the favored type

## Shared path palette (identical in every biome).
const PATH_COLOR: Color = Color(0.66, 0.54, 0.38)
const PATH_EDGE: Color = Color(0.36, 0.27, 0.18)
const PATH_PEBBLE: Color = Color(0.8, 0.71, 0.56)
const PATH_RUT: Color = Color(0.5, 0.39, 0.26)
const COBBLE: Color = Color(0.62, 0.6, 0.57)
const COBBLE_GAP: Color = Color(0.32, 0.3, 0.29)
const OUTLINE: Color = Color(0.06, 0.06, 0.08, 0.85)

const DEFS: Array[Dictionary] = [
	{
		"name": "Meadow",
		"ground": Color(0.29, 0.5, 0.23), "ground_alt": Color(0.4, 0.62, 0.29), "grid": Color(0.05, 0.15, 0.02, 0.22),
		"style": 0, "detail": Color(0.55, 0.78, 0.36), "detail2": Color(1.0, 0.93, 0.6),
		"feature": "pond", "water_style": 0, "water_deep": Color(0.1, 0.3, 0.52), "water_shallow": Color(0.26, 0.6, 0.72), "shore": Color(0.52, 0.5, 0.32),
		"fog": Color(0.05, 0.09, 0.06), "clouds": 1.0, "particles": "pollen",
		"decorations": [["tree", 3], ["bush", 3], ["flowers", 4], ["rock", 1], ["grass", 6]],
		"shore_decorations": [["reeds", 3], ["grass", 2], ["rock", 1]],
		"deco_colors": {"leaf": Color(0.18, 0.46, 0.2), "leaf_light": Color(0.42, 0.72, 0.3), "trunk": Color(0.45, 0.3, 0.18),
			"flower_a": Color(1.0, 0.85, 0.3), "flower_b": Color(0.95, 0.45, 0.6), "flower_c": Color(0.75, 0.6, 1.0),
			"rock": Color(0.56, 0.58, 0.6), "grass": Color(0.36, 0.62, 0.26), "reed": Color(0.45, 0.6, 0.28), "reed_top": Color(0.42, 0.28, 0.16)},
		"deco_density": 0.18,
		"buff": {"range": 0.10}, "favored": TowerTypes.BASIC, "favored_buff": {"range": 0.15},
	},
	{
		"name": "Desert",
		"ground": Color(0.8, 0.64, 0.38), "ground_alt": Color(0.92, 0.79, 0.52), "grid": Color(0.35, 0.2, 0.0, 0.2),
		"style": 1, "detail": Color(0.68, 0.52, 0.3), "detail2": Color(0.55, 0.42, 0.3),
		"feature": "oasis", "water_style": 0, "water_deep": Color(0.04, 0.42, 0.5), "water_shallow": Color(0.25, 0.74, 0.7), "shore": Color(0.46, 0.6, 0.28),
		"fog": Color(0.17, 0.12, 0.07), "clouds": 0.55, "particles": "dust",
		"decorations": [["cactus", 4], ["rock", 3], ["dry_bush", 3], ["bones", 1]],
		"shore_decorations": [["palm", 3], ["grass", 2]],
		"deco_colors": {"cactus": Color(0.3, 0.55, 0.3), "cactus_light": Color(0.48, 0.72, 0.4), "rock": Color(0.68, 0.5, 0.34),
			"dry": Color(0.6, 0.48, 0.28), "bones": Color(0.95, 0.93, 0.85), "flower_a": Color(1.0, 0.4, 0.55),
			"palm": Color(0.25, 0.55, 0.25), "palm_light": Color(0.42, 0.72, 0.32), "trunk": Color(0.55, 0.4, 0.25), "grass": Color(0.42, 0.62, 0.28)},
		"deco_density": 0.12,
		"buff": {"attack_speed": 0.05}, "favored": TowerTypes.CANNON, "favored_buff": {"attack_speed": 0.15},
	},
	{
		"name": "Tundra",
		"ground": Color(0.79, 0.85, 0.93), "ground_alt": Color(0.94, 0.97, 1.0), "grid": Color(0.2, 0.3, 0.5, 0.2),
		"style": 2, "detail": Color(0.62, 0.72, 0.88), "detail2": Color(1.0, 1.0, 1.0),
		"feature": "frozen lake", "water_style": 1, "water_deep": Color(0.42, 0.66, 0.84), "water_shallow": Color(0.7, 0.87, 0.97), "shore": Color(0.86, 0.91, 0.97),
		"fog": Color(0.11, 0.14, 0.2), "clouds": 0.8, "particles": "snow",
		"decorations": [["pine", 4], ["ice", 3], ["snow_rock", 3]],
		"shore_decorations": [["ice", 3], ["snow_rock", 1]],
		"deco_colors": {"pine": Color(0.16, 0.38, 0.34), "pine_light": Color(0.25, 0.5, 0.44), "snow": Color(0.97, 0.98, 1.0), "trunk": Color(0.4, 0.3, 0.22),
			"ice": Color(0.62, 0.86, 1.0), "rock": Color(0.52, 0.57, 0.66)},
		"deco_density": 0.14,
		"buff": {"damage": 0.05}, "favored": TowerTypes.TESLA, "favored_buff": {"damage": 0.20},
	},
	{
		"name": "Volcanic",
		"ground": Color(0.16, 0.14, 0.15), "ground_alt": Color(0.29, 0.24, 0.24), "grid": Color(1.0, 0.45, 0.15, 0.12),
		"style": 3, "detail": Color(0.06, 0.05, 0.06), "detail2": Color(1.0, 0.42, 0.1),
		"feature": "lava pool", "water_style": 2, "water_deep": Color(0.85, 0.2, 0.04), "water_shallow": Color(1.0, 0.78, 0.28), "shore": Color(0.1, 0.08, 0.08),
		"fog": Color(0.06, 0.02, 0.02), "clouds": 0.45, "particles": "embers",
		"decorations": [["lava", 2], ["stump", 3], ["obsidian", 3], ["rock", 2]],
		"shore_decorations": [["obsidian", 2], ["rock", 1]],
		"deco_colors": {"lava": Color(1.0, 0.42, 0.12), "lava_glow": Color(1.0, 0.75, 0.3), "stump": Color(0.16, 0.12, 0.1),
			"obsidian": Color(0.1, 0.08, 0.14), "obsidian_light": Color(0.45, 0.35, 0.6), "rock": Color(0.3, 0.26, 0.26)},
		"deco_density": 0.13,
		"buff": {"damage": 0.05}, "favored": TowerTypes.CANNON, "favored_buff": {"damage": 0.20},
	},
	{
		"name": "Swamp",
		"ground": Color(0.2, 0.28, 0.18), "ground_alt": Color(0.31, 0.39, 0.23), "grid": Color(0.0, 0.05, 0.0, 0.24),
		"style": 4, "detail": Color(0.42, 0.52, 0.24), "detail2": Color(0.13, 0.17, 0.12),
		"feature": "bog", "water_style": 3, "water_deep": Color(0.1, 0.17, 0.12), "water_shallow": Color(0.24, 0.33, 0.2), "shore": Color(0.27, 0.23, 0.15),
		"fog": Color(0.04, 0.07, 0.05), "clouds": 0.7, "particles": "fireflies",
		"decorations": [["reeds", 4], ["mushroom", 3], ["log", 2], ["grass", 3]],
		"shore_decorations": [["reeds", 4], ["mushroom", 1]],
		"deco_colors": {"reed": Color(0.5, 0.6, 0.28), "reed_top": Color(0.42, 0.3, 0.18), "lily": Color(0.4, 0.7, 0.35),
			"cap": Color(0.85, 0.3, 0.25), "stem": Color(0.92, 0.88, 0.78), "log": Color(0.35, 0.26, 0.17), "moss": Color(0.4, 0.55, 0.25),
			"grass": Color(0.34, 0.45, 0.22)},
		"deco_density": 0.15,
		"buff": {"range": 0.10}, "favored": TowerTypes.TESLA, "favored_buff": {"range": 0.20},
	},
	{
		"name": "Autumn Forest",
		"ground": Color(0.4, 0.36, 0.21), "ground_alt": Color(0.53, 0.47, 0.27), "grid": Color(0.1, 0.05, 0.0, 0.2),
		"style": 5, "detail": Color(0.86, 0.4, 0.12), "detail2": Color(0.96, 0.7, 0.22),
		"feature": "pond", "water_style": 0, "water_deep": Color(0.13, 0.26, 0.36), "water_shallow": Color(0.3, 0.45, 0.5), "shore": Color(0.42, 0.35, 0.23),
		"fog": Color(0.09, 0.06, 0.03), "clouds": 1.0, "particles": "leaves",
		"decorations": [["autumn_tree", 4], ["leaves", 3], ["pumpkin", 1], ["rock", 1], ["mushroom", 1]],
		"shore_decorations": [["reeds", 3], ["leaves", 1]],
		"deco_colors": {"leaf": Color(0.85, 0.4, 0.13), "leaf_light": Color(0.98, 0.68, 0.22), "leaf_red": Color(0.75, 0.2, 0.12), "trunk": Color(0.38, 0.25, 0.15),
			"leaves": Color(0.8, 0.32, 0.15), "pumpkin": Color(0.95, 0.5, 0.12), "rock": Color(0.5, 0.48, 0.45),
			"cap": Color(0.7, 0.45, 0.25), "stem": Color(0.92, 0.88, 0.78), "reed": Color(0.6, 0.55, 0.3), "reed_top": Color(0.42, 0.28, 0.16)},
		"deco_density": 0.16,
		"buff": {"attack_speed": 0.05}, "favored": TowerTypes.BASIC, "favored_buff": {"attack_speed": 0.15},
	},
]


static func count() -> int:
	return DEFS.size()


## Biome index for `wave` (1-based): waves 1-10 are biome 0, 11-20 biome 1, ... cycling.
static func index_for_wave(wave: int) -> int:
	return floori(float(maxi(wave, 1) - 1) / GameConfig.BIOME_WAVES) % DEFS.size()


static func get_def(index: int) -> Dictionary:
	return DEFS[index % DEFS.size()]


## Total bonus of `effect` for a tower of `type_id` in biome `index`.
static func bonus(index: int, type_id: String, effect: String) -> float:
	if index < 0:
		return 0.0  # no biome (used by tests that need unbuffed numbers)
	var def: Dictionary = get_def(index)
	var value: float = float(def["buff"].get(effect, 0.0))
	if def["favored"] == type_id:
		value += float(def["favored_buff"].get(effect, 0.0))
	return value


## "Meadow: +10% range for all towers, Basic +25% range".
static func describe(index: int) -> String:
	var def: Dictionary = get_def(index)
	var parts: PackedStringArray = PackedStringArray()
	for effect: String in def["buff"]:
		parts.append("+%d%% %s" % [roundi(def["buff"][effect] * 100.0), _effect_name(effect)])
	var favored: PackedStringArray = PackedStringArray()
	for effect: String in def["favored_buff"]:
		var total: float = float(def["buff"].get(effect, 0.0)) + float(def["favored_buff"][effect])
		favored.append("+%d%% %s" % [roundi(total * 100.0), _effect_name(effect)])
	return "%s all, %s %s" % [", ".join(parts), TowerTypes.get_def(def["favored"])["short"], ", ".join(favored)]


static func _effect_name(effect: String) -> String:
	match effect:
		"attack_speed":
			return "hit speed"
		_:
			return effect
