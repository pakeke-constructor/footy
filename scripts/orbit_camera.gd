class_name OrbitCamera
extends Camera3D


# Camera settings
@export var target: Node3D  # The object to follow (your car/player)
@export var follow_offset: Vector3
@export var follow_distance: float = 8.0
@export var camera_speed: float = 15.0
@export var rotation_speed: float = 3.0
@export var mouse_sensitivity: float = 0.005

# Collision detection
@onready var space_state := get_world_3d().direct_space_state


func _ready():
	# Capture mouse for camera control
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED


func _input(event):
	# Handle mouse movement for camera rotation
	if event is InputEventMouseMotion:
		global_rotation.x -= event.relative.y * mouse_sensitivity
		global_rotation.y -= event.relative.x * mouse_sensitivity
		
		# HACK: This is somehow needed to prevent camera going weird?
		# TODO: Not have the camera as a child of the player, I think
		# - Atirut
		global_rotation.z = 0
		
		# Clamp vertical rotation to prevent flipping
		global_rotation.x = clamp(global_rotation.x, -PI/3, PI/6)
	

func _process(delta):
	if not target:
		return
	
	# Calculate desired camera position
	var desired_position = calculate_camera_position()
	
	# Check for collisions and adjust position
	var final_position = handle_collision(target.global_position + follow_offset, desired_position)
	
	# Smoothly move camera to the final position
	global_position = global_position.lerp(final_position, camera_speed * delta)


func calculate_camera_position() -> Vector3:
	var offset := Vector3(
		sin(global_rotation.y) * cos(global_rotation.x) * follow_distance,
		-sin(global_rotation.x) * follow_distance,
		cos(global_rotation.y) * cos(global_rotation.x) * follow_distance
	)
	
	return target.global_position + follow_offset + offset


func handle_collision(target_pos: Vector3, desired_pos: Vector3) -> Vector3:
	# Cast a ray from target to desired camera position
	var query = PhysicsRayQueryParameters3D.create(target_pos, desired_pos)
	query.exclude = [target]  # Don't collide with the target itself
	
	var result = space_state.intersect_ray(query)
	
	if result:
		# If there's a collision, move camera slightly in front of the collision point
		var collision_point = result.position
		var direction = (target_pos - collision_point).normalized()
		return collision_point + direction * 0.5
	
	return desired_pos
