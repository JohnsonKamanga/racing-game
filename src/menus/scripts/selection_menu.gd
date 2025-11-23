extends Control

signal game_ready

func _ready():
	pass

func display_car_stats(car_scene_path: String):
	if car_scene_path == "":
		return
	
	var car_scene = load(car_scene_path)
	var car_instance = car_scene.instantiate()
	var stats = car_instance.get_display_stats()
	
	# Update UI labels
	$ColorRect/SelectedCarDetails/ColorRect/CarName.text = stats.name
	$ColorRect/SelectedCarDetails/ColorRect/MaxSpeed.text = str(stats.speed)
	$ColorRect/SelectedCarDetails/ColorRect/Acceleration.text = str(stats.acceleration)
	
	#make start button visible
	if Global.selected_character_path != "" and Global.selected_track_path != "" :
		$ColorRect/SelectedCarDetails/ColorRect/StartGameButton.show()
	
	car_instance.queue_free()

func _on_suv_button_pressed() -> void:
	Global.selected_character_path = "res://src/cars/suv.tscn"
	display_car_stats(Global.selected_character_path)

func _on_firetruck_button_pressed() -> void:
	Global.selected_character_path = "res://src/cars/fire_truck.tscn"
	display_car_stats(Global.selected_character_path)


func _on_police_car_button_pressed() -> void:
	Global.selected_character_path = "res://src/cars/police.tscn"
	display_car_stats(Global.selected_character_path)


func _on_garage_truck_button_pressed() -> void:
	Global.selected_character_path = "res://src/cars/garage_truck.tscn"
	display_car_stats(Global.selected_character_path)


func _on_sedan_button_pressed() -> void:
	Global.selected_character_path = "res://src/cars/sedan.tscn"
	display_car_stats(Global.selected_character_path)


func _on_race_car_button_pressed() -> void:
	Global.selected_character_path = "res://src/cars/race.tscn"
	display_car_stats(Global.selected_character_path)


func _on_track_selection_menu_track_selected() -> void:
	display_car_stats(Global.selected_character_path)


func _on_selected_car_details_details_ready() -> void:
	game_ready.emit()
