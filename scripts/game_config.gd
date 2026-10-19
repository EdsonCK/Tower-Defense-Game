class_name GameConfig
extends RefCounted
## Shared tuning constants. Holds no game state; edit values here to rebalance.
## Enemy type stats live in enemy_types.gd; wave scaling formulas in wave_generator.gd.

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
## Fraction of everything spent on a tower (build + upgrades) returned when it is sold.
const SELL_REFUND_RATIO: float = 0.5

# --- Tower upgrades (each tower commits to one path, up to UPGRADE_MAX_LEVEL levels) ---
const UPGRADE_MAX_LEVEL: int = 3                 # +1 per tower type with its Mastery skill
const UPGRADE_COSTS: Array[int] = [50, 80, 120, 180]
const UPGRADE_DAMAGE_FACTOR_PER_LEVEL: float = 0.6  # Damage path: every damage type +60% per level
const UPGRADE_RANGE_PER_LEVEL: float = 24.0      # Basic: 112 -> 136 -> 160 -> 184 px
const UPGRADE_COOLDOWN_FACTOR: float = 0.75      # 0.8 -> 0.6 -> 0.45 -> 0.34 s

# --- Waves (endless; see WaveGenerator) ---
const WAVE_BASE_ENEMY_COUNT: float = 6.0
const WAVE_ENEMY_COUNT_PER_WAVE: float = 2.2
## Past this wave the enemy count also grows quadratically: + LATE_WAVE_EXTRA * (w - start)^2.
const LATE_WAVE_START: int = 30
const LATE_WAVE_EXTRA: float = 0.15
const MAX_ENEMIES_PER_WAVE: int = 320
## Spawn intervals shrink over time: interval x 1 / (1 + SPAWN_RATE_GROWTH * (w - 1)),
## never below MIN_INTERVAL_SCALE. Counts grow faster than intervals shrink, so later
## waves still last longer.
const SPAWN_RATE_GROWTH: float = 0.03
const MIN_INTERVAL_SCALE: float = 0.22
const BOSS_WAVE_INTERVAL: int = 10
const MAX_BOSSES_PER_WAVE: int = 3
## Regular-enemy count multiplier on boss waves.
const BOSS_WAVE_ESCORT_FACTOR: float = 0.5
## Enemy health multiplier on wave w: (1 + LINEAR*(w-1)) * GROWTH^(w-1).
## Exponential growth outpaces any economy eventually, so endless runs always end;
## well-built mazes (long routes, upgrades, skills) push that point much further out.
const HEALTH_SCALE_LINEAR: float = 0.10
const HEALTH_SCALE_GROWTH: float = 1.10
const WAVE_CLEAR_BONUS_BASE: int = 30
const WAVE_CLEAR_BONUS_PER_WAVE: int = 5

# --- Diamonds and skill tree ---
const DIAMONDS_PER_WAVE: int = 1
## The skill tree opens automatically after every Nth completed wave.
const SKILL_MENU_WAVE_INTERVAL: int = 5
## Where permanent progress (diamonds + unlocked skills) is saved.
const PROGRESS_SAVE_PATH: String = "user://progress.json"
## Seconds between waves when auto-start is on.
const AUTO_START_DELAY: float = 3.0
