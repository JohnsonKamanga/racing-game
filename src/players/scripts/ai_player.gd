extends Player
class_name AIPlayer

# FSM States , inpired by documents given in the assignment
enum States {
	NORMAL_DRIVING,
	OVERTAKING,
	DEFEND_AND_BLOCK,
	RECOVER
}

var current_state: States = States.NORMAL_DRIVING
var state_timer: float = 0.0

# AI characteristics (driver persona)
@export var skill_level: float = 0.99  # 0.98-1.0 range
@export var aggression: float = 0.5  # 0.0-1.0
@export var mistake_probability: float = 0.02
var biorhythm_time: float = 0.0
var current_skill_modifier: float = 1.0

# Steering behavior settings
@export var speed_max := 450.0
@export var acceleration_max = 50.0
@export var angular_speed_max = 360
@export var angular_acceleration_max = 40

var angular_velocity = 0.0

# Steering framework
@onready var agent = GSAISteeringAgent.new()
var follow_behavior: GSAIFollowPath
var path: GSAIPath
var proximity: GSAIRadiusProximity
var steering_output := GSAITargetAcceleration.new()

# State-specific data
var overtake_target: BaseCar = null
var overtake_side: String = ""  # "left" or "right"
var defend_target: BaseCar = null
var recovery_points: int = 0
var state_transition_cooldown: float = 0.0

# Utility thresholds
const NORMAL_DRIVING_UTILITY = 500
const UTILITY_HYSTERESIS = 50

func _ready():
	setup_agent()
	setup_path()
	setup_behaviors()

func setup_agent():
	agent.linear_speed_max = speed_max
	agent.linear_acceleration_max = acceleration_max
	agent.angular_acceleration_max = deg_to_rad(angular_acceleration_max)
	agent.angular_speed_max = deg_to_rad(angular_speed_max)
	
	var collision_shape = car.get_node("BodyCollisionShape3D") as CollisionShape3D
	var x_radius = collision_shape.shape.extents.x
	var y_radius = collision_shape.shape.extents.y
	agent.bounding_radius = x_radius if x_radius > y_radius else y_radius
	
	update_agent()

func setup_path():
	var track_scene = load(Global.selected_track_path)
	var track_instance = track_scene.instantiate() as StaticBody3D
	
	# Add to tree temporarily (but hidden) so to_global() works
	add_child(track_instance)
	track_instance.hide()  # Keep it hidden since it's just for path extraction
	
	var p = track_instance.get_node("Node3D/AIPath") as Path3D
	var curve = p.curve
	
	var baked_length = curve.get_baked_length()
	var bake_interval = curve.bake_interval
	var num_points = int(baked_length / bake_interval)
	var waypoints = []
	
	for i in range(num_points + 1):
		var offset = (float(i) / num_points) * baked_length
		var point = curve.sample_baked(offset)
		var global_point = p.to_global(point)
		waypoints.append(global_point)
	
	# Clean up the temporary track instance
	track_instance.queue_free()
	
	# FALSE = closed/looping path
	path = GSAIPath.new(waypoints, false)


func setup_behaviors():
	follow_behavior = GSAIFollowPath.new(agent, path, 30.0, 0.3)
	follow_behavior.deceleration_radius = 100.0
	follow_behavior.arrival_tolerance = 20.0
	follow_behavior.is_arrive_enabled = false

func get_input(delta: float = 1.0):
	update_agent()
	update_biorhythm(delta)
	state_timer += delta
	state_transition_cooldown = max(0.0, state_transition_cooldown - delta)
	
	# Evaluate state transitions
	if state_transition_cooldown <= 0.0:
		evaluate_state_transitions()
	
	# Execute current state behavior
	match current_state:
		States.NORMAL_DRIVING:
			execute_normal_driving(delta)
		States.OVERTAKING:
			execute_overtaking(delta)
		States.DEFEND_AND_BLOCK:
			execute_defend_and_block(delta)
		States.RECOVER:
			execute_recovery(delta)

func update_biorhythm(delta: float):
	# Biorhythm with 100 second period
	biorhythm_time += delta
	var wave = sin(biorhythm_time * TAU / 100.0)
	# Map from [-1, 1] to skill variation range
	# High skill 99% varies between 97-99%
	var skill_range = 0.02
	current_skill_modifier = skill_level + (wave * skill_range - skill_range/2)
	current_skill_modifier = clamp(current_skill_modifier, 0.95, 1.0)

