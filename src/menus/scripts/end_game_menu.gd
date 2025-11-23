extends CanvasLayer

func _on_main_menu_button_pressed() -> void:
	Global.reset_selected_paths()
	get_tree().change_scene_to_file("res://main.tscn")


func _on_restart_button_pressed() -> void:
	get_tree().change_scene_to_file("res://src/main_game_scene.tscn")
