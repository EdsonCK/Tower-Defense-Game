class_name GameConfig
extends RefCounted
## Shared v0.1 defaults. This class holds no mutable game state.

const GRID_SIZE := Vector2i(40, 24)
const CELL_SIZE := 32
const BOARD_SIZE := Vector2(1280, 768)
const SPAWN := Vector2i(0, 12)
const EXIT := Vector2i(39, 12)
const STARTING_CURRENCY := 200
const STARTING_LIVES := 10
const TOWER_COST := 60
const TOWER_RANGE := 112.0
const TOWER_DAMAGE := 15
const TOWER_COOLDOWN := 0.8
const SHOT_FLASH_DURATION := 0.1
const ENEMY_SPEED := 60.0
const KILL_BOUNTY := 12
const SPAWN_INTERVAL := 1.2
const WAVE_CLEAR_BONUS := 30
const BASE_DAMAGE := 1
const WAVE_COUNTS: Array[int] = [8, 12, 16]
const WAVE_HEALTH: Array[int] = [45, 60, 75]
