class_name Board
extends Node2D
## Sole owner of the grid: blocked cells, the AStarGrid2D pathfinder, grid <-> pixel
## conversion, placement validation, path queries and board/hover rendering.
## Board-local coordinates equal screen coordinates because the board sits at (0, 0).

signal navigation_changed(revision: int)
signal cell_clicked(cell: Vector2i)

const NO_CELL: Vector2i = Vector2i(-1, -1)
const HOVER_REFRESH_INTERVAL: float = 0.1

const MSG_OUT_OF_BOUNDS: String = "Outside the board"
const MSG_RESERVED: String = "Cannot build on the entrance or exit"
const MSG_OCCUPIED: String = "Occupied tile"
const MSG_ENEMY_ON_TILE: String = "An enemy is on or entering that tile"
const MSG_BLOCKS_ROUTE: String = "Cannot block the last route"
const MSG_STRANDS_ENEMY: String = "That would trap an enemy"

const COLOR_GROUND: Color = Color(0.20, 0.32, 0.18)
const COLOR_GROUND_ALT: Color = Color(0.22, 0.35, 0.20)
const COLOR_GRID: Color = Color(0.0, 0.0, 0.0, 0.18)
const COLOR_ENTRANCE: Color = Color(0.25, 0.85, 0.35)
const COLOR_EXIT: Color = Color(0.95, 0.40, 0.15)
const COLOR_HOVER_VALID: Color = Color(0.3, 1.0, 0.4, 0.40)
const COLOR_HOVER_INVALID: Color = Color(1.0, 0.25, 0.2, 0.40)

## Incremented on every committed change to blocked cells.
var revision: int = 0
var towers: Node2D
var enemies: Node2D

var _astar: AStarGrid2D = AStarGrid2D.new()
var _blocked: Dictionary = {}  # Vector2i -> true
var _build_mode: bool = false
var _can_afford: bool = true
var _hover_cell: Vector2i = NO_CELL
var _hover_valid: bool = false
var _hover_refresh_left: float = 0.0


func _init() -> void:
	_astar.region = Rect2i(0, 0, GameConfig.GRID_COLUMNS, GameConfig.GRID_ROWS)
	_astar.cell_size = Vector2(GameConfig.CELL_SIZE, GameConfig.CELL_SIZE)
	_astar.diagonal_mode = AStarGrid2D.DIAGONAL_MODE_NEVER
	_astar.default_compute_heuristic = AStarGrid2D.HEURISTIC_MANHATTAN
	_astar.default_estimate_heuristic = AStarGrid2D.HEURISTIC_MANHATTAN
	# update() resets solidity, so it is called exactly once, here.
	_astar.update()


func _ready() -> void:
	towers = get_node_or_null("Towers") as Node2D
	enemies = get_node_or_null("Enemies") as Node2D
	queue_redraw()


# --- Coordinates -------------------------------------------------------------

static func cell_to_world(cell: Vector2i) -> Vector2:
	var half: float = GameConfig.CELL_SIZE / 2.0
	return Vector2(cell.x * GameConfig.CELL_SIZE + half, cell.y * GameConfig.CELL_SIZE + half)


static func world_to_cell(pos: Vector2) -> Vector2i:
	return Vector2i(floori(pos.x / GameConfig.CELL_SIZE), floori(pos.y / GameConfig.CELL_SIZE))


static func is_in_bounds(cell: Vector2i) -> bool:
	return cell.x >= 0 and cell.y >= 0 and cell.x < GameConfig.GRID_COLUMNS and cell.y < GameConfig.GRID_ROWS


static func is_reserved(cell: Vector2i) -> bool:
	return cell == GameConfig.SPAWN_CELL or cell == GameConfig.EXIT_CELL


static func is_inside_board_pixels(pos: Vector2) -> bool:
	return pos.x >= 0.0 and pos.y >= 0.0 and pos.x < GameConfig.BOARD_WIDTH and pos.y < GameConfig.BOARD_HEIGHT


# --- Occupancy and paths -------------------------------------------------------

func is_blocked(cell: Vector2i) -> bool:
	return _blocked.has(cell)


func is_solid(cell: Vector2i) -> bool:
	return is_in_bounds(cell) and _astar.is_point_solid(cell)


func get_blocked_cells() -> Array[Vector2i]:
	var cells: Array[Vector2i] = []
	for cell: Vector2i in _blocked:
		cells.append(cell)
	return cells


