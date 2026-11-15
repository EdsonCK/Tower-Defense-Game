class_name Board
extends Node2D
## Owns the map: the fixed path network (MapLayout), the visible window that grows each
## wave, tower occupancy, placement rules, grid <-> world conversion, fitting the
## window to the screen, input on the map, and drawing ground, decorations and path in
## the current biome. Towers and enemies are children and use world coordinates
## (CELL_SIZE px per cell); this node is scaled and positioned so the window fills its
## BoardArea.
##
## Art is split into child layers, back to front: Terrain (ground, path, lakes, fog;
## one shader pass), DecorLayer (scenery), MapMarkers (gate and entrance portals),
## Overlay (build hover and range preview), then Towers and Enemies, then Atmosphere
## (ambient particles). The board itself draws nothing.

signal cell_clicked(cell: Vector2i)

const NO_CELL: Vector2i = Vector2i(-1, -1)
const HOVER_REFRESH_INTERVAL: float = 0.1
## Camera: zoom 1.0 is "fit the whole window" (the most zoomed-out view); the player can
## zoom in up to MAX_ZOOM and pan around while zoomed.
const MAX_ZOOM: float = 3.0
const ZOOM_STEP: float = 1.15
const KEY_PAN_SPEED: float = 900.0  # screen px per second

const MSG_OUTSIDE: String = "Outside the map"
const MSG_ON_PATH: String = "Towers can't be built on the path"
const MSG_GATE: String = "Can't build on the gate"
const MSG_OCCUPIED: String = "Occupied tile"
const MSG_FEATURE: String = "Can't build on the "  # + the biome's lake name ("pond", "lava pool"...)

const COLOR_HOVER_VALID: Color = Color(0.3, 1.0, 0.4, 0.40)
const COLOR_HOVER_INVALID: Color = Color(1.0, 0.25, 0.2, 0.40)

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
var zoom: float = 1.0
var _focus: Vector2 = Vector2.ZERO  # world point at the center of the view
var _dragging: bool = false
var terrain: Terrain
var decor: DecorLayer
var markers: MapMarkers
var overlay: Node2D
var atmosphere: Atmosphere


func _ready() -> void:
	towers = get_node_or_null("Towers") as Node2D
	enemies = get_node_or_null("Enemies") as Node2D
	_ensure_layers()
	_entrances = layout.entrances(half_width)
	fit_to(_fit_area)
	_refresh_map_art()
	_refresh_biome_art(false)


## Creates the art layers once (see the class comment for their order).
func _ensure_layers() -> void:
	if terrain != null:
		return
	terrain = Terrain.new()
	terrain.name = "Terrain"
	decor = DecorLayer.new()
	decor.name = "Decor"
	decor.board = self
	markers = MapMarkers.new()
	markers.name = "Markers"
	markers.board = self
	overlay = Node2D.new()
	overlay.name = "Overlay"
	overlay.draw.connect(_draw_overlay)
	var layers: Array[Node2D] = [terrain, decor, markers, overlay]
	for i in layers.size():
		add_child(layers[i])
		move_child(layers[i], i)
	atmosphere = Atmosphere.new()
	atmosphere.name = "Atmosphere"
	add_child(atmosphere)


func _refresh_map_art() -> void:
	if terrain == null:
		return
	terrain.update_map(layout, half_width, window_rect_world())
	decor.queue_redraw()
	markers.queue_redraw()
	overlay.queue_redraw()
	atmosphere.configure(atmosphere.kind, window_rect_world())


func _refresh_biome_art(animate: bool) -> void:
	if terrain == null:
		return
	var def: Dictionary = Biomes.get_def(maxi(biome_index, 0))
	terrain.apply_biome(biome_index, animate)
	decor.queue_redraw()
	atmosphere.configure(def["particles"], window_rect_world())


## New run: generates the path network from `seed_value`, resets the window and towers.
func setup_map(seed_value: int) -> void:
	layout = MapLayout.new(seed_value)
	_blocked.clear()
	biome_index = 0
	zoom = 1.0
	_focus = window_rect_world().get_center()
	set_half_width(GameConfig.MAP_START_HALF_WIDTH)
	_refresh_biome_art(false)


