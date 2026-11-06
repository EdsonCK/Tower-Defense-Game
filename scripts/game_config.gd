class_name GameConfig
extends RefCounted
## Shared tuning constants. Holds no game state; edit values here to rebalance.
## Enemy type stats live in enemy_types.gd; wave scaling formulas in wave_generator.gd.

# --- Board ---
## The on-screen board area (pixels). The map is drawn scaled to fit it.
const BOARD_WIDTH: int = 1280
const BOARD_HEIGHT: int = 768
## World size of one map cell before scaling.
const CELL_SIZE: int = 32
## Full map grid (the visible window grows inside it). The exit sits at the center.
const GRID_COLUMNS: int = 61
const GRID_ROWS: int = 37
const EXIT_CELL: Vector2i = Vector2i(30, 18)
## The visible window is |dx| <= half_width, |dy| <= floor(3 * half_width / 5) around the
## exit. It starts small and grows by one ring after every wave up to the full grid.
const MAP_START_HALF_WIDTH: int = 11
const MAP_MAX_HALF_WIDTH: int = 30
const MAP_GROWTH_PER_WAVE: int = 1
## Path network: branches from the exit, plus forks that create crossroads further out.
const MAP_ROOT_BRANCHES: int = 2
const MAP_FORK_BRANCHES: int = 5
## Waves per biome (art style and tower buffs change every this many waves).
const BIOME_WAVES: int = 10

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
## Every Nth wave is a boss wave: a single Colossus with enormous health, no escort.
const BOSS_WAVE_INTERVAL: int = 15
## Enemy health multiplier on wave w: (1 + LINEAR*(w-1)) * GROWTH^(w-1).
## Exponential growth outpaces any economy eventually, so endless runs always end;
## strong placement, upgrades and skills push that point much further out.
const HEALTH_SCALE_LINEAR: float = 0.10
const HEALTH_SCALE_GROWTH: float = 1.065
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
