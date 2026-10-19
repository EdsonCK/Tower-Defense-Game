class_name EnemyProfile
extends RefCounted
## A per-spawn value object; generation never mutates a shared template.

enum Kind { GRUNT, RUNNER, ARMORED, REGENERATOR, SHIELDED }

var kind := Kind.GRUNT
var title := "Grunt"
var hit_points := 45
var speed := 60.0
var bounty := 12
var color := Color("f06464")
var armor := 0
var regeneration := 0.0
var shield := 0


static func base(type: Kind) -> EnemyProfile:
	var result := EnemyProfile.new()
	result.kind = type
	match type:
		Kind.RUNNER:
			result.title = "Runner"
			result.hit_points = 30
			result.speed = 90.0
			result.bounty = 9
			result.color = Color("ffba58")
		Kind.ARMORED:
			result.title = "Armored"
			result.hit_points = 105
			result.speed = 40.0
			result.bounty = 24
			result.color = Color("a8bccb")
			result.armor = 3
		Kind.REGENERATOR:
			result.title = "Regenerator"
			result.hit_points = 68
			result.speed = 52.0
			result.bounty = 20
			result.color = Color("c889ef")
			result.regeneration = 3.0
		Kind.SHIELDED:
			result.title = "Shielded"
			result.hit_points = 80
			result.speed = 66.0
			result.bounty = 22
			result.color = Color("f2df78")
			result.shield = 30
	return result
