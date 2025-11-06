extends Area3D

@export var checkpoint_id: int

signal checkpoint_passed
var forward_direction : Vector3


func _ready() -> void:
	forward_direction = -global_transform.basis.z
	body_entered.connect(_on_body_entered)

func _on_body_entered(body):
	if body.is_in_group("vehicle"):
		var vehicle_velocity = body.velocity
		
		var dot = vehicle_velocity.normalized().dot(forward_direction)
		if dot > 0.3 :
			checkpoint_passed.emit(body)
		else :
			return
