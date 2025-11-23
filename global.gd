extends Node

enum Game_States {
	RUNNING, PAUSED
} 

var game_state: Game_States

var selected_character_path = ""
var selected_track_path = ""
var number_of_laps = 3
var players : Array[BaseCar]
var sorted_players : Array[BaseCar]


func reset_selected_paths():
	selected_character_path = ""
	selected_track_path = ""
