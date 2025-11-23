extends Control

signal track_selected

func _on_track_one_button_pressed() -> void:
	Global.selected_track_path = "res://src/tracks/track_three.tscn"
	track_selected.emit()


func _on_track_two_button_pressed() -> void:
	Global.selected_track_path = "res://src/tracks/track_two.tscn"
	track_selected.emit()