func set_half_width(new_half_width: int) -> void:
	half_width = clampi(new_half_width, 1, GameConfig.MAP_MAX_HALF_WIDTH)
	_entrances = layout.entrances(half_width)
	_hover_refresh_left = 0.0
	fit_to(_fit_area)
	_refresh_map_art()


func set_biome(index: int) -> void:
	if index == biome_index:
		return
	biome_index = index
	_refresh_biome_art(true)


## Name of the current biome's lakes ("pond", "lava pool", ...).
func feature_name() -> String:
	return Biomes.get_def(maxi(biome_index, 0))["feature"]


func is_feature(cell: Vector2i) -> bool:
	return layout.is_feature(cell)


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


## Scales and positions this node so the window fills `area` (centered, aspect kept) at
## zoom 1.0, or shows a zoomed-in, panned part of it.
func fit_to(area: Vector2) -> void:
	_fit_area = area
	_apply_camera()


## Scale that shows the whole window (zoom 1.0).
func fit_scale() -> float:
	var world: Rect2 = window_rect_world()
	return minf(_fit_area.x / world.size.x, _fit_area.y / world.size.y)


func set_zoom(new_zoom: float, anchor_screen: Vector2 = Vector2(-1, -1)) -> void:
	# Keep the world point under `anchor_screen` (board-area pixels) fixed while zooming.
	var anchor: Vector2 = _fit_area / 2.0 if anchor_screen.x < 0.0 else anchor_screen
	var world_under: Vector2 = (anchor - position) / scale.x
	zoom = clampf(new_zoom, 1.0, MAX_ZOOM)
	var s: float = fit_scale() * zoom
	_focus = world_under + (_fit_area / 2.0 - anchor) / s
	_apply_camera()


## Moves the view by `screen_delta` board-area pixels (the map follows the drag).
func pan_by(screen_delta: Vector2) -> void:
	_focus -= screen_delta / scale.x
	_apply_camera()


func reset_camera() -> void:
	zoom = 1.0
	_focus = window_rect_world().get_center()
	_apply_camera()


func view_center() -> Vector2:
	return _focus


func _apply_camera() -> void:
	var world: Rect2 = window_rect_world()
	var s: float = fit_scale() * zoom
	# Clamp so the view never leaves the window; at zoom 1 this centers it exactly.
	var half_view: Vector2 = _fit_area / (2.0 * s)
	for axis in 2:
		var lo: float = world.position[axis] + half_view[axis]
		var hi: float = world.end[axis] - half_view[axis]
		_focus[axis] = world.get_center()[axis] if lo >= hi else clampf(_focus[axis], lo, hi)
	scale = Vector2(s, s)
	position = _fit_area / 2.0 - _focus * s


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
	if layout.is_feature(cell):
		return MSG_FEATURE + feature_name()
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
	_redraw_decor()
	return ""


func unblock_cell(cell: Vector2i) -> void:
	if _blocked.erase(cell):
		_redraw_decor()


func clear_blocked_cells() -> void:
	_blocked.clear()
	_redraw_decor()


func _redraw_decor() -> void:
	if decor != null:
		decor.queue_redraw()  # scenery is hidden under towers


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
	if terrain != null:
		terrain.set_grid_visible(active)
		overlay.queue_redraw()


