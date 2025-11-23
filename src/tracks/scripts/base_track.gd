extends StaticBody3D

var checkpoints : Array[Area3D] = []
@onready var p: Array[BaseCar] = Global.players

func _ready() -> void:
	var ch = get_tree().get_nodes_in_group("checkpoints") as Array[Checkpoint]
	
	for i in range(ch.size()):
		var c = ch[i]
		
		checkpoints.append(c)
		c.checkpoint_passed.connect(_on_checkpoint_passed)
	

func _process(_delta):
	if Global.game_state == Global.Game_States.RUNNING :
		p.sort_custom(sort_players)
		
		for i in range(p.size()):
			p[i].set_car_position(i + 1)
			p[i].update_position(i + 1)
		
		Global.sorted_players = p

func calculate_average_speed(c: BaseCar):
	if c.total_time == 0.0:
		return 0.0
	
	return (c.get_distance_traveled() / (c.lap + 1))


func sort_players(a: BaseCar, b: BaseCar):
	# Compare laps first
	if a.lap != b.lap:
		return a.lap > b.lap
	
	# Then checkpoints passed
	if a.checkpoints_passed != b.checkpoints_passed:
		return a.checkpoints_passed > b.checkpoints_passed
	
	# Finally, distance to next checkpoint (closer = ahead)
	var dist_a = get_distance_along_path_to_checkpoint(a)
	var dist_b = get_distance_along_path_to_checkpoint(b)
	return dist_a < dist_b


func _on_checkpoint_passed(body: CharacterBody3D):
	if not body.is_in_group("vehicle"): 
		return
	
	var car = body as BaseCar
	car.checkpoints_passed +=1
	if (car.get_distance_traveled() / (car.lap + 1)) >= 0.95 * get_track_length():
		car.next_lap()
		 
		if car.lap >= Global.number_of_laps:
			car.finished = true
		elif car.HUD != null:
			car.get_node("HUD/Lap").text = str(car.lap + 1)

func get_track_length():
	return $Node3D/Path3D.curve.get_baked_length()

func get_next_checkpoint_position(car: BaseCar) -> Vector3:
	if checkpoints.is_empty():
		return car.global_position  # Fallback if no checkpoints
	
	# Calculate which checkpoint the car should be heading toward
	var next_checkpoint_index = (car.checkpoints_passed + 1) % checkpoints.size()
	
	# Return the global position of that checkpoint
	return checkpoints[next_checkpoint_index].global_position

func get_distance_along_path_to_checkpoint(car: BaseCar) -> float:
	if checkpoints.is_empty():
		return 0.0
	
	var path = $Node3D/Path3D.curve
	var checkpoint_pos = get_next_checkpoint_position(car)
	
	# Get closest point on path for car and checkpoint
	var car_path_offset = path.get_closest_offset(car.global_position)
	var checkpoint_path_offset = path.get_closest_offset(checkpoint_pos)
	
	# Calculate distance along the path
	var distance = checkpoint_path_offset - car_path_offset
	
	# Handle wraparound (if checkpoint is "behind" on the path but actually ahead)
	if distance < 0:
		distance += path.get_baked_length()
	
	return distance
