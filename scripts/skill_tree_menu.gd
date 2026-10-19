class_name SkillTreeMenu
extends Control

signal purchase_requested(id: String)
signal close_requested
signal retry_requested

@onready var balance: Label = $Panel/Margin/Items/Balance
@onready var message: Label = $Panel/Margin/Items/Message
@onready var retry_button: Button = $Panel/Margin/Items/Footer/Retry


func _ready() -> void:
	for id in SkillCatalog.IDS:
		get_node("Panel/Margin/Items/Skills/" + id + "/Buy").pressed.connect(func() -> void: purchase_requested.emit(id))
	$Panel/Margin/Items/Footer/Close.pressed.connect(func() -> void: close_requested.emit())
	retry_button.pressed.connect(func() -> void: retry_requested.emit())


func refresh(profile: Progression) -> void:
	balance.text = "Permanent skills • Diamonds: %d" % profile.diamonds
	message.text = "Earn 1 diamond per completed wave. Unlock Tesla first. Your skills and diamonds survive Restart."
	if not profile.save_error.is_empty():
		message.text = profile.save_error
	retry_button.visible = not profile.save_error.is_empty()
	for id in SkillCatalog.IDS:
		var node: Dictionary = SkillCatalog.NODES[id]
		var button := get_node("Panel/Margin/Items/Skills/" + id + "/Buy") as Button
		var description := get_node("Panel/Margin/Items/Skills/" + id + "/Description") as Label
		button.text = str(node.title) + (" • Unlocked" if profile.has_skill(id) else " • %d diamonds" % int(node.cost))
		button.disabled = not profile.purchase_error(id).is_empty()
		var requirement := "Start here" if node.requires.is_empty() else "Requires: " + str(SkillCatalog.NODES[node.requires].title)
		description.text = requirement + "\n" + str(node.effect)
