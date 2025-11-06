extends CanvasLayer
signal details_ready

func _on_start_game_button_pressed() -> void:
	details_ready.emit()
