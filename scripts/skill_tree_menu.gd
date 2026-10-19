class_name SkillTreeMenu
extends Control

signal purchase_requested(id: String)
signal close_requested
signal retry_requested

var buy_buttons: Dictionary = {}
var _requirements: Dictionary = {}
var _cards: Dictionary = {}
var _descriptions: Dictionary = {}

@onready var balance: Label = $Panel/Margin/Items/Balance
@onready var message: Label = $Panel/Margin/Items/Message
@onready var retry_button: Button = $Panel/Margin/Items/Footer/Retry
@onready var scroll: ScrollContainer = $Panel/Margin/Items/Scroll


func _ready() -> void:
	theme = UIStyle.make_theme()
	var columns: Dictionary = {}
	for branch in ["Basic ballistics", "Tesla research", "Economy", "Disruption"]:
		var column := VBoxContainer.new()
		column.custom_minimum_size.x = 288
		column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		column.add_theme_constant_override("separation", 12)
		$Panel/Margin/Items/Scroll/Branches.add_child(column)
		columns[branch] = column
		var heading := Label.new()
		heading.text = branch.to_upper()
		heading.add_theme_color_override("font_color", UIStyle.CYAN)
		heading.add_theme_font_size_override("font_size", 18)
		column.add_child(heading)
	for id in SkillCatalog.IDS:
		var node: Dictionary = SkillCatalog.NODES[id]
		var parent: Node = $Panel/Margin/Items/Root if id == "tesla" else columns[node.branch]
		_create_card(id, parent)
	$Panel/Margin/Items/Footer/Close.pressed.connect(func() -> void: close_requested.emit())
	retry_button.pressed.connect(func() -> void: retry_requested.emit())


func _create_card(id: String, parent: Node) -> void:
	var data: Dictionary = SkillCatalog.NODES[id]
	var card := PanelContainer.new()
	card.name = id
	card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	parent.add_child(card)
	_cards[id] = card
	var items := VBoxContainer.new()
	items.add_theme_constant_override("separation", 6)
	card.add_child(items)
	var title := Label.new()
	title.text = data.title
	title.add_theme_font_size_override("font_size", 18)
	items.add_child(title)
	var requirement := Label.new()
	requirement.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	requirement.add_theme_font_size_override("font_size", 14)
	items.add_child(requirement)
	_requirements[id] = requirement
	var description := Label.new()
	description.text = data.effect
	description.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	description.custom_minimum_size.y = 42 if id != "tesla" else 0
	description.add_theme_font_size_override("font_size", 15)
	description.add_theme_color_override("font_color", UIStyle.MUTED)
	items.add_child(description)
	_descriptions[id] = description
	var button := Button.new()
	button.custom_minimum_size.y = 36
	button.pressed.connect(func() -> void: purchase_requested.emit(id))
	items.add_child(button)
	buy_buttons[id] = button


func refresh(profile: Progression) -> void:
	balance.text = "RESEARCH LAB                                  ◇ %d diamonds" % profile.diamonds
	message.text = "Permanent across runs • Earn 1 diamond per cleared wave • Unlock Tesla to open four research branches."
	if not profile.save_error.is_empty():
		message.text = profile.save_error
	retry_button.visible = not profile.save_error.is_empty()
	for id in SkillCatalog.IDS:
		var node: Dictionary = SkillCatalog.NODES[id]
		var button := buy_buttons[id] as Button
		var owned := profile.has_skill(id)
		var error := profile.purchase_error(id)
		var available := error.is_empty()
		button.text = "✓ RESEARCHED" if owned else "Unlock  ◇ %d" % int(node.cost)
		button.disabled = not available
		button.tooltip_text = error
		var requirement := _requirements[id] as Label
		requirement.text = "START HERE • First unlock" if node.requires.is_empty() else "↳ " + str(SkillCatalog.NODES[node.requires].title)
		requirement.add_theme_color_override("font_color", UIStyle.CYAN if owned or available else UIStyle.MUTED)
		(_cards[id] as PanelContainer).add_theme_stylebox_override("panel", UIStyle.box(Color("192c3c") if owned else UIStyle.PANEL, UIStyle.CYAN if available else UIStyle.LINE))