func evaluate_state_transitions():
	var current_utility = calculate_state_utility(current_state)
	var best_state = current_state
	var best_utility = current_utility + UTILITY_HYSTERESIS  # Hysteresis
	
	# Check all possible states
	for state in States.values():
		if state == current_state:
			continue
		
		var utility = calculate_state_utility(state)
		if utility > best_utility:
			best_utility = utility
			best_state = state
	
	# Transition if better state found
	if best_state != current_state:
		exit_state(current_state)
		current_state = best_state
		enter_state(current_state)

func calculate_state_utility(state: States) -> float:
	match state:
		States.NORMAL_DRIVING:
			return NORMAL_DRIVING_UTILITY
		
		States.OVERTAKING:
			return calculate_overtaking_utility()
		
		States.DEFEND_AND_BLOCK:
			return calculate_defend_utility()
		
		States.RECOVER:
			return calculate_recovery_utility()
	
	
	return 0.0

func calculate_overtaking_utility() -> float:
	var utility = 0.0
	var nearby_cars = get_cars_ahead(150.0)
	
	if nearby_cars.is_empty():
		return 0.0
	
	var target = nearby_cars[0]
	var speed_advantage = car.velocity.length() - target.velocity.length()
	
	# Need speed advantage to overtake
	if speed_advantage > 5.0:
		utility = 600.0
		
		# Increase utility based on speed advantage
		utility += speed_advantage * 5.0
		
		# Aggression increases overtaking likelihood
		utility += aggression * 100.0
		
		# Check if there's space to overtake
		if has_overtaking_opportunity(target):
			utility += 200.0
		
		# Random factor (some drivers more opportunistic)
		var random_factor = randf_range(-50.0, 50.0)
		utility += random_factor
	
	return utility

func calculate_defend_utility() -> float:
	var utility = 0.0
	var cars_behind = get_cars_behind(100.0)
	
	if cars_behind.is_empty():
		return 0.0
	
	var threat = cars_behind[0]
	var speed_deficit = threat.velocity.length() - car.velocity.length()
	
	# Opponent is faster and catching up
	if speed_deficit > 5.0:
		utility = 550.0
		
		# More aggressive drivers defend more
		utility += aggression * 150.0
		
		# Increase utility if opponent is very close
		var distance = car.global_position.distance_to(threat.global_position)
		if distance < 30.0:
			utility += 100.0
	
	return utility

func calculate_recovery_utility() -> float:
	var utility = 0.0
	var recovery_score = 0
	
	# Check if off track
	var current_distance = path.calculate_distance(agent.position)
	var nearest_point = path.calculate_target_position(current_distance)
	var distance_from_path = car.global_position.distance_to(nearest_point)
	
	# Far off track - major issue
	if distance_from_path > 15.0:
		recovery_score += 60
	elif distance_from_path > 10.0:
		recovery_score += 30
	
	# Check if speed is very low (stalled)
	var current_speed = car.velocity.length()
	if current_speed < 3.0:
		recovery_score += 40
	elif current_speed < 8.0:
		recovery_score += 20
	
	# Check orientation (facing wrong way)
	var forward = -car.transform.basis.z.normalized()
	var path_forward = (path.calculate_target_position(current_distance + 10.0) - nearest_point).normalized()
	var alignment = forward.dot(path_forward)
	
	if alignment < -0.3:  # Facing significantly wrong direction
		recovery_score += 50
	elif alignment < 0.3:  # Slightly misaligned
		recovery_score += 25
	
	# Check if stuck (position not changing much)
	# This would need a stored previous position - see below for implementation
	
	# Convert score to utility
	if recovery_score > 40:
		utility = 900.0 + recovery_score * 2.0
	
	return utility


func enter_state(state: States):
	state_timer = 0.0
	
	match state:
		States.NORMAL_DRIVING:
			pass
		States.OVERTAKING:
			overtake_target = find_overtake_target()
			overtake_side = determine_overtake_side(overtake_target)
		States.DEFEND_AND_BLOCK:
			defend_target = get_cars_behind(100.0)[0] if not get_cars_behind(100.0).is_empty() else null
		States.RECOVER:
			recovery_points = 100  # Start high to stay in recovery
			print_debug("AI entering RECOVERY mode")