func _unhandled_input(event: InputEvent) -> void:
	var motion: InputEventMouseMotion = event as InputEventMouseMotion
	if motion != null:
		if _dragging:
			pan_by(motion.relative * _screen_to_area_factor())
			get_viewport().set_input_as_handled()
		return
	var key: InputEventKey = event as InputEventKey
	if key != null and key.pressed:
		match key.keycode:
			KEY_EQUAL, KEY_PLUS, KEY_KP_ADD:
				set_zoom(zoom * ZOOM_STEP)
			KEY_MINUS, KEY_KP_SUBTRACT:
				set_zoom(zoom / ZOOM_STEP)
			KEY_HOME:
				reset_camera()
			_:
				return
		get_viewport().set_input_as_handled()
		return
	var mouse_event: InputEventMouseButton = event as InputEventMouseButton
	if mouse_event == null:
		return
	if mouse_event.button_index == MOUSE_BUTTON_MIDDLE:
		_dragging = mouse_event.pressed and _event_in_area(mouse_event)
		if _dragging or not mouse_event.pressed:
			get_viewport().set_input_as_handled()
		return
	if not mouse_event.pressed:
		return
	# UI panels consume their own clicks before _unhandled_input. make_input_local applies
	# the window stretch and this node's zoom, so this works at any size.
	var local: Vector2 = (make_input_local(mouse_event) as InputEventMouseButton).position
	if mouse_event.button_index == MOUSE_BUTTON_WHEEL_UP or mouse_event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
		if not _event_in_area(mouse_event):
			return
		var factor: float = ZOOM_STEP if mouse_event.button_index == MOUSE_BUTTON_WHEEL_UP else 1.0 / ZOOM_STEP
		set_zoom(zoom * factor, position + local * scale.x)
		get_viewport().set_input_as_handled()
		return
	if mouse_event.button_index != MOUSE_BUTTON_LEFT:
		return
	if not is_inside_window_world(local):
		return
	get_viewport().set_input_as_handled()
	cell_clicked.emit(world_to_cell(local))


## Whether a mouse event lands on the board area (not on a panel next to it).
func _event_in_area(event: InputEventMouse) -> bool:
	var area_pos: Vector2 = position + (make_input_local(event) as InputEventMouse).position * scale.x
	return Rect2(Vector2.ZERO, _fit_area).has_point(area_pos)


## Converts viewport (window) pixels to board-area pixels, for drag deltas.
func _screen_to_area_factor() -> float:
	var parent_item: CanvasItem = get_parent() as CanvasItem
	if parent_item == null:
		return 1.0
	var t: Transform2D = parent_item.get_global_transform_with_canvas()
	return 1.0 / maxf(0.0001, t.get_scale().x)


func _key_pan(delta: float) -> void:
	if zoom <= 1.0:
		return
	var dir: Vector2 = Vector2.ZERO
	if Input.is_key_pressed(KEY_A) or Input.is_key_pressed(KEY_LEFT):
		dir.x -= 1.0
	if Input.is_key_pressed(KEY_D) or Input.is_key_pressed(KEY_RIGHT):
		dir.x += 1.0
	if Input.is_key_pressed(KEY_W) or Input.is_key_pressed(KEY_UP):
		dir.y -= 1.0
	if Input.is_key_pressed(KEY_S) or Input.is_key_pressed(KEY_DOWN):
		dir.y += 1.0
	if dir != Vector2.ZERO:
		pan_by(-dir.normalized() * KEY_PAN_SPEED * delta)


func _process(delta: float) -> void:
	_key_pan(delta)
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
	if overlay != null:
		overlay.queue_redraw()


# --- Rendering -------------------------------------------------------------------

## Build-mode hover: the tile highlight and, on a valid tile, the range the new tower
## would cover.
func _draw_overlay() -> void:
	if not _build_mode or _hover_cell == NO_CELL:
		return
	var rect: Rect2 = Rect2(Vector2(_hover_cell) * GameConfig.CELL_SIZE, Vector2.ONE * GameConfig.CELL_SIZE)
	var color: Color = COLOR_HOVER_VALID if _hover_valid else COLOR_HOVER_INVALID
	overlay.draw_rect(rect.grow(-1.0), Color(color, 0.25))
	overlay.draw_rect(rect.grow(-1.0), Color(color, 0.95), false, 2.0)
	if _hover_valid:
		var center: Vector2 = cell_to_world(_hover_cell)
		overlay.draw_circle(center, _preview_range, Color(1, 1, 1, 0.08))
		var segments: int = 48
		for i in segments:
			if i % 2 == 0:
				overlay.draw_arc(center, _preview_range, TAU * i / segments, TAU * (i + 1) / segments, 4, Color(1, 1, 1, 0.75), 1.5)
