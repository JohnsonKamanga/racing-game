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
@export var max_acceleration = 10
@export var max_speed = 15

signal pause_game

var acceleration = Vector3.ZERO
var steer_angle = 0.0
var raycast: RayCast3D
var moving_right = true
var total_time : int = 0
var lap = 0
var finished: bool = false
var distance_traveled: float = 0.0 # Total distance traveled by the vehicle (will be helpful later)
var _last_player_position: Vector3 = Vector3.ZERO #tmp
var HUD: CanvasLayer #HUD to be dynamically set
var car_position: int = 0 #player's race positon 
var checkpoints_passed = 0

func update_distance_traveled():
	# find length to vector between last and current position
	var distance = position.distance_to(_last_player_position)
	_last_player_position = position # update last position
	distance_traveled += distance

func get_distance_traveled():
	return distance_traveled

func set_hud(c: CanvasLayer):
	HUD = c
	HUD.pause_game.connect(_on_pause_game)
	add_child(HUD)

func update_speed(speed: float):
	
	if HUD != null:
		var _speed_val = HUD.get_node("Speed")
		_speed_val.text = str(speed) + " km/h"
	
func update_acceleration(a: float):
	if HUD != null:
		var acceleration_val = HUD.get_node("Acceleration")
		acceleration_val.text = str(int(a)) + " km/h^2"


func get_display_stats(): 
	
	return {
		"name": car_name,
		"speed": max_speed,
		"acceleration": round(max_acceleration),
		"brakes": abs(braking)
	}

func calculate_time(time_in_seconds: int): 
	var m = int(time_in_seconds / 60.0)
	var s = int(time_in_seconds - m * 60)
	return {"min": m, "sec": s}


func update_timer(time: int):
	var t = calculate_time(time)
	
	if HUD != null :
		var time_val = HUD.get_node("RaceTime")
		time_val.text = '%02d:%02d' % [t.min, t.sec]


func _ready():
	update_speed(0)
	var timer: Timer = $RaceTimer
	timer.start()
	if not timer.is_connected("timeout", Callable(self, "_on_race_timer_timeout")):
		timer.timeout.connect(_on_race_timer_timeout)
	raycast = $RayCast3D # Make sure this matches the name of your RayCast3D node
	if HUD != null:
		HUD.get_node("Lap").text =  "1"


func apply_friction(delta: float):
	if velocity.length() < 0.2 and acceleration.length() == 0:
		velocity.x = 0
		velocity.y = 0
	
	var friction_force = velocity * friction * delta
	var drag_force = velocity * velocity.length() * delta * drag
	acceleration += drag_force + friction_force
	acceleration = max_acceleration * acceleration.normalized()
	update_acceleration(acceleration.length())


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


#this timer implementation was inspired by https://youtu.be/lx-eo3kQPyA?si=eNAZaQdjPtdUxUP0
func _on_race_timer_timeout() -> void:
	if Global.game_state == Global.Game_States.RUNNING :
		total_time +=1
		update_timer(total_time)
	

func next_lap():
	if not finished:
		lap += 1
		print("debug: lap " + str(lap))

func update_position(p: int):
	if HUD != null :
		var position_node = HUD.get_node("Position")
		position_node.text = str(p)

func set_car_position(p: int):
	car_position = p

func _on_pause_game():
	pause_game.emit()
