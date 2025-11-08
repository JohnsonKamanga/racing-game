class_name BaseCar extends CharacterBody3D

#most of this code was obtained and inspired from https://kidscancode.org/godot_recipes/3.x/3d/kinematic_car/car_base/index.html
@export var gravity = -20
@export var wheel_base = 0.6
@export var steering_limit = 10.0
@export var engine_power = 20.0
@export var braking = -9.0
@export var friction = -2.0
@export var drag = -2.0
@export var max_speed_reverse = 3.0
@export var car_name = ""


var acceleration = Vector3.ZERO
var steer_angle = 0.0
var raycast: RayCast3D
var moving_right = true
var total_time : int = 0
var lap = 0
var finished: bool = false
var distance_traveled: float = 0.0 # Total distance traveled by the vehicle (will be helpful later)
var _last_player_position: Vector3 = Vector3.ZERO #tmp

func update_distance_traveled():
	# find length to vector between last and current position
	var distance = position.distance_to(_last_player_position)
	_last_player_position = position # update last position
	distance_traveled += distance

func get_distance_traveled():
	return distance_traveled

func update_speed(speed: float):
	$HUD/Speed.text = str(speed) + " km/h"

func calculate_realistic_top_speed() -> float:
	"""
	More accurate top speed calculation considering both drag and friction
	At top speed: engine_power = drag * v^2 + friction * v
	Solving quadratic equation: drag*v^2 + friction*v - engine_power = 0
	"""
	var a = abs(drag)
	var b = abs(friction)
	var c = -engine_power
	
	# Quadratic formula: v = (-b + sqrt(b^2 - 4ac)) / 2a
	var discriminant = b * b - 4 * a * c
	if discriminant < 0:
		return 0.0
	
	var top_speed = (-b + sqrt(discriminant)) / (2 * a)
	return top_speed * 3.6  # Convert to km/h (assuming m/s * 3.6)

func get_display_stats(): 
	var speed = calculate_realistic_top_speed()
	
	return {
		"name": car_name,
		"speed": round(speed),
		"acceleration": round(acceleration.length()),
		"brakes": abs(braking)
	}

func calculate_time(time_in_seconds: int): 
	var m = int(time_in_seconds / 60.0)
	var s = int(time_in_seconds - m * 60)
	return {"min": m, "sec": s}


func update_timer(time: int):
	var t = calculate_time(time)
	$HUD/RaceTime.text = '%02d:%02d' % [t.min, t.sec]


func _ready():
	update_speed(0)
	$RaceTimer.start()
	raycast = $RayCast3D # Make sure this matches the name of your RayCast3D node
	$HUD/Lap.text =  "1"


func apply_friction(delta: float):
	if velocity.length() < 0.2 and acceleration.length() == 0:
		velocity.x = 0
		velocity.y = 0
	
	var friction_force = velocity * friction * delta
	var drag_force = velocity * velocity.length() * delta * drag
	acceleration += drag_force + friction_force


func calculate_steering(delta: float):
	var rear_wheel = transform.origin + transform.basis.z * wheel_base / 2.0
	var front_wheel = transform.origin - transform.basis.z * wheel_base / 2.0
	rear_wheel += velocity * delta
	front_wheel += velocity.rotated(transform.basis.y.normalized(), steer_angle * 0.3) * delta
	var new_heading = rear_wheel.direction_to(front_wheel)
	
	var d = new_heading.dot(velocity.normalized())
	if d > 0:
		velocity = new_heading * velocity.length()
	
	if d < 0:
		velocity = - new_heading * min(velocity.length(), max_speed_reverse)
	
	look_at(transform.origin + new_heading, transform.basis.y)


func get_input():
	var turn = Input.get_action_strength("steer_left")
	turn -= Input.get_action_strength("steer_right")
	steer_angle = turn * deg_to_rad(steering_limit)
	#front and back wheels swapped naming - front refers to back and back refers to front
	$"wheel-back-right".rotation.y = steer_angle * 2
	$"wheel-back-left".rotation.y = steer_angle * 2
	acceleration = Vector3.ZERO
	
	if Input.is_action_pressed("accelerate"):
		acceleration = -transform.basis.z * engine_power
	
	if Input.is_action_pressed("brake"):
		acceleration = -transform.basis.z * braking
		


func _physics_process(delta: float) -> void:
	
	if is_on_floor():
		get_input()
		apply_friction(delta)
		calculate_steering(delta)
		update_distance_traveled()
		
	if not raycast.is_colliding():
		moving_right = not moving_right
		# Reverse the velocity or move direction based on your movement logic
		
	acceleration.y = gravity
	velocity += acceleration * delta
	update_speed(int(velocity.length())) 
	move_and_slide()
	
	if moving_right:
		raycast.position.x = abs(raycast.position.x)
	else:
		raycast.position.x = -abs(raycast.position.x)

#this timer implementation was inspired by https://youtu.be/lx-eo3kQPyA?si=eNAZaQdjPtdUxUP0
func _on_race_timer_timeout() -> void:
	total_time +=1
	update_timer(total_time)
	

func next_lap():
	if not finished:
		lap += 1
		print("debug: lap " + str(lap))
