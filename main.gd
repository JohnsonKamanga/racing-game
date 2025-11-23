extends CanvasLayer


func _on_start_button_pressed() -> void:
	print_debug("start button pressed")
	get_tree().change_scene_to_file("res://src/menus/main_menu.tscn")
