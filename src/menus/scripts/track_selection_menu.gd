extends CanvasLayer

signal track_selected

func _on_track_one_button_pressed() -> void:
	Global.selected_track_path = "res://src/tracks/track_1.tscn"
	track_selected.emit()
