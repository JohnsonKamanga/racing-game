extends Sprite2D

var pressing = false
var is_pressing_right = false
var is_pressing_left = false

@onready var parent = $".."
@export var max_length = 50
@export var deadzone = 5

func _ready():
	print_debug(parent)

func _process(delta):
	if pressing:
		var angle = parent.global_position.angle_to_point(get_global_mouse_position())
		
		# Update joystick position
		if get_global_mouse_position().distance_to(parent.global_position) <= max_length:
			global_position = get_global_mouse_position()
		else:
			global_position.x = parent.global_position.x + cos(angle) * max_length
			global_position.y = parent.global_position.y + sin(angle) * max_length
		
		# Calculate horizontal offset from center
		var offset_x = global_position.x - parent.global_position.x
		
		# Check direction based on horizontal offset (beyond deadzone)
		if offset_x > deadzone:
			# Moving right
			if not is_pressing_right:
				Input.action_press("steer_right")
				is_pressing_right = true
				print_debug("press right")
			# Release left if it was pressed
			if is_pressing_left:
				Input.action_release("steer_left")
				is_pressing_left = false
				print_debug("release left")
				
		elif offset_x < -deadzone:
			# Moving left
			if not is_pressing_left:
				Input.action_press("steer_left")
				is_pressing_left = true
				print_debug("press left")
			# Release right if it was pressed
			if is_pressing_right:
				Input.action_release("steer_right")
				is_pressing_right = false
				print_debug("release right")
				
		else:
			# Within deadzone - release both
			if is_pressing_right:
				Input.action_release("steer_right")
				is_pressing_right = false
				print_debug("release right (deadzone)")
			if is_pressing_left:
				Input.action_release("steer_left")
				is_pressing_left = false
				print_debug("release left (deadzone)")
		
		calculate_vector()
	else:
		# Joystick released - return to center and release all actions
		global_position = lerp(global_position, parent.global_position, delta * 10)
		parent.pos_vector = Vector2.ZERO
		
		if is_pressing_right:
			Input.action_release("steer_right")
			is_pressing_right = false
			print_debug("release right (joystick up)")
		if is_pressing_left:
			Input.action_release("steer_left")
			is_pressing_left = false
			print_debug("release left (joystick up)")

func _on_button_button_down() -> void:
	pressing = true

func _on_button_button_up() -> void:
	pressing = false

func calculate_vector():
	if abs(global_position.x - parent.global_position.x) >= deadzone:
		parent.pos_vector.x = (global_position.x - parent.global_position.x) / max_length
	else:
		parent.pos_vector.x = 0
		
	if abs(global_position.y - parent.global_position.y) >= deadzone:
		parent.pos_vector.y = (global_position.y - parent.global_position.y) / max_length
	else:
		parent.pos_vector.y = 0
