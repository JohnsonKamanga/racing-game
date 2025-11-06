extends Node


func _ready():
	var car_scene = load(Global.selected_character_path)
	var track_scene = load(Global.selected_track_path)
	
	var car_instance = car_scene.instantiate()
	var track_instance = track_scene.instantiate()
	
	#place player's car on the start of the race track
	car_instance.position = track_instance.get_node("StartPosition").position
	
	#HUD in every car instance is hidden on purpose
	car_instance.get_node("HUD").show()
	
	add_child(track_instance)
	add_child(car_instance)
	
