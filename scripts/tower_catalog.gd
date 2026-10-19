class_name TowerCatalog
extends RefCounted
## Single source for construction, combat defaults, research and HUD information.
## Integer keys match Tower.Kind; kept independent to avoid scene/class cycles.

const DATA: Array[Dictionary] = [
	{"title": "Sentinel", "unlock": "", "training": "basic_training", "special": "piercing", "mastery": "basic_mastery", "special_title": "Piercing Rounds", "cost": 60, "damage": 15, "armor_ratio": 1.6, "shield_ratio": 0.55, "range": 112.0, "interval": 0.8, "damage_step": 12, "range_step": 24.0, "special_damage": 8, "prices": [60, 100, 160, 240, 360, 520], "color": Color("efbf70")},
	{"title": "Tesla", "unlock": "tesla", "training": "tesla_training", "special": "static_field", "mastery": "tesla_mastery", "special_title": "Static Field", "cost": 110, "damage": 12, "armor_ratio": 0.5, "shield_ratio": 2.0, "range": 80.0, "interval": 1.1, "damage_step": 9, "range_step": 12.0, "special_damage": 4, "prices": [80, 130, 200, 300, 450, 650], "color": Color("bb9bff")},
	{"title": "Mortar", "unlock": "mortar", "training": "mortar_training", "special": "mortar_area", "mastery": "mortar_mastery", "special_title": "Blast Radius", "cost": 160, "damage": 55, "armor_ratio": 1.4, "shield_ratio": 0.6, "range": 280.0, "interval": 2.4, "damage_step": 22, "range_step": 32.0, "special_damage": 10, "prices": [100, 160, 240, 350, 500, 720], "color": Color("ff995f")},
	{"title": "Ice", "unlock": "ice", "training": "ice_training", "special": "ice_freeze", "mastery": "ice_mastery", "special_title": "Deep Freeze", "cost": 100, "damage": 8, "armor_ratio": 0.5, "shield_ratio": 1.25, "range": 136.0, "interval": 1.0, "damage_step": 6, "range_step": 20.0, "special_damage": 2, "prices": [70, 110, 170, 250, 370, 540], "color": Color("87e5f9")},
	{"title": "Cannon", "unlock": "cannon", "training": "cannon_training", "special": "cannon_distance", "mastery": "cannon_mastery", "special_title": "Long Barrel", "cost": 150, "damage": 42, "armor_ratio": 1.6, "shield_ratio": 0.5, "range": 176.0, "interval": 1.6, "damage_step": 16, "range_step": 24.0, "special_damage": 6, "prices": [90, 145, 220, 320, 470, 680], "color": Color("b9d0a0")},
]


static func valid(kind: int) -> bool:
	return kind >= 0 and kind < DATA.size()


static func unlocked(profile: Progression, kind: int) -> bool:
	return valid(kind) and (str(DATA[kind].unlock).is_empty() or profile.has_skill(DATA[kind].unlock))
