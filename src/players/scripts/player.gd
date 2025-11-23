@abstract
class_name Player extends Node

@export var car : BaseCar

func set_car(_car: BaseCar):
	if car: # if it already attached
		remove_child(car) # Remove it else 2 vehicles will be there in level
	
	self.car = _car
	self.add_child(_car)
	
func get_car():
	return car

@abstract
func get_input(delta: float = 1.0)

func _physics_process(delta: float) -> void:
	
	if Global.game_state == Global.Game_States.RUNNING :
		
		if car.is_on_floor() and not car.finished:
			get_input(delta)
			car.apply_friction(delta)
			car.calculate_steering(delta)
		
		car.update_distance_traveled()
			
		if not car.raycast.is_colliding():
			car.moving_right = not car.moving_right
			# Reverse the velocity or move direction based on your movement logic
		
		car.acceleration.y = car.gravity
		car.velocity += car.acceleration * delta
		car.update_speed(int(car.velocity.length())) 
		car.move_and_slide()
		
		if car.moving_right:
			car.raycast.position.x = abs(car.raycast.position.x)
		else:
			car.raycast.position.x = -abs(car.raycast.position.x)
		
		car.update_position(car.car_position)
		
