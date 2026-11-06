class_name Board
extends Node2D
## Owns the map: the fixed path network (MapLayout), the visible window that grows each
## wave, tower occupancy, placement rules, grid <-> world conversion, fitting the
## window to the screen, input on the map, and drawing ground, decorations and path in
## the current biome. Towers and enemies are children and use world coordinates
## (CELL_SIZE px per cell); this node is scaled and positioned so the window fills its
## BoardArea.

signal cell_clicked(cell: Vector2i)

const NO_CELL: Vector2i = Vector2i(-1, -1)
const HOVER_REFRESH_INTERVAL: float = 0.1

const MSG_OUTSIDE: String = "Outside the map"
const MSG_ON_PATH: String = "Towers can't be built on the path"
const MSG_GATE: String = "Can't build on the gate"
const MSG_OCCUPIED: String = "Occupied tile"

const COLOR_HOVER_VALID: Color = Color(0.3, 1.0, 0.4, 0.40)
const COLOR_HOVER_INVALID: Color = Color(1.0, 0.25, 0.2, 0.40)
const COLOR_ENTRANCE: Color = Color(0.85, 0.25, 0.25)
const COLOR_GATE: Color = Color(0.55, 0.58, 0.66)

var layout: MapLayout = MapLayout.new(0)
var half_width: int = GameConfig.MAP_START_HALF_WIDTH
var biome_index: int = 0
var towers: Node2D
var enemies: Node2D

var _blocked: Dictionary = {}  # Vector2i -> true (cells with a tower)
var _entrances: Array[Vector2i] = []
var _build_mode: bool = false
var _can_afford: bool = true
var _preview_range: float = GameConfig.TOWER_RANGE
var _hover_cell: Vector2i = NO_CELL
var _hover_valid: bool = false
var _hover_refresh_left: float = 0.0
var _fit_area: Vector2 = Vector2(GameConfig.BOARD_WIDTH, GameConfig.BOARD_HEIGHT)


func _ready() -> void:
	towers = get_node_or_null("Towers") as Node2D
	enemies = get_node_or_null("Enemies") as Node2D
	_entrances = layout.entrances(half_width)
	fit_to(_fit_area)


## New run: generates the path network from `seed_value`, resets the window and towers.
func setup_map(seed_value: int) -> void:
	layout = MapLayout.new(seed_value)
	_blocked.clear()
	biome_index = 0
	set_half_width(GameConfig.MAP_START_HALF_WIDTH)


func set_half_width(new_half_width: int) -> void:
	half_width = clampi(new_half_width, 1, GameConfig.MAP_MAX_HALF_WIDTH)
	_entrances = layout.entrances(half_width)
	_hover_refresh_left = 0.0
	fit_to(_fit_area)
	queue_redraw()


func set_biome(index: int) -> void:
	if index == biome_index:
		return
	biome_index = index
	queue_redraw()


func half_height() -> int:
	return MapLayout.half_height(half_width)


## Visible window in cells.
func window_rect_cells() -> Rect2i:
	var e: Vector2i = layout.exit
	return Rect2i(e.x - half_width, e.y - half_height(), 2 * half_width + 1, 2 * half_height() + 1)


## Visible window in world pixels.
func window_rect_world() -> Rect2:
	var cells: Rect2i = window_rect_cells()
	return Rect2(Vector2(cells.position) * GameConfig.CELL_SIZE, Vector2(cells.size) * GameConfig.CELL_SIZE)


## Scales and positions this node so the window fills `area` (centered, aspect kept).
func fit_to(area: Vector2) -> void:
	_fit_area = area
	var world: Rect2 = window_rect_world()
	var s: float = minf(area.x / world.size.x, area.y / world.size.y)
	scale = Vector2(s, s)
	position = area / 2.0 - world.get_center() * s


# --- Coordinates -------------------------------------------------------------

