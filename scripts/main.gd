extends Node2D

@onready var hud: GameHUD = $HUD/UILayout


func _ready() -> void:
	hud.display(GameConfig.STARTING_CURRENCY, GameConfig.STARTING_LIVES, 0, "READY", false, true, false)
	hud.show_message("Create a maze of towers. Keep a route open from the entrance to the exit.")
