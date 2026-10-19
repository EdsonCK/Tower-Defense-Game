class_name SkillCatalog
extends RefCounted
## Permanent one-time unlocks. Tesla is the sole root of the tree.

const IDS: Array[String] = [
	"tesla", "basic_training", "tesla_training", "salvage",
	"piercing", "static_field", "gold_mastery", "sluggish",
	"fragile", "engineering", "armor_breaker", "armor_breaker_ii",
	"engineering_ii", "engineering_iii", "optics", "optics_ii",
	"overcharge", "overcharge_ii", "rapid_fire", "rapid_fire_ii",
	"gold_mastery_ii", "gold_mastery_iii", "sluggish_ii", "fragile_ii",
	"exposed_armor", "shield_decay",
]
const NODES := {
	"tesla": {"branch": "Start here", "title": "Tesla Tower", "cost": 3, "requires": "", "effect": "Unlock the short-range tower that bolts ALL nearby enemies."},
	"basic_training": {"branch": "Basic ballistics", "title": "Basic Tower Training", "cost": 3, "requires": "tesla", "effect": "Unlock gold upgrades for basic towers: damage, range, or speed."},
	"tesla_training": {"branch": "Tesla research", "title": "Tesla Training", "cost": 4, "requires": "tesla", "effect": "Unlock gold upgrades for Tesla towers: damage, range, or speed."},
	"salvage": {"branch": "Economy", "title": "Salvage", "cost": 3, "requires": "tesla", "effect": "+20% gold from kills and wave-clear bonuses."},
	"piercing": {"branch": "Basic ballistics", "title": "Piercing Rounds", "cost": 4, "requires": "basic_training", "effect": "Basic towers gain a unique upgrade track: bonus health damage and concentrated armor damage."},
	"static_field": {"branch": "Tesla research", "title": "Static Field", "cost": 4, "requires": "tesla_training", "effect": "Tesla gains a unique track: bonus damage and a brief area slow."},
	"gold_mastery": {"branch": "Economy", "title": "Gold Mastery", "cost": 5, "requires": "salvage", "effect": "+20% more gold (40% total). Refunds are never boosted."},
	"sluggish": {"branch": "Disruption", "title": "Heavy Footsteps", "cost": 4, "requires": "tesla", "effect": "All newly spawned enemies move 10% slower."},
	"fragile": {"branch": "Disruption", "title": "Brittle Defenses", "cost": 5, "requires": "sluggish", "effect": "All new enemies have 15% less HP and shield."},
	"engineering": {"branch": "Basic ballistics", "title": "Tower Engineering", "cost": 4, "requires": "basic_training", "effect": "Permanently increase both tower types' damage by 10%, including placed towers."},
	"armor_breaker": {"title": "Armor Breaker", "cost": 7, "requires": "piercing", "branch": "Basic ballistics", "effect": "All towers deal +25% damage to armor pools."},
	"armor_breaker_ii": {"title": "Armor Breaker II", "cost": 14, "requires": "armor_breaker", "branch": "Basic ballistics", "effect": "Another +40% armor damage (65% total)."},
	"engineering_ii": {"title": "Tower Engineering II", "cost": 9, "requires": "engineering", "branch": "Basic ballistics", "effect": "Another +15% damage (25% total), to all three layers."},
	"engineering_iii": {"title": "Tower Engineering III", "cost": 18, "requires": "engineering_ii", "branch": "Basic ballistics", "effect": "Another +25% damage (50% total), to all three layers."},
	"optics": {"title": "Precision Optics", "cost": 6, "requires": "basic_training", "branch": "Basic ballistics", "effect": "All towers gain 8% range."},
	"optics_ii": {"title": "Precision Optics II", "cost": 12, "requires": "optics", "branch": "Basic ballistics", "effect": "Another 12% range (20% total)."},
	"overcharge": {"title": "Overcharge", "cost": 7, "requires": "static_field", "branch": "Tesla research", "effect": "All towers deal +25% damage to shield pools."},
	"overcharge_ii": {"title": "Overcharge II", "cost": 14, "requires": "overcharge", "branch": "Tesla research", "effect": "Another +40% shield damage (65% total)."},
	"rapid_fire": {"title": "Rapid Cycling", "cost": 8, "requires": "tesla_training", "branch": "Tesla research", "effect": "All towers fire with an 8% shorter interval."},
	"rapid_fire_ii": {"title": "Rapid Cycling II", "cost": 16, "requires": "rapid_fire", "branch": "Tesla research", "effect": "Reduce firing intervals by another 12% (19% total)."},
	"gold_mastery_ii": {"title": "Gold Mastery II", "cost": 10, "requires": "gold_mastery", "branch": "Economy", "effect": "Another +25% gold from kills and wave clears (65% total)."},
	"gold_mastery_iii": {"title": "Gold Mastery III", "cost": 20, "requires": "gold_mastery_ii", "branch": "Economy", "effect": "Another +35% gold (100% total). No refund boosts."},
	"sluggish_ii": {"title": "Heavy Footsteps II", "cost": 9, "requires": "sluggish", "branch": "Disruption", "effect": "New enemies move another 10% slower (19% total)."},
	"fragile_ii": {"title": "Brittle Defenses II", "cost": 12, "requires": "fragile", "branch": "Disruption", "effect": "Reduce new enemies' health and shield by another 15%."},
	"exposed_armor": {"title": "Exposed Plating", "cost": 8, "requires": "fragile", "branch": "Disruption", "effect": "New enemies spawn with 20% less armor."},
	"shield_decay": {"title": "Shield Decay", "cost": 10, "requires": "exposed_armor", "branch": "Disruption", "effect": "New enemies spawn with 25% less shield."},
}
