class_name SkillCatalog
extends RefCounted
## Permanent one-time unlocks. Tesla is the sole root of the tree.

const IDS: Array[String] = ["tesla", "basic_training", "tesla_training", "salvage", "piercing", "static_field", "gold_mastery", "sluggish", "fragile", "engineering"]
const NODES := {
	"tesla": {"title": "Tesla Tower", "cost": 3, "requires": "", "effect": "Unlock the short-range tower that bolts ALL nearby enemies."},
	"basic_training": {"title": "Basic Tower Training", "cost": 3, "requires": "tesla", "effect": "Unlock gold upgrades for basic towers: damage, range, or speed."},
	"tesla_training": {"title": "Tesla Training", "cost": 4, "requires": "tesla", "effect": "Unlock gold upgrades for Tesla towers: damage, range, or speed."},
	"salvage": {"title": "Salvage", "cost": 3, "requires": "tesla", "effect": "+20% gold from kills and wave-clear bonuses."},
	"piercing": {"title": "Piercing Rounds", "cost": 4, "requires": "basic_training", "effect": "Basic towers gain a unique upgrade track: bonus damage and armor penetration."},
	"static_field": {"title": "Static Field", "cost": 4, "requires": "tesla_training", "effect": "Tesla gains a unique track: bonus damage and a brief area slow."},
	"gold_mastery": {"title": "Gold Mastery", "cost": 5, "requires": "salvage", "effect": "+20% more gold (40% total). Refunds are never boosted."},
	"sluggish": {"title": "Heavy Footsteps", "cost": 4, "requires": "tesla", "effect": "All newly spawned enemies move 10% slower."},
	"fragile": {"title": "Brittle Defenses", "cost": 5, "requires": "sluggish", "effect": "All new enemies have 15% less HP and shield."},
	"engineering": {"title": "Tower Engineering", "cost": 4, "requires": "basic_training", "effect": "Permanently increase both tower types' damage by 10%, including placed towers."},
}
