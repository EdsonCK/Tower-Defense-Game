class_name GameConfig
extends RefCounted
## Shared v0.1 tuning constants. Holds no game state; edit values here to rebalance.

# --- Board ---
const GRID_COLUMNS: int = 40
const GRID_ROWS: int = 24
const CELL_SIZE: int = 32
const BOARD_WIDTH: int = GRID_COLUMNS * CELL_SIZE   # 1280
const BOARD_HEIGHT: int = GRID_ROWS * CELL_SIZE     # 768
const SPAWN_CELL: Vector2i = Vector2i(0, 12)
const EXIT_CELL: Vector2i = Vector2i(39, 12)

# --- Player ---
const STARTING_CURRENCY: int = 200
const STARTING_LIVES: int = 10

# --- Tower ---
const TOWER_COST: int = 60
const TOWER_RANGE: float = 112.0
const TOWER_DAMAGE: int = 15
const TOWER_COOLDOWN: float = 0.8
const TOWER_FLASH_DURATION: float = 0.1

# --- Enemy ---
const ENEMY_SPEED: float = 60.0
const ENEMY_BOUNTY: int = 12
const BASE_DAMAGE_PER_ENEMY: int = 1

# --- Waves ---
const SPAWN_INTERVAL: float = 1.2
const WAVE_CLEAR_BONUS: int = 30
const WAVES: Array = [
	{"count": 8, "health": 45},
	{"count": 12, "health": 60},
	{"count": 16, "health": 75},
]