func exit_state(state: States):
	match state:
		States.OVERTAKING:
			overtake_target = null
			state_transition_cooldown = 3.0
		States.DEFEND_AND_BLOCK:
			defend_target = null
		States.RECOVER:
			recovery_points = 0
			state_transition_cooldown = 2.0  # Prevent immediate re-entry
			print_debug("AI exiting RECOVERY mode")


func execute_normal_driving(delta: float):
	# Standard path following with conservative spacing
	follow_behavior.calculate_steering(steering_output)
	apply_ai_steering(steering_output, delta, 1.0)

func execute_overtaking(delta: float):
	# Push to the limit and get aggressive
	var skill_boost = 1.02  # Exceed normal limits temporarily
	
	if overtake_target and is_instance_valid(overtake_target):
		# Calculate offset from racing line to overtake
		var lateral_offset = 0.0
		if overtake_side == "left":
			lateral_offset = -10.0  # Move left
		else:
			lateral_offset = 10.0  # Move right
		
		# Modify steering target
		follow_behavior.calculate_steering(steering_output)
		
		# Add lateral adjustment for overtaking
		var perpendicular = Vector3.UP.cross(-car.transform.basis.z).normalized()
		var offset_target = steering_output.linear.normalized()
		steering_output.linear = (offset_target + perpendicular * lateral_offset * 0.1).normalized() * agent.linear_acceleration_max
		
		apply_ai_steering(steering_output, delta, skill_boost)
		
		# Check if overtake complete
		if has_completed_overtake(overtake_target):
			state_transition_cooldown = 2.0  # Brief cooldown before state change
			overtake_target = null
	else:
		# Lost target, return to normal driving
		execute_normal_driving(delta)

func execute_defend_and_block(delta: float):
	# Match opponent's lateral position
	if defend_target and is_instance_valid(defend_target):
		var my_pos = car.global_position
		var opponent_pos = defend_target.global_position
		
		# Calculate lateral offset to block
		var to_opponent = opponent_pos - my_pos
		var perpendicular = Vector3.UP.cross(-car.transform.basis.z).normalized()
		var lateral_diff = to_opponent.dot(perpendicular)
		
		# Small steering adjustments to block
		follow_behavior.calculate_steering(steering_output)
		var block_adjustment = perpendicular * sign(lateral_diff) * 5.0
		steering_output.linear += block_adjustment
		steering_output.linear = steering_output.linear.normalized() * agent.linear_acceleration_max
		
		apply_ai_steering(steering_output, delta, 1.01)
		
		# Exit if opponent gets alongside or too far
		var distance = my_pos.distance_to(opponent_pos)
		if distance > 50.0 or abs(lateral_diff) < 2.0:
			defend_target = null
	else:
		execute_normal_driving(delta)

