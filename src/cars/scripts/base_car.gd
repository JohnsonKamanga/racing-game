extends CharacterBody3D

#most of this code was obtained and inspired from https://kidscancode.org/godot_recipes/3.x/3d/kinematic_car/car_base/index.html
@export var gravity = -20
@export var wheel_base = 0.6
@export var steering_limit = 10.0
@export var engine_power = 6.0
@export var braking = -9.0
@export var friction = -2.0
@export var drag = -2.0
@export var max_speed_reverse = 3.0

var acceleration = Vector3.ZERO
var steer_angle = 0.0

func apply_friction(delta: float):
	if velocity.length() < 2 and acceleration.length() == 0:
		velocity.x = 0
		velocity.y = 0
	
	var friction_force = velocity * friction * delta
	var drag_force = velocity * velocity.length() * delta * drag
	acceleration += drag_force + friction_force


func calculate_steering(delta: float):
	var rear_wheel = transform.origin + transform.basis.z * wheel_base / 2.0
	var front_wheel = transform.origin - transform.basis.z * wheel_base / 2.0
	rear_wheel += velocity * delta
	front_wheel += velocity.rotated(transform.basis.y, -steer_angle) * delta
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
	$"wheel-front-right".rotation.y = steer_angle * 2
	$"wheel-front-left".rotation.y = steer_angle * 2
	acceleration = Vector3.ZERO
	
	if Input.is_action_pressed("accelerate"):
		acceleration = transform.basis.z * engine_power
	
	if Input.is_action_pressed("brake"):
		acceleration = transform.basis.z * braking
		


func _physics_process(delta: float) -> void:
	
	if is_on_floor():
		get_input()
		apply_friction(delta)
		calculate_steering(delta)
		
	acceleration.y = gravity
	var friction_force = velocity * friction * delta
	var drag_force = velocity * velocity.length() * delta * drag
	acceleration += drag_force + friction_force
	
	velocity += acceleration * delta
	
	move_and_slide()
