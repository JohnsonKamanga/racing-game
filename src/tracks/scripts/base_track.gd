extends StaticBody3D

var checkpoints : Array[Area3D] = []

func _ready() -> void:
	var ch = get_tree().get_nodes_in_group("checkpoints") as Array[Checkpoint]
	
	for i in range(ch.size()):
		var c = ch[i]
		
		checkpoints.append(c)
		c.checkpoint_passed.connect(_on_checkpoint_passed)
	

func _on_checkpoint_passed(body: CharacterBody3D):
	if not body.is_in_group("vehicle"): 
		return
	
	var car = body as BaseCar
	if (car.get_distance_traveled() / (car.lap + 1)) >= 0.95 * get_track_length():
		car.next_lap()
		 
		if car.lap >= Global._number_of_laps:
			car.finished = true
		else:
			car.get_node("HUD/Lap").text = str(car.lap + 1)

func get_track_length():
	return $Node3D/Path3D.curve.get_baked_length()


func _on_finish_line_checkpoint_passed(body) -> void:
	body.lap +=1
	body.get_node("HUD/Lap").text = str(body.lap) 