static func cell_to_world(cell: Vector2i) -> Vector2:
	var half: float = GameConfig.CELL_SIZE / 2.0
	return Vector2(cell.x * GameConfig.CELL_SIZE + half, cell.y * GameConfig.CELL_SIZE + half)


static func world_to_cell(pos: Vector2) -> Vector2i:
	return Vector2i(floori(pos.x / GameConfig.CELL_SIZE), floori(pos.y / GameConfig.CELL_SIZE))


## Inside the full map grid (not necessarily visible yet).
static func is_in_bounds(cell: Vector2i) -> bool:
	return MapLayout.in_grid(cell)


func in_window(cell: Vector2i) -> bool:
	return MapLayout.in_window(cell, half_width)


func is_inside_window_world(pos: Vector2) -> bool:
	return window_rect_world().has_point(pos)


# --- Path ------------------------------------------------------------------------

func is_path(cell: Vector2i) -> bool:
	return layout.is_path(cell)


func exit_cell() -> Vector2i:
	return layout.exit


## Where enemies enter the current window.
func entrances() -> Array[Vector2i]:
	return _entrances


func next_cell(cell: Vector2i) -> Vector2i:
	return layout.next_cell(cell)


func distance_to_exit(cell: Vector2i) -> int:
	return layout.distance.get(cell, 0)


# --- Placement -------------------------------------------------------------------

## "" if a tower may be built on `cell`, otherwise a player-facing reason.
func placement_rejection(cell: Vector2i) -> String:
	if not in_window(cell):
		return MSG_OUTSIDE
	if cell == layout.exit:
		return MSG_GATE
	if layout.is_path(cell):
		return MSG_ON_PATH
	if _blocked.has(cell):
		return MSG_OCCUPIED
	return ""


func is_buildable(cell: Vector2i) -> bool:
	return placement_rejection(cell) == ""


## Marks `cell` as holding a tower if allowed. Returns "" on success.
func try_block_cell(cell: Vector2i) -> String:
	var reason: String = placement_rejection(cell)
	if reason != "":
		return reason
	_blocked[cell] = true
	queue_redraw()
	return ""


func unblock_cell(cell: Vector2i) -> void:
	if _blocked.erase(cell):
		queue_redraw()


func clear_blocked_cells() -> void:
	_blocked.clear()
	queue_redraw()


func is_blocked(cell: Vector2i) -> bool:
	return _blocked.has(cell)


func get_blocked_cells() -> Array[Vector2i]:
	var cells: Array[Vector2i] = []
	for cell: Vector2i in _blocked:
		cells.append(cell)
	return cells


## Every buildable cell in the window.
func buildable_cells() -> Array[Vector2i]:
	var cells: Array[Vector2i] = []
	var rect: Rect2i = window_rect_cells()
	for y in range(rect.position.y, rect.end.y):
		for x in range(rect.position.x, rect.end.x):
			var cell: Vector2i = Vector2i(x, y)
			if is_buildable(cell):
				cells.append(cell)
	return cells


# --- Input and hover -----------------------------------------------------------

## Called by Main whenever build mode, affordability or the build type changes.
func set_build_state(active: bool, can_afford: bool, preview_range: float = GameConfig.TOWER_RANGE) -> void:
	if active == _build_mode and can_afford == _can_afford and preview_range == _preview_range:
		return  # called on every HUD refresh; only redraw on a real change
	_build_mode = active
	_can_afford = can_afford
	_preview_range = preview_range
	_hover_refresh_left = 0.0
	if not active:
		_hover_cell = NO_CELL
	queue_redraw()


func _unhandled_input(event: InputEvent) -> void:
	var mouse_event: InputEventMouseButton = event as InputEventMouseButton
	if mouse_event == null or not mouse_event.pressed or mouse_event.button_index != MOUSE_BUTTON_LEFT:
		return
	# UI panels consume their own clicks before _unhandled_input. make_input_local applies
	# the window stretch and this node's zoom, so this works at any size.
	var local: Vector2 = (make_input_local(mouse_event) as InputEventMouseButton).position
	if not is_inside_window_world(local):
		return
	get_viewport().set_input_as_handled()
	cell_clicked.emit(world_to_cell(local))


