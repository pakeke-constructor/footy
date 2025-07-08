
extends Camera3D

# Camera settings
@export var target: Node3D  # The object to follow (your car/player)
@export var follow_distance: float = 8.0
@export var follow_height: float = 4.0
@export var camera_speed: float = 5.0
@export var rotation_speed: float = 3.0
@export var mouse_sensitivity: float = 0.005

# Camera rotation
var camera_rotation_x: float = 0.0
var camera_rotation_y: float = 0.0

# Collision detection
var space_state: PhysicsDirectSpaceState3D

func _ready():
	# Capture mouse for camera control
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	
	# Get physics space for collision detection
	space_state = get_world_3d().direct_space_state

func _input(event):
	# Handle mouse movement for camera rotation
	if event is InputEventMouseMotion:
		camera_rotation_y -= event.relative.x * mouse_sensitivity
		camera_rotation_x -= event.relative.y * mouse_sensitivity
		
		# Clamp vertical rotation to prevent flipping
		camera_rotation_x = clamp(camera_rotation_x, -PI/3, PI/6)
	

func _process(delta):
	if not target:
		return
	
	# Calculate desired camera position
	var desired_position = calculate_camera_position()
	
	# Check for collisions and adjust position
	var final_position = handle_collision(target.global_position, desired_position)
	
	# Smoothly move camera to the final position
	global_position = global_position.lerp(final_position, camera_speed * delta)
	
	# Make camera look at the target
	look_at(target.global_position + Vector3.UP * 1.0, Vector3.UP)

func calculate_camera_position() -> Vector3:
	# Create rotation based on mouse input
	var transform_basis = Transform3D()
	transform_basis = transform_basis.rotated(Vector3.UP, camera_rotation_y)
	transform_basis = transform_basis.rotated(Vector3.RIGHT, camera_rotation_x)
	
	# Calculate offset from target
	var offset = Vector3(0, follow_height, follow_distance)
	offset = transform_basis * offset
	
	return target.global_position + offset

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