## Returns the cardinal cell path from `from` to `to` (inclusive), or [] if none exists.
func find_path(from: Vector2i, to: Vector2i) -> Array[Vector2i]:
	if not is_in_bounds(from) or not is_in_bounds(to):
		return []
	if _astar.is_point_solid(from) or _astar.is_point_solid(to):
		return []
	return _astar.get_id_path(from, to)


## True when `path` starts at `from`, ends at `to`, avoids solid cells and only takes cardinal steps.
func is_valid_route(path: Array[Vector2i], from: Vector2i, to: Vector2i) -> bool:
	if path.is_empty() or path[0] != from or path[path.size() - 1] != to:
		return false
	for i in path.size():
		if is_solid(path[i]):
			return false
		if i > 0:
			var step: Vector2i = path[i] - path[i - 1]
			if absi(step.x) + absi(step.y) != 1:
				return false
	return true


func has_route(from: Vector2i, to: Vector2i) -> bool:
	return is_valid_route(find_path(from, to), from, to)


# --- Placement validation ------------------------------------------------------

## Checks whether `cell` could be blocked. Returns "" when valid, otherwise a player-facing reason.
## `occupied_cells`: cells living enemies stand on or are moving into (never buildable).
## `committed_waypoints`: each living enemy's committed next cell center; each must still reach the exit.
## The pathfinder is left exactly as it was found.
func validate_placement(cell: Vector2i, occupied_cells: Array[Vector2i], committed_waypoints: Array[Vector2i]) -> String:
	var reason: String = _basic_rejection(cell, occupied_cells)
	if reason != "":
		return reason
	_astar.set_point_solid(cell, true)
	reason = _route_rejection(committed_waypoints)
	_astar.set_point_solid(cell, false)
	return reason


## Blocks `cell` if every required route stays open. Returns "" on success, otherwise the
## rejection reason with the pathfinder unchanged.
func try_block_cell(cell: Vector2i, occupied_cells: Array[Vector2i], committed_waypoints: Array[Vector2i]) -> String:
	var reason: String = _basic_rejection(cell, occupied_cells)
	if reason != "":
		return reason
	_astar.set_point_solid(cell, true)
	reason = _route_rejection(committed_waypoints)
	if reason != "":
		_astar.set_point_solid(cell, false)
		return reason
	_blocked[cell] = true
	_bump_revision()
	return ""


## Validates `cell` against the live enemies inside the Enemies container.
func validate_placement_live(cell: Vector2i) -> String:
	return validate_placement(cell, get_enemy_occupied_cells(), get_enemy_committed_waypoints())


## Blocks `cell` for a tower, validating against the live enemies.
func try_block_cell_live(cell: Vector2i) -> String:
	return try_block_cell(cell, get_enemy_occupied_cells(), get_enemy_committed_waypoints())


## Rolls back a block (used if tower creation fails).
func unblock_cell(cell: Vector2i) -> void:
	if not _blocked.has(cell):
		return
	_blocked.erase(cell)
	_astar.set_point_solid(cell, false)
	_bump_revision()


func clear_blocked_cells() -> void:
	for cell: Vector2i in _blocked:
		_astar.set_point_solid(cell, false)
	_blocked.clear()
	_bump_revision()


func get_enemy_occupied_cells() -> Array[Vector2i]:
	var cells: Array[Vector2i] = []
	for enemy: Enemy in _active_enemies():
		cells.append_array(enemy.get_occupied_cells())
	return cells


func get_enemy_committed_waypoints() -> Array[Vector2i]:
	var cells: Array[Vector2i] = []
	for enemy: Enemy in _active_enemies():
		cells.append(enemy.get_committed_waypoint())
	return cells


func _active_enemies() -> Array[Enemy]:
	var list: Array[Enemy] = []
	if enemies == null:
		return list
	for child: Node in enemies.get_children():
		var enemy: Enemy = child as Enemy
		if enemy != null and enemy.is_active():
			list.append(enemy)
	return list


func _basic_rejection(cell: Vector2i, occupied_cells: Array[Vector2i]) -> String:
	if not is_in_bounds(cell):
		return MSG_OUT_OF_BOUNDS
	if is_reserved(cell):
		return MSG_RESERVED
	if _blocked.has(cell) or _astar.is_point_solid(cell):
		return MSG_OCCUPIED
	if occupied_cells.has(cell):
		return MSG_ENEMY_ON_TILE
	return ""


