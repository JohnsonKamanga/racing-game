extends StaticBody3D


func _on_finish_line_checkpoint_passed(body) -> void:
	body.lap +=1
	body.get_node("HUD/Lap").text = str(body.lap) 
