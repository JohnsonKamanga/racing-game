extends Node


func _on_selection_menu_game_ready() -> void:
	get_tree().change_scene_to_file("res://src/main_game_scene.tscn")