func _process(delta: float) -> void:
	if not _build_mode:
		return
	var local: Vector2 = get_local_mouse_position()
	var cell: Vector2i = world_to_cell(local) if is_inside_window_world(local) else NO_CELL
	_hover_refresh_left -= delta
	if cell == _hover_cell and _hover_refresh_left > 0.0:
		return
	_hover_cell = cell
	_hover_refresh_left = HOVER_REFRESH_INTERVAL
	_hover_valid = cell != NO_CELL and _can_afford and is_buildable(cell)
	queue_redraw()


# --- Rendering -------------------------------------------------------------------

func _draw() -> void:
	var biome: Dictionary = Biomes.get_def(biome_index)
	var cs: float = GameConfig.CELL_SIZE
	var rect: Rect2i = window_rect_cells()
	var world: Rect2 = window_rect_world()
	# Fog of unexplored land around the window.
	draw_rect(world.grow(cs * 40.0), (biome["ground"] as Color).darkened(0.72))
	draw_rect(world.grow(cs * 0.25), (biome["ground"] as Color).darkened(0.5))
	for y in range(rect.position.y, rect.end.y):
		for x in range(rect.position.x, rect.end.x):
			var cell: Vector2i = Vector2i(x, y)
			var shade: float = _hash01(cell, 11)
			var ground: Color = (biome["ground_alt"] if (x + y) % 2 == 0 else biome["ground"]) as Color
			draw_rect(_cell_rect(cell), ground.lerp(ground.darkened(0.08), shade))
	for x in range(rect.position.x, rect.end.x + 1):
		draw_line(Vector2(x * cs, world.position.y), Vector2(x * cs, world.end.y), biome["grid"], 1.0)
	for y in range(rect.position.y, rect.end.y + 1):
		draw_line(Vector2(world.position.x, y * cs), Vector2(world.end.x, y * cs), biome["grid"], 1.0)
	# Decorations on free ground (never on the path or under towers).
	for y in range(rect.position.y, rect.end.y):
		for x in range(rect.position.x, rect.end.x):
			var cell: Vector2i = Vector2i(x, y)
			if not layout.is_path(cell) and not _blocked.has(cell) and not _next_to_path(cell) and _hash01(cell, biome_index * 7 + 3) < biome["deco_density"]:
				_draw_decoration(cell, biome)
	# Path (same palette in every biome).
	for cell: Vector2i in layout.parent:
		if in_window(cell):
			_draw_path_cell(cell)
	for cell: Vector2i in _entrances:
		_draw_entrance(cell)
	_draw_gate(layout.exit)
	if _build_mode and _hover_cell != NO_CELL:
		var color: Color = COLOR_HOVER_VALID if _hover_valid else COLOR_HOVER_INVALID
		draw_rect(_cell_rect(_hover_cell), color)
		draw_rect(_cell_rect(_hover_cell), Color(color, 0.9), false, 2.0)
		if _hover_valid:
			draw_arc(cell_to_world(_hover_cell), _preview_range, 0.0, TAU, 48, Color(1, 1, 1, 0.45), 1.5)


func _next_to_path(cell: Vector2i) -> bool:
	for d: Vector2i in MapLayout.DIRECTIONS:
		if layout.is_path(cell + d):
			return true
	return false


