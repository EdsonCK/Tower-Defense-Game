class_name CombatArt
extends RefCounted
## Shared 2x artwork baked from MonsterArt/TowerArt; no per-enemy vector rebuild.
## Only visual phases are sampled. Simulation timing and hitboxes stay continuous.
const MONSTERS := preload("res://assets/generated/monsters.png")
const TOWERS := preload("res://assets/generated/towers.png")
const FRAMES := 64
const TILE := 96
const FREQUENCIES := [6.0, 12.0, 6.0, 4.0, 3.0]
const DESTINATION := Rect2(-24, -24, 48, 48)

static func monster(c: CanvasItem, kind: int, time: float, flash: float) -> void:
	var frame := roundi(fposmod(time * FREQUENCIES[kind], TAU) / TAU * FRAMES) % FRAMES
	var source := Rect2((frame % 16) * TILE, (kind * 4 + frame / 16) * TILE, TILE, TILE)
	c.draw_texture_rect_region(MONSTERS, DESTINATION, source)
	if flash > 0:
		c.draw_arc(Vector2.ZERO, 13, -2.5, 0.5, 16, Color(1, 0.94, 0.76, flash), 2, true)

static func tower(c: CanvasItem, kind: int, aim: float, recoil: float) -> void:
	c.draw_texture_rect_region(TOWERS, DESTINATION, Rect2(kind * TILE, 0, TILE, TILE))
	TowerArt.draw_weapon(c, kind, aim, recoil)
