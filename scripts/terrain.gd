class_name Terrain
extends Node2D
## Draws the ground, path, gate plaza, lakes, cloud shadows, build grid and fog in one
## shader pass (shaders/terrain.gdshader). The board feeds it a one-texel-per-cell map
## texture and the current biome's palette; biome changes cross-fade the colors.

const SHADER: Shader = preload("res://shaders/terrain.gdshader")
const FADE_SECONDS: float = 1.4
const COLOR_PARAMS: Dictionary = {
	# shader uniform: biome key
	"ground_a": "ground", "ground_b": "ground_alt", "detail_a": "detail", "detail_b": "detail2",
	"water_deep": "water_deep", "water_shallow": "water_shallow", "shore_col": "shore", "fog_col": "fog",
}

var _material: ShaderMaterial
var _image: Image
var _texture: ImageTexture
var _from: Dictionary = {}
var _to: Dictionary = {}
var _grid_tween: Tween
var _fade_tween: Tween
var _grid_shown: float = 0.0   # target (0 or 1)
var _grid_value: float = 0.0   # current, while fading
var _window: Rect2 = Rect2()
var _reveal_tween: Tween

const REVEAL_SECONDS: float = 0.9


func _init() -> void:
	_material = ShaderMaterial.new()
	_material.shader = SHADER
	material = _material
	_image = Image.create(GameConfig.GRID_COLUMNS, GameConfig.GRID_ROWS, false, Image.FORMAT_RGBA8)
	_texture = ImageTexture.create_from_image(_image)
	_material.set_shader_parameter("map_tex", _texture)
	_material.set_shader_parameter("grid_size", Vector2(GameConfig.GRID_COLUMNS, GameConfig.GRID_ROWS))
	_material.set_shader_parameter("cell_size", float(GameConfig.CELL_SIZE))
	_material.set_shader_parameter("show_grid", 0.0)
	for pair: Array in [["path_col", Biomes.PATH_COLOR], ["path_edge", Biomes.PATH_EDGE], ["path_rut", Biomes.PATH_RUT],
			["pebble_col", Biomes.PATH_PEBBLE], ["cobble_col", Biomes.COBBLE], ["cobble_gap", Biomes.COBBLE_GAP]]:
		_material.set_shader_parameter(pair[0], _vec3(pair[1]))


## Rebuilds the per-cell map texture (path inside the window, lakes, the cobbled road
## near the gate) and places the gate plaza.
func update_map(layout: MapLayout, half_width: int, window_world: Rect2) -> void:
	var exit: Vector2i = layout.exit
	for y in GameConfig.GRID_ROWS:
		for x in GameConfig.GRID_COLUMNS:
			var cell: Vector2i = Vector2i(x, y)
			var path: float = 1.0 if layout.is_path(cell) and MapLayout.in_window(cell, half_width) else 0.0
			var lake: float = 1.0 if layout.is_feature(cell) else 0.0
			var cobble: float = 0.0
			if path > 0.0:
				cobble = clampf(1.0 - (float(layout.distance.get(cell, 99)) - 2.0) * 0.3, 0.0, 1.0)
			_image.set_pixel(x, y, Color(path, lake, cobble, 1.0))
	_texture.update(_image)
	_material.set_shader_parameter("gate_pos", Board.cell_to_world(exit))
	# When the map grows, the fog rolls back over REVEAL_SECONDS instead of snapping.
	if _reveal_tween != null:
		_reveal_tween.kill()
	var grows: bool = _window.has_area() and window_world.encloses(_window) and window_world != _window
	if grows and is_inside_tree():
		_reveal_tween = create_tween()
		_reveal_tween.tween_method(_set_window, _window, window_world, REVEAL_SECONDS).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	else:
		_set_window(window_world)
	_window = window_world
	queue_redraw()


func _set_window(rect: Rect2) -> void:
	_material.set_shader_parameter("window_rect", Vector4(rect.position.x, rect.position.y, rect.size.x, rect.size.y))


## Applies a biome's palette; with `animate` the colors cross-fade over FADE_SECONDS.
func apply_biome(index: int, animate: bool) -> void:
	var def: Dictionary = Biomes.get_def(maxi(index, 0))
	_to = {}
	for param: String in COLOR_PARAMS:
		_to[param] = def[COLOR_PARAMS[param]] as Color
	_material.set_shader_parameter("style", int(def["style"]))
	_material.set_shader_parameter("water_style", int(def["water_style"]))
	_material.set_shader_parameter("clouds", float(def["clouds"]))
	_material.set_shader_parameter("grid_col", def["grid"] as Color)
	if _fade_tween != null:
		_fade_tween.kill()
	if not animate or _from.is_empty() or not is_inside_tree():
		_from = _to.duplicate()
		_blend(1.0)
		return
	_fade_tween = create_tween()
	_fade_tween.tween_method(_blend, 0.0, 1.0, FADE_SECONDS)


func _blend(t: float) -> void:
	var current: Dictionary = {}
	for param: String in _to:
		var c: Color = (_from.get(param, _to[param]) as Color).lerp(_to[param], t)
		current[param] = c
		_material.set_shader_parameter(param, _vec3(c))
	if t >= 1.0:
		_from = current


## Fades the build grid in or out.
func set_grid_visible(visible_now: bool) -> void:
	var target: float = 1.0 if visible_now else 0.0
	if is_equal_approx(target, _grid_shown):
		return
	_grid_shown = target
	if _grid_tween != null:
		_grid_tween.kill()
	if not is_inside_tree():
		_set_grid_value(target)
		return
	_grid_tween = create_tween()
	_grid_tween.tween_method(_set_grid_value, _grid_value, target, 0.15)


func _set_grid_value(v: float) -> void:
	_grid_value = v
	_material.set_shader_parameter("show_grid", v)


func grid_visible() -> bool:
	return _grid_shown > 0.5


## The per-cell map the shader samples (see update_map).
func map_image() -> Image:
	return _image


func shader_param(name: String) -> Variant:
	return _material.get_shader_parameter(name)


func _draw() -> void:
	# One big quad over the whole grid plus a wide fog margin; the shader does the rest.
	var cs: float = GameConfig.CELL_SIZE
	var margin: float = cs * 40.0
	draw_rect(Rect2(-margin, -margin, GameConfig.GRID_COLUMNS * cs + margin * 2.0, GameConfig.GRID_ROWS * cs + margin * 2.0), Color.WHITE)


static func _vec3(c: Color) -> Vector3:
	return Vector3(c.r, c.g, c.b)