func _route_rejection(committed_waypoints: Array[Vector2i]) -> String:
	if not has_route(GameConfig.SPAWN_CELL, GameConfig.EXIT_CELL):
		return MSG_BLOCKS_ROUTE
	for waypoint: Vector2i in committed_waypoints:
		if not has_route(waypoint, GameConfig.EXIT_CELL):
			return MSG_STRANDS_ENEMY
	return ""


func _bump_revision() -> void:
	revision += 1
	_hover_refresh_left = 0.0
	navigation_changed.emit(revision)


# --- Input and hover -----------------------------------------------------------

## Called by Main whenever build mode or affordability changes.
func set_build_state(active: bool, can_afford: bool) -> void:
	_build_mode = active
	_can_afford = can_afford
	_hover_refresh_left = 0.0
	if not active:
		_hover_cell = NO_CELL
	queue_redraw()


func _unhandled_input(event: InputEvent) -> void:
	var mouse_event: InputEventMouseButton = event as InputEventMouseButton
	if mouse_event == null or not mouse_event.pressed or mouse_event.button_index != MOUSE_BUTTON_LEFT:
		return
	# UI panels consume their own clicks before _unhandled_input; this guards everything else.
	var local: Vector2 = get_local_mouse_position()
	if not is_inside_board_pixels(local):
		return
	get_viewport().set_input_as_handled()
	cell_clicked.emit(world_to_cell(local))


func _process(delta: float) -> void:
	if not _build_mode:
		return
	var local: Vector2 = get_local_mouse_position()
	var cell: Vector2i = world_to_cell(local) if is_inside_board_pixels(local) else NO_CELL
	_hover_refresh_left -= delta
	# Enemies move, so validity is re-checked periodically even if the mouse is still.
	if cell == _hover_cell and _hover_refresh_left > 0.0:
		return
	_hover_cell = cell
	_hover_refresh_left = HOVER_REFRESH_INTERVAL
	_hover_valid = cell != NO_CELL and _can_afford and validate_placement_live(cell) == ""
	queue_redraw()


# --- Rendering -------------------------------------------------------------------

func _draw() -> void:
	var size_px: int = GameConfig.CELL_SIZE
	draw_rect(Rect2(0, 0, GameConfig.BOARD_WIDTH, GameConfig.BOARD_HEIGHT), COLOR_GROUND)
	for y in GameConfig.GRID_ROWS:
		for x in GameConfig.GRID_COLUMNS:
			if (x + y) % 2 == 0:
				draw_rect(_cell_rect(Vector2i(x, y)), COLOR_GROUND_ALT)
	for x in GameConfig.GRID_COLUMNS + 1:
		draw_line(Vector2(x * size_px, 0), Vector2(x * size_px, GameConfig.BOARD_HEIGHT), COLOR_GRID, 1.0)
	for y in GameConfig.GRID_ROWS + 1:
		draw_line(Vector2(0, y * size_px), Vector2(GameConfig.BOARD_WIDTH, y * size_px), COLOR_GRID, 1.0)

	_draw_marker(GameConfig.SPAWN_CELL, COLOR_ENTRANCE, "IN")
	_draw_marker(GameConfig.EXIT_CELL, COLOR_EXIT, "OUT")

	if _build_mode and _hover_cell != NO_CELL:
		var color: Color = COLOR_HOVER_VALID if _hover_valid else COLOR_HOVER_INVALID
		draw_rect(_cell_rect(_hover_cell), color)
		draw_rect(_cell_rect(_hover_cell), Color(color, 0.9), false, 2.0)
		if _hover_valid:
			draw_arc(cell_to_world(_hover_cell), GameConfig.TOWER_RANGE, 0.0, TAU, 48, Color(1, 1, 1, 0.35), 1.5)


func _draw_marker(cell: Vector2i, color: Color, text: String) -> void:
	draw_rect(_cell_rect(cell).grow(-2.0), color)
	var font: Font = ThemeDB.fallback_font
	var rect: Rect2 = _cell_rect(cell)
	draw_string(font, rect.position + Vector2(0, 21), text, HORIZONTAL_ALIGNMENT_CENTER, rect.size.x, 12, Color.BLACK)


func _cell_rect(cell: Vector2i) -> Rect2:
	return Rect2(cell.x * GameConfig.CELL_SIZE, cell.y * GameConfig.CELL_SIZE, GameConfig.CELL_SIZE, GameConfig.CELL_SIZE)
