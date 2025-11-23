extends CanvasLayer

signal pause_game

func _on_pause_button_pressed() -> void:
	Global.game_state = Global.Game_States.PAUSED
	pause_game.emit()
