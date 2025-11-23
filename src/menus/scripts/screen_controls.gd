extends CanvasLayer


func _on_break_button_button_down() -> void:
	Input.action_press("brake")


func _on_break_button_button_up() -> void:
	print_debug(("pressed brake"))
	Input.action_release("brake")


func _on_acceleration_button_button_down() -> void:
	Input.action_press("accelerate")


func _on_acceleration_button_button_up() -> void:
	Input.action_release("accelerate")