func _draw_path_cell(cell: Vector2i) -> void:
	var cs: float = GameConfig.CELL_SIZE
	var center: Vector2 = cell_to_world(cell)
	var linked: Array[Vector2i] = []
	if cell != layout.exit:
		linked.append(layout.parent[cell])
	for kid: Vector2i in layout.children.get(cell, []):
		linked.append(kid)
	# Dark edge, then the dirt fill, each a center square plus connectors to linked cells.
	for pass_index in 2:
		var inset: float = 2.0 if pass_index == 0 else 5.0
		var color: Color = Biomes.PATH_EDGE if pass_index == 0 else Biomes.PATH_COLOR
		var core: Rect2 = Rect2(center - Vector2(cs / 2.0 - inset, cs / 2.0 - inset), Vector2(cs - 2.0 * inset, cs - 2.0 * inset))
		draw_rect(core, color)
		for other: Vector2i in linked:
			var d: Vector2 = Vector2(other - cell)
			var half_len: float = cs / 2.0
			var width: float = cs - 2.0 * inset
			var connector: Rect2
			if d.x != 0.0:
				connector = Rect2(center + Vector2(minf(0.0, d.x) * half_len, -width / 2.0), Vector2(half_len, width))
			else:
				connector = Rect2(center + Vector2(-width / 2.0, minf(0.0, d.y) * half_len), Vector2(width, half_len))
			draw_rect(connector, color)
	for i in 2:
		var offset: Vector2 = Vector2(_hash01(cell, 20 + i) - 0.5, _hash01(cell, 30 + i) - 0.5) * (cs * 0.5)
		draw_circle(center + offset, 1.6, Biomes.PATH_PEBBLE)


func _draw_entrance(cell: Vector2i) -> void:
	var center: Vector2 = cell_to_world(cell)
	draw_circle(center + Vector2(1.5, 2.5), 13.0, Color(0, 0, 0, 0.3))
	draw_circle(center, 13.0, COLOR_ENTRANCE.darkened(0.45))
	draw_arc(center, 13.0, 0.0, TAU, 24, COLOR_ENTRANCE, 3.0)
	draw_circle(center, 6.0, Color(1.0, 0.6, 0.5, 0.9))


func _draw_gate(cell: Vector2i) -> void:
	var center: Vector2 = cell_to_world(cell)
	var body: Rect2 = Rect2(center - Vector2(15, 13), Vector2(30, 26))
	draw_rect(body.grow(1.0).abs(), Biomes.OUTLINE)
	draw_rect(Rect2(body.position + Vector2(2, 3), body.size), Color(0, 0, 0, 0.3))
	draw_rect(body, COLOR_GATE)
	for i in 4:
		draw_rect(Rect2(body.position + Vector2(1 + i * 8, -6), Vector2(5, 6)), COLOR_GATE.darkened(0.1))
	draw_rect(Rect2(center + Vector2(-6, -2), Vector2(12, 15)), Color(0.18, 0.12, 0.1))
	draw_line(center + Vector2(9, -13), center + Vector2(9, -26), Biomes.OUTLINE, 2.0)
	draw_colored_polygon(PackedVector2Array([center + Vector2(10, -26), center + Vector2(22, -22), center + Vector2(10, -18)]), Color(0.3, 0.55, 1.0))


