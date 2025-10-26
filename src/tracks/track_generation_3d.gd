@tool
extends Path3D

var is_dirty = false
var road_part_size = 10.0

func _ready():
	pass
	
func _process(delta: float):
	if is_dirty:
		update_multimesh()
		is_dirty = false

func update_multimesh():
	var path_length = curve.get_baked_length()
	
	var mm: MultiMesh = $MultiMeshInstance3D.multimesh
	var count = 0
	while path_length > 0:
		var curve_distance = road_part_size * count
		position = curve.sample_baked(curve_distance, true)
		var forward = position.direction_to(curve.sample_baked(curve_distance + 0.1, true))
		var up = curve.sample_baked_up_vector(curve_distance, true)
		
		path_length -= road_part_size
		basis = Basis()
		basis.y = up
		basis.x = forward.cross(up).normalized()
		basis.z = -forward
		transform = Transform3D(basis, position)
		mm.set_instance_transform(count, transform)


func _on_curve_changed() -> void:
	is_dirty = true