func execute_recovery(delta: float):
	var current_distance = path.calculate_distance(agent.position)
	var nearest_point = path.calculate_target_position(current_distance)
	var distance_from_path = car.global_position.distance_to(nearest_point)
	var current_speed = car.velocity.length()
	
	# Check orientation
	var forward = -car.transform.basis.z.normalized()
	var path_forward = (path.calculate_target_position(current_distance + 10.0) - nearest_point).normalized()
	var alignment = forward.dot(path_forward)
	
	# Determine recovery strategy based on situation
	if alignment < -0.5:
		# Badly misaligned - need to turn around
		print_debug("Recovery: Turning around")
		var perpendicular = Vector3.UP.cross(forward).normalized()
		steering_output.linear = perpendicular * agent.linear_acceleration_max * 0.8
		
		# Apply steering to turn
		var turn_direction = sign(forward.cross(path_forward).y)
		car.steer_angle = turn_direction * deg_to_rad(car.steering_limit)
		
		# Gentle throttle or reverse
		if current_speed < 2.0:
			car.acceleration = -car.transform.basis.z * car.engine_power * 0.4
		else:
			car.acceleration = Vector3.ZERO
		
	elif distance_from_path > 15.0:
		# Far off track - drive toward path
		print_debug("Recovery: Returning to track")
		var to_path = (nearest_point - car.global_position).normalized()
		
		# Calculate steering toward path
		var current_forward = -car.transform.basis.z.normalized()
		var angle_to_target = current_forward.signed_angle_to(to_path, Vector3.UP)
		
		car.steer_angle = clamp(
			angle_to_target * 3.0,
			-deg_to_rad(car.steering_limit),
			deg_to_rad(car.steering_limit)
		)
		
		# Moderate speed to reach track
		var target_speed = agent.linear_speed_max * 0.5
		if current_speed < target_speed * 0.9:
			car.acceleration = -car.transform.basis.z * car.engine_power * 0.7
		elif current_speed > target_speed * 1.2:
			car.acceleration = -car.transform.basis.z * car.braking * 0.5
		else:
			car.acceleration = -car.transform.basis.z * car.engine_power * 0.4
		
	elif current_speed < 5.0:
		# Stalled on track - accelerate forward
		print_debug("Recovery: Accelerating from stall")
		
		# Get back on racing line
		follow_behavior.calculate_steering(steering_output)
		var to_target = steering_output.linear.normalized()
		var current_forward = -car.transform.basis.z.normalized()
		var angle_to_target = current_forward.signed_angle_to(to_target, Vector3.UP)
		
		car.steer_angle = clamp(
			angle_to_target * 2.5,
			-deg_to_rad(car.steering_limit * 0.7),
			deg_to_rad(car.steering_limit * 0.7)
		)
		
		# Strong acceleration to get moving
		car.acceleration = -car.transform.basis.z * car.engine_power * 0.8
		
	else:
		# Close to track and moving - stabilize and return to racing
		print_debug("Recovery: Stabilizing")
		follow_behavior.calculate_steering(steering_output)
		apply_ai_steering(steering_output, delta, 0.8)
	
	# Update recovery state
	if state_timer > 1.0:  # Been in recovery for at least 1 second
		# Check if we're recovered
		if distance_from_path < 8.0 and alignment > 0.5 and current_speed > 10.0:
			recovery_points = 0  # Exit recovery
			print_debug("Recovery complete!")
		elif distance_from_path < 12.0 and current_speed > 5.0:
			recovery_points = max(0, recovery_points - 15)  # Gradual decay
	
	# Safety: force exit after too long in recovery
	if state_timer > 10.0:
		print_debug("Recovery timeout - forcing exit")
		recovery_points = 0

func apply_ai_steering(_steering: GSAITargetAcceleration, _delta: float, skill_multiplier: float = 1.0):
	var current_distance = path.calculate_distance(agent.position)
	var nearest_point_on_path = path.calculate_target_position(current_distance)
	var distance_from_path = car.global_position.distance_to(nearest_point_on_path)
	
	var current_speed = car.velocity.length()
	var adaptive_offset = follow_behavior.path_offset
	
	# Adaptive look-ahead
	if distance_from_path > 10.0:
		adaptive_offset = 0.0
	elif distance_from_path > 5.0:
		adaptive_offset = 15.0
	else:
		adaptive_offset = min(follow_behavior.path_offset, 15.0 + current_speed * 0.5)
	
	var target_distance = current_distance + adaptive_offset
	var target_position = path.calculate_target_position(target_distance)
	
	# Steering calculation
	var to_target = target_position - car.global_position
	to_target.y = 0
	
	if to_target.length() > 0.5:
		var desired_direction = to_target.normalized()
		var current_forward = -car.transform.basis.z.normalized()
		var angle_to_target = current_forward.signed_angle_to(desired_direction, Vector3.UP)
		
		var steering_multiplier = 4.0
		if distance_from_path > 10.0:
			steering_multiplier = 6.0
		elif distance_from_path > 5.0:
			steering_multiplier = 5.0
		
		car.steer_angle = clamp(
			angle_to_target * steering_multiplier,
			-deg_to_rad(car.steering_limit),
			deg_to_rad(car.steering_limit)
		)
	else:
		car.steer_angle = 0.0
	
	# Update wheels
	if car.has_node("wheel-back-right"):
		car.get_node("wheel-back-right").rotation.y = car.steer_angle
	if car.has_node("wheel-back-left"):
		car.get_node("wheel-back-left").rotation.y = car.steer_angle
	
	# Speed control with skill modifier
	var turn_sharpness = abs(car.steer_angle)
	var base_target_speed = agent.linear_speed_max * 0.85 * current_skill_modifier * skill_multiplier
	var target_speed = base_target_speed
	
	# Adjust for situation
	if distance_from_path > 15.0:
		target_speed = base_target_speed * 0.3
	elif distance_from_path > 8.0:
		target_speed = base_target_speed * 0.6
	elif turn_sharpness > deg_to_rad(35):
		target_speed = base_target_speed * 0.6
	elif turn_sharpness > deg_to_rad(25):
		target_speed = base_target_speed * 0.75
	
	# Apply throttle/brake
	if current_speed < target_speed * 0.95:
		car.acceleration = -car.transform.basis.z * car.engine_power
	elif current_speed > target_speed * 1.5:
		car.acceleration = -car.transform.basis.z * car.braking * 0.4
	else:
		car.acceleration = -car.transform.basis.z * car.engine_power * 0.95

