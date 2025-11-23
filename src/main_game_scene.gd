extends Node

var running_music_positon = 0.0

func _ready():
	var car_scene = load(Global.selected_character_path)
	var ai_car_scene = load("res://src/cars/suv.tscn")
	var track_scene = load(Global.selected_track_path)
	
	var car_instance = car_scene.instantiate() as BaseCar
	var ai_car_instance1 = ai_car_scene.instantiate() as BaseCar
	var ai_car_instance2 = ai_car_scene.instantiate() as BaseCar
	var ai_car_instance3 = ai_car_scene.instantiate() as BaseCar
	var track_instance = track_scene.instantiate()
	
	#place player's car on the start of the race track
	car_instance.position = track_instance.get_node("StartPosition").position
	ai_car_instance1.position = track_instance.get_node("StartPosition2").position
	ai_car_instance2.position = track_instance.get_node("StartPosition3").position
	ai_car_instance3.position = track_instance.get_node("StartPosition4").position
	
	#HUD in every car instance is hidden on purpose
	var hud_scene = load("res://src/menus/hud.tscn")
	var hud = hud_scene.instantiate()
	
	car_instance.set_hud(hud)
	var human_player = HumanPlayer.new()
	var ai_player1 = AIPlayer.new()
	var ai_player2 = AIPlayer.new()
	var ai_player3 = AIPlayer.new()
	human_player.set_car(car_instance)
	car_instance.pause_game.connect(_on_pause_game)
	Global.game_state = Global.Game_States.RUNNING
	ai_player1.set_car(ai_car_instance1)
	ai_player2.set_car(ai_car_instance2)
	ai_player3.set_car(ai_car_instance3)
	Global.players = [car_instance, ai_car_instance1, ai_car_instance2, ai_car_instance3]
	
	human_player.race_completed.connect(_on_race_completed)
	add_child(track_instance)
	add_child(human_player)
	add_child(ai_player1)
	add_child(ai_player2)
	add_child(ai_player3)
	
	$RunningMusicPlayer.play()


func reset():
	pass

func _on_pause_game():
	$PauseMenu.visible = true
	running_music_positon = $RunningMusicPlayer.get_playback_position()
	$RunningMusicPlayer.stop()
	$PausedMusicPlayer.play()

func _on_race_completed():
	Global.game_state = Global.Game_States.PAUSED
	
	var end_game_menu_scene = load("res://src/menus/end_game_menu.tscn")
	var end_game_menu_instance = end_game_menu_scene.instantiate()
	
	var t1 = Global.sorted_players[0].calculate_time(Global.sorted_players[0].total_time)
	var time_str = '%02d:%02d' % [t1.min, t1.sec]
	var base = end_game_menu_instance.get_node("Control/ColorRect/ColorRect/RaceTimeLabel").text
	end_game_menu_instance.get_node("Control/ColorRect/ColorRect/RaceTimeLabel").text = base + time_str
	
	for i in range(Global.sorted_players.size()):
		var pos = Global.sorted_players[i].car_position
		var t = Global.sorted_players[i].calculate_time(Global.sorted_players[i].total_time)
		var car_name_and_pos = str(pos) + ". " + Global.sorted_players[i].name
		var time_string = '%02d:%02d' % [t.min, t.sec]
		
		
		if pos == 1:
			end_game_menu_instance.get_node("Control/ColorRect/ColorRect/PlayerSection/FirstPlaceLabel").text = car_name_and_pos
			
			end_game_menu_instance.get_node("Control/ColorRect/ColorRect/TimeSection/FirstPlaceTimeLabel").text = time_string
		elif pos == 2:
			
			end_game_menu_instance.get_node("Control/ColorRect/ColorRect/PlayerSection/SecondPlaceLabel").text = car_name_and_pos
			
			end_game_menu_instance.get_node("Control/ColorRect/ColorRect/TimeSection/SecondPlaceTimeLabel").text = time_string
		elif pos == 3:
			end_game_menu_instance.get_node("Control/ColorRect/ColorRect/PlayerSection/ThirdPlaceLabel").text = car_name_and_pos
			
			end_game_menu_instance.get_node("Control/ColorRect/ColorRect/TimeSection/ThirdPlaceTimeLabel").text = time_string
		elif pos == 4:
			end_game_menu_instance.get_node("Control/ColorRect/ColorRect/PlayerSection/FourthPlaceLabel").text = car_name_and_pos
			
			end_game_menu_instance.get_node("Control/ColorRect/ColorRect/TimeSection/FourthPlaceTimeLabel").text = time_string
		else:
			continue
	
	add_child(end_game_menu_instance)
	$RunningMusicPlayer.stop()
	$PausedMusicPlayer.play()


func _on_pause_menu_resume_game() -> void:
	$PausedMusicPlayer.stop()
	$RunningMusicPlayer.play(running_music_positon)
	
