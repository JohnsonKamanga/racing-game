class_name HumanPlayer extends Player

signal race_completed

func get_input( _delat: float = 1.0):
	var turn = Input.get_action_strength("steer_left")
	turn -= Input.get_action_strength("steer_right")
	car.steer_angle = turn * deg_to_rad(car.steering_limit)
	#front and back wheels swapped naming - front refers to back and back refers to front
	car.get_node("wheel-back-right").rotation.y = car.steer_angle * 2
	car.get_node("wheel-back-left").rotation.y = car.steer_angle * 2
	car.acceleration = Vector3.ZERO
	
	if Input.is_action_pressed("accelerate"):
		car.acceleration = -car.transform.basis.z * car.engine_power
	
	if Input.is_action_pressed("brake"):
		car.acceleration = -car.transform.basis.z * car.braking
		

func _physics_process(delta: float) -> void:
	super(delta)
	
	if car.finished:
		race_completed.emit()
		
