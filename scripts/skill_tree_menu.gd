class_name SkillTreeMenu
extends Control

signal purchase_requested(id: String)
signal close_requested
signal retry_requested

var buy_buttons: Dictionary = {}
var _children: Dictionary = {}
var _weights: Dictionary = {}
var _profile: Progression
var _hovered_id := ""

@onready var balance: Label = $Panel/Margin/Items/Balance
@onready var message: Label = $Panel/Margin/Items/Message
@onready var retry_button: Button = $Panel/Margin/Items/Footer/Retry
@onready var scroll: ScrollContainer = $Panel/Margin/Items/Scroll
@onready var graph: ResearchGraph = $Panel/Margin/Items/Scroll/Graph
@onready var hover_card: PanelContainer = $HoverCard
@onready var hover_text: Label = $HoverCard/Info


func _ready() -> void:
	theme = UIStyle.make_theme()
	for id in SkillCatalog.IDS:
		_children[id] = []
	for id in SkillCatalog.IDS:
		var parent: String = SkillCatalog.NODES[id].requires
		if not parent.is_empty():
			_children[parent].append(id)
	_measure("tesla")
	_place("tesla", 0.0, 0)
	var max_y := 0.0
	for id in SkillCatalog.IDS:
		var button := ResearchIcon.new()
		button.name = id
		button.skill_id = id
		button.position = graph.positions[id] - Vector2(28, 28)
		button.size = Vector2(56, 56)
		button.pressed.connect(func() -> void: purchase_requested.emit(id))
		button.mouse_entered.connect(func() -> void: _show_info(id))
		button.mouse_exited.connect(func() -> void: _hide_info(id))
		button.focus_entered.connect(func() -> void: _show_info(id))
		button.focus_exited.connect(func() -> void: _hide_info(id))
		graph.add_child(button)
		buy_buttons[id] = button
		max_y = maxf(max_y, button.position.y + 100)
	graph.custom_minimum_size = Vector2(maxf(1260, float(_weights.tesla) * 70 + 64), max_y)
	var focus_order: Array[Control] = []
	for id in SkillCatalog.IDS:
		focus_order.append(buy_buttons[id])
	focus_order.append($Panel/Margin/Items/Footer/Close)
	for i in range(focus_order.size()):
		focus_order[i].focus_next = focus_order[i].get_path_to(focus_order[(i + 1) % focus_order.size()])
		focus_order[i].focus_previous = focus_order[i].get_path_to(focus_order[(i - 1 + focus_order.size()) % focus_order.size()])
	$Panel/Margin/Items/Footer/Close.pressed.connect(func() -> void: close_requested.emit())
	retry_button.pressed.connect(func() -> void: retry_requested.emit())
	visibility_changed.connect(func() -> void:
		if not visible:
			_hovered_id = ""
			hover_card.hide()
	)


func _measure(id: String) -> int:
	var weight := 0
	for child in _children[id]:
		weight += _measure(child)
	_weights[id] = maxi(weight, 1)
	return int(_weights[id])


func _place(id: String, left: float, depth: int) -> void:
	graph.positions[id] = Vector2(32 + (left + float(_weights[id]) / 2) * 70, 55 + depth * 134)
	for child in _children[id]:
		_place(child, left, depth + 1)
		left += float(_weights[child])


func refresh(profile: Progression) -> void:
	_profile = profile
	balance.text = "THE ARCHIVE                                         ◇ %d diamonds" % profile.diamonds
	message.text = "Begin with Tesla • Follow the branches • Hover an icon for details • Click to research"
	if not profile.save_error.is_empty():
		message.text = profile.save_error
	retry_button.visible = not profile.save_error.is_empty()
	graph.owned.assign(profile.unlocked)
	graph.queue_redraw()
	for id in SkillCatalog.IDS:
		var icon := buy_buttons[id] as ResearchIcon
		icon.owned = profile.has_skill(id)
		icon.available = profile.purchase_error(id).is_empty()
		# Keep locked icons hoverable/focusable; purchase() validates every click.
		icon.accent = _accent(id)
		icon.queue_redraw()
	if not _hovered_id.is_empty():
		_show_info(_hovered_id)


func _accent(id: String) -> Color:
	var branch: String = SkillCatalog.NODES[id].branch
	return {"Basic ballistics": Color("e2bd79"), "Tesla research": Color("bc9be5"), "Siegecraft": Color("f7a16d"), "Cryomancy": Color("97ddf2"), "Artillery": Color("c2d29e"), "Economy": Color("e9cd80"), "Disruption": Color("86bfa4")}.get(branch, Color("c0a8ec"))


func _show_info(id: String) -> void:
	if _profile == null or not visible:
		return
	_hovered_id = id
	var data: Dictionary = SkillCatalog.NODES[id]
	var requirement := "First unlock" if str(data.requires).is_empty() else "Requires: " + str(SkillCatalog.NODES[data.requires].title)
	var state := "Researched" if _profile.has_skill(id) else _profile.purchase_error(id)
	if state.is_empty():
		state = "Click to purchase"
	hover_text.text = "%s\n◇ %d diamonds  •  %s\n\n%s\n\n%s" % [data.title, data.cost, requirement, data.effect, state]
	hover_card.show()
	hover_card.reset_size()
	_position_info()
	call_deferred("_position_info") # Re-clamp after wrapped label/container layout settles.


func _position_info() -> void:
	if _hovered_id.is_empty() or not hover_card.visible:
		return
	var point := (buy_buttons[_hovered_id] as Control).get_global_rect().get_center() + Vector2(35, -35)
	hover_card.position = Vector2(clampf(point.x, 132, 1468 - hover_card.size.x), clampf(point.y, 80, 800 - hover_card.size.y))


func _hide_info(id: String) -> void:
	if _hovered_id == id:
		_hovered_id = ""
		hover_card.hide()
