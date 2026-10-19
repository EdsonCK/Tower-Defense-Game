class_name GameConfig
extends RefCounted
## Shared endless-mode defaults. This class holds no mutable game state.

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
const MAX_WAVE_ENEMIES := 64
const MIN_SPAWN_INTERVAL := 0.45
const MAX_ENEMY_HEALTH := 1000000
const TOWER_REFUND := int(TOWER_COST * 0.5) # 50% of original construction; upgrades are not refunded.
const MAX_UPGRADE_LEVEL := 5
const UPGRADE_COSTS: Array[int] = [60, 100, 160, 240, 360]
const DAMAGE_PER_LEVEL := 12
const RANGE_PER_LEVEL := 24.0
const SPEED_FACTOR_PER_LEVEL := 0.82
const REGEN_DELAY := 2.0

const TESLA_COST := 110
const TESLA_RANGE := 80.0
const TESLA_DAMAGE := 12
const TESLA_COOLDOWN := 1.1
const TESLA_UPGRADE_COSTS: Array[int] = [80, 130, 200, 300, 450]
const SKILL_MENU_INTERVAL := 5

# Veteran pressure follows early-game investment without imposing a final wave.
const VETERAN_START_WAVE := 30
const VETERAN_HEALTH_PER_WAVE := 0.04
const VETERAN_ARMOR_INTERVAL := 4.0