func apply_recovery_steering(steering: GSAITargetAcceleration, _delta: float, target_speed: float):
	# Simplified steering for recovery
	var current_speed = car.velocity.length()
	
	var to_target = steering.linear.normalized()
	var current_forward = -car.transform.basis.z.normalized()
	var angle_to_target = current_forward.signed_angle_to(to_target, Vector3.UP)
	
	car.steer_angle = clamp(
		angle_to_target * 2.0,
		-deg_to_rad(car.steering_limit),
		deg_to_rad(car.steering_limit)
	)
	
	if current_speed > target_speed:
		car.acceleration = -car.transform.basis.z * car.braking * 0.6
	else:
		car.acceleration = -car.transform.basis.z * car.engine_power * 0.3

func update_agent() -> void:
	agent.position.x = car.global_position.x
	agent.position.y = car.global_position.y
	agent.position.z = car.global_position.z
	
	var forward = -car.global_transform.basis.z
	agent.orientation = atan2(forward.x, forward.z)
	
	agent.linear_velocity.x = car.velocity.x
	agent.linear_velocity.y = car.velocity.y
	agent.linear_velocity.z = car.velocity.z
	agent.angular_velocity = angular_velocity

# Utility functions
func get_cars_ahead(distance: float) -> Array[BaseCar]:
	var result: Array[BaseCar] = []
	if not Global.players:
		return result
	
	var my_forward = -car.transform.basis.z.normalized()
	
	for player in Global.players:
		if player == car or not is_instance_valid(player):
			continue
		
		var to_player = player.global_position - car.global_position
		var dist = to_player.length()
		
		if dist < distance and to_player.normalized().dot(my_forward) > 0.5:
			result.append(player)
	
	# Sort by distance
	result.sort_custom(func(a, b): return car.global_position.distance_to(a.global_position) < car.global_position.distance_to(b.global_position))
	
	return result

func get_cars_behind(distance: float) -> Array[BaseCar]:
	var result: Array[BaseCar] = []
	if not Global.players:
		return result
	
	var my_forward = -car.transform.basis.z.normalized()
	
	for player in Global.players:
		if player == car or not is_instance_valid(player):
			continue
		
		var to_player = player.global_position - car.global_position
		var dist = to_player.length()
		
		if dist < distance and to_player.normalized().dot(my_forward) < -0.5:
			result.append(player)
	
	result.sort_custom(func(a, b): return car.global_position.distance_to(a.global_position) < car.global_position.distance_to(b.global_position))
	
	return result

func find_overtake_target() -> BaseCar:
	var cars_ahead = get_cars_ahead(100.0)
	return cars_ahead[0] if not cars_ahead.is_empty() else null

func determine_overtake_side(target: BaseCar) -> String:
	if not target:
		return "right"
	
	var to_target = target.global_position - car.global_position
	var perpendicular = Vector3.UP.cross(-car.transform.basis.z).normalized()
	var lateral = to_target.dot(perpendicular)
	
	# Go to opposite side
	return "left" if lateral > 0 else "right"

func has_overtaking_opportunity(target: BaseCar) -> bool:
	if not target:
		return false
	
	# Check if there's space beside the target
	var distance = car.global_position.distance_to(target.global_position)
	return distance > 10.0 and distance < 50.0

func has_completed_overtake(target: BaseCar) -> bool:
	if not target or not is_instance_valid(target):
		return true
	
	var to_target = target.global_position - car.global_position
	var my_forward = -car.transform.basis.z.normalized()
	
	# Overtake complete if target is behind us
	return to_target.dot(my_forward) < 0 and to_target.length() > 15.0
