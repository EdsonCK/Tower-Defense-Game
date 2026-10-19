class_name WindowFit
extends Node
## Keeps the OS window fully visible and centered on its screen.
## The game renders at a fixed 1600x900 logical resolution; project settings use the
## canvas_items stretch mode with "keep" aspect, so any window size shows the whole
## game scaled and centered (letterboxed if the window is not 16:9).
## This node only manages the window itself: it fits it to the usable screen area on
## startup, re-fits and re-centers it after the player resizes it, and toggles
## fullscreen with F11.

const BASE_SIZE: Vector2i = Vector2i(1600, 900)
const MIN_SIZE: Vector2i = Vector2i(800, 450)
## Fraction of the usable screen area the window may occupy (leaves room for borders).
const SCREEN_FILL: float = 0.92
## Wait for the user to stop dragging before re-centering.
const RESIZE_SETTLE_SECONDS: float = 0.25

var _settle_timer: Timer


func _ready() -> void:
	if not _can_manage_window():
		return
	_settle_timer = Timer.new()
	_settle_timer.one_shot = true
	_settle_timer.wait_time = RESIZE_SETTLE_SECONDS
	_settle_timer.timeout.connect(_on_resize_settled)
	add_child(_settle_timer)
	get_window().min_size = MIN_SIZE
	get_window().size_changed.connect(_on_window_size_changed)
	fit_to_screen()


func _unhandled_input(event: InputEvent) -> void:
	var key: InputEventKey = event as InputEventKey
	if key != null and key.pressed and not key.echo and key.keycode == KEY_F11 and _can_manage_window():
		get_viewport().set_input_as_handled()
		toggle_fullscreen()


## Sizes the window to the largest 16:9 size (up to 1600x900) that fits the usable
## screen area, then centers it.
func fit_to_screen() -> void:
	if not _is_windowed():
		return
	var target: Vector2i = fitted_size(_max_window_size())
	if get_window().size != target:
		get_window().size = target
	center_on_screen()


## Largest 16:9 size up to BASE_SIZE that fits in `max_size` (never below MIN_SIZE).
static func fitted_size(max_size: Vector2i) -> Vector2i:
	var scale: float = minf(1.0, minf(float(max_size.x) / BASE_SIZE.x, float(max_size.y) / BASE_SIZE.y))
	return Vector2i(floori(BASE_SIZE.x * scale), floori(BASE_SIZE.y * scale)).max(MIN_SIZE)


## Shrinks the window if it no longer fits, then centers it on its current screen.
func clamp_and_center() -> void:
	if not _is_windowed():
		return
	var max_size: Vector2i = _max_window_size()
	var size: Vector2i = get_window().size
	var clamped: Vector2i = size.min(max_size).max(MIN_SIZE)
	if clamped != size:
		get_window().size = clamped
	center_on_screen()


func center_on_screen() -> void:
	var usable: Rect2i = _usable_rect()
	var window: Window = get_window()
	var outer: Vector2i = window.get_size_with_decorations().max(window.size)
	var decoration_offset: Vector2i = window.position - window.get_position_with_decorations()
	var outer_position: Vector2i = usable.position + (usable.size - outer) / 2
	window.position = outer_position.max(usable.position) + decoration_offset


func toggle_fullscreen() -> void:
	if get_window().mode == Window.MODE_FULLSCREEN:
		get_window().mode = Window.MODE_WINDOWED
		fit_to_screen()
	else:
		get_window().mode = Window.MODE_FULLSCREEN


func _on_window_size_changed() -> void:
	_settle_timer.start()


func _on_resize_settled() -> void:
	clamp_and_center()


func _max_window_size() -> Vector2i:
	var usable: Vector2i = _usable_rect().size
	var window: Window = get_window()
	var decorations: Vector2i = (window.get_size_with_decorations() - window.size).max(Vector2i.ZERO)
	return Vector2i(floori(usable.x * SCREEN_FILL), floori(usable.y * SCREEN_FILL)) - decorations


func _usable_rect() -> Rect2i:
	return DisplayServer.screen_get_usable_rect(get_window().current_screen)


func _is_windowed() -> bool:
	return get_window().mode == Window.MODE_WINDOWED


## No real OS window exists in headless runs or when the game is embedded in the editor.
func _can_manage_window() -> bool:
	return DisplayServer.get_name() != "headless" and not Engine.is_embedded_in_editor()