## Draws one biome decoration. All share the style: flat fill, dark outline, soft shadow.
func _draw_decoration(cell: Vector2i, biome: Dictionary) -> void:
	var c: Dictionary = biome["deco_colors"]
	var kind: String = _pick_decoration(cell, biome["decorations"])
	var center: Vector2 = cell_to_world(cell) + Vector2(_hash01(cell, 41) - 0.5, _hash01(cell, 43) - 0.5) * 8.0
	var size: float = 0.8 + 0.4 * _hash01(cell, 47)
	var shadow: Color = Color(0, 0, 0, 0.22)
	match kind:
		"tree", "autumn_tree":
			draw_circle(center + Vector2(3, 6), 10.0 * size, shadow)
			draw_rect(Rect2(center + Vector2(-2, 2), Vector2(4, 9)), c["trunk"])
			draw_circle(center, 10.0 * size + 1.0, Biomes.OUTLINE)
			draw_circle(center, 10.0 * size, c["leaf"])
			draw_circle(center + Vector2(-3, -3) * size, 5.0 * size, c["leaf_light"])
		"bush":
			draw_circle(center + Vector2(2, 4), 7.0 * size, shadow)
			for o: Vector2 in [Vector2(-4, 1), Vector2(4, 1), Vector2(0, -3)]:
				draw_circle(center + o * size, 5.0 * size + 1.0, Biomes.OUTLINE)
			for o: Vector2 in [Vector2(-4, 1), Vector2(4, 1), Vector2(0, -3)]:
				draw_circle(center + o * size, 5.0 * size, c["leaf_light"])
		"flowers":
			for i in 3:
				var p: Vector2 = center + Vector2(_hash01(cell, 50 + i) - 0.5, _hash01(cell, 60 + i) - 0.5) * 18.0
				draw_line(p, p + Vector2(0, 5), c["leaf"], 1.5)
				draw_circle(p, 2.5, c["flower_a"] if i % 2 == 0 else c["flower_b"])
		"rock", "snow_rock":
			var rock: PackedVector2Array = PackedVector2Array([center + Vector2(-8, 4) * size, center + Vector2(-5, -5) * size,
				center + Vector2(4, -6) * size, center + Vector2(9, 2) * size, center + Vector2(4, 6) * size])
			draw_colored_polygon(_offset(rock, Vector2(2, 3)), shadow)
			draw_colored_polygon(rock, c["rock"])
			rock.append(rock[0])
			draw_polyline(rock, Biomes.OUTLINE, 1.5)
			if kind == "snow_rock":
				draw_colored_polygon(PackedVector2Array([center + Vector2(-5, -5) * size, center + Vector2(4, -6) * size, center + Vector2(1, -2) * size]), c["snow"])
		"cactus":
			draw_rect(Rect2(center + Vector2(-2, 6), Vector2(8, 3)), shadow)
			for part: Rect2 in [Rect2(-3, -10, 6, 18), Rect2(-9, -4, 4, 8), Rect2(5, -7, 4, 7)]:
				var r: Rect2 = Rect2(center + part.position * size, part.size * size)
				draw_rect(r.grow(1.0), Biomes.OUTLINE)
				draw_rect(r, c["cactus"])
			draw_line(center + Vector2(0, -9) * size, center + Vector2(0, 6) * size, c["cactus_light"], 1.0)
		"dune":
			draw_arc(center + Vector2(0, 6), 10.0 * size, PI * 1.1, PI * 1.9, 12, c["dune"], 3.0)
			draw_arc(center + Vector2(6, 0), 7.0 * size, PI * 1.1, PI * 1.9, 12, c["dune"], 2.0)
		"bones":
			draw_line(center + Vector2(-6, -2), center + Vector2(6, 2), c["bones"], 2.5)
			draw_circle(center + Vector2(-6, -2), 2.5, c["bones"])
			draw_circle(center + Vector2(6, 2), 2.5, c["bones"])
		"pine":
			draw_circle(center + Vector2(3, 8), 8.0 * size, shadow)
			draw_rect(Rect2(center + Vector2(-2, 5), Vector2(4, 5)), c["trunk"])
			var tri: PackedVector2Array = PackedVector2Array([center + Vector2(0, -13) * size, center + Vector2(9, 6) * size, center + Vector2(-9, 6) * size])
			draw_colored_polygon(tri, c["pine"])
			tri.append(tri[0])
			draw_polyline(tri, Biomes.OUTLINE, 1.5)
			draw_colored_polygon(PackedVector2Array([center + Vector2(0, -13) * size, center + Vector2(4, -5) * size, center + Vector2(-4, -5) * size]), c["snow"])
		"ice":
			var shard: PackedVector2Array = PackedVector2Array([center + Vector2(0, -10) * size, center + Vector2(5, 0), center + Vector2(0, 8) * size, center + Vector2(-5, 0)])
			draw_colored_polygon(_offset(shard, Vector2(2, 3)), shadow)
			draw_colored_polygon(shard, c["ice"])
			shard.append(shard[0])
			draw_polyline(shard, Biomes.OUTLINE, 1.2)
		"lava":
			var crack: PackedVector2Array = PackedVector2Array([center + Vector2(-10, -3), center + Vector2(-3, 1), center + Vector2(2, -4), center + Vector2(10, 3)])
			draw_polyline(crack, c["lava_glow"], 4.0)
			draw_polyline(crack, c["lava"], 2.0)
		"stump":
			draw_circle(center + Vector2(2, 3), 6.0 * size, shadow)
			draw_circle(center, 6.0 * size + 1.0, Biomes.OUTLINE)
			draw_circle(center, 6.0 * size, c["stump"])
			draw_arc(center, 3.0 * size, 0.0, TAU, 12, c["stump"].lightened(0.25), 1.0)
		"obsidian":
			var spike: PackedVector2Array = PackedVector2Array([center + Vector2(-6, 6), center + Vector2(-2, -10) * size, center + Vector2(3, -4), center + Vector2(7, 6)])
			draw_colored_polygon(_offset(spike, Vector2(2, 3)), shadow)
			draw_colored_polygon(spike, c["obsidian"])
			draw_line(center + Vector2(-2, -10) * size, center + Vector2(0, 4), c["obsidian_light"], 1.2)
		"reeds":
			for i in 4:
				var base: Vector2 = center + Vector2(-6 + i * 4, 7)
				var tip: Vector2 = base + Vector2((_hash01(cell, 70 + i) - 0.5) * 6.0, -12.0 * size)
				draw_line(base, tip, c["reed"], 1.5)
				draw_rect(Rect2(tip - Vector2(1.2, 0), Vector2(2.4, 4)), c["reed_top"])
		"pond":
			draw_circle(center, 11.0 * size + 1.0, Biomes.OUTLINE)
			draw_circle(center, 11.0 * size, c["water"])
			draw_circle(center + Vector2(-3, 2), 3.5, c["lily"])
			draw_circle(center + Vector2(4, -3), 2.5, c["lily"])
		"mushroom":
			draw_rect(Rect2(center + Vector2(-1.5, -1), Vector2(3, 7)), c["stem"])
			draw_circle(center + Vector2(0, -1), 5.0 * size + 1.0, Biomes.OUTLINE)
			draw_circle(center + Vector2(0, -1), 5.0 * size, c["cap"])
			draw_circle(center + Vector2(-2, -3), 1.2, c["stem"])
		"leaves":
			for i in 4:
				var p: Vector2 = center + Vector2(_hash01(cell, 80 + i) - 0.5, _hash01(cell, 90 + i) - 0.5) * 20.0
				draw_circle(p, 2.5, c["leaves"] if i % 2 == 0 else c["leaf_light"])
		"pumpkin":
			draw_circle(center + Vector2(2, 3), 7.0, shadow)
			draw_circle(center, 7.0, Biomes.OUTLINE)
			draw_circle(center, 6.0, c["pumpkin"])
			draw_line(center + Vector2(0, -6), center + Vector2(1, -9), Color(0.3, 0.45, 0.2), 2.0)


func _pick_decoration(cell: Vector2i, options: Array) -> String:
	var total: float = 0.0
	for option: Array in options:
		total += float(option[1])
	var roll: float = _hash01(cell, 97) * total
	for option: Array in options:
		roll -= float(option[1])
		if roll <= 0.0:
			return option[0]
	return options[options.size() - 1][0]


static func _offset(points: PackedVector2Array, by: Vector2) -> PackedVector2Array:
	var moved: PackedVector2Array = PackedVector2Array()
	for p: Vector2 in points:
		moved.append(p + by)
	return moved


## Stable pseudo-random value in [0, 1) for a cell (so decorations never flicker).
func _hash01(cell: Vector2i, salt: int) -> float:
	return float(absi(hash([cell.x, cell.y, salt])) % 10007) / 10007.0


func _cell_rect(cell: Vector2i) -> Rect2:
	return Rect2(cell.x * GameConfig.CELL_SIZE, cell.y * GameConfig.CELL_SIZE, GameConfig.CELL_SIZE, GameConfig.CELL_SIZE)
