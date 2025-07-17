
extends CharacterBody3D

@export var speed = 300.0
@export var jump_velocity = 4.5

var gravity = ProjectSettings.get_setting("physics/3d/default_gravity")
var player_id: int
var camera: OrbitCamera

var direction := Vector2(0,0)

var bufferer: Bufferer




func _ready():
	player_id = get_multiplayer_authority()

	bufferer = Bufferer.new(self)
	self.add_child(bufferer)

	Util.disable_physics_clientside(self)

	if is_multiplayer_authority():
		# Capture mouse for local player
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
		camera = OrbitCamera.new()
		camera.target = self
		camera.follow_offset = Vector3(0, 1.75, 0)
		camera.current = true
		get_tree().current_scene.add_child(camera) # TODO: Clean up camera when done
	else:
		# Else, its on server, OR on another 
		set_process_input(false)
		$ServerCollider.server_collide.connect(_server_collide)



func _physics_process_server(delta: float) -> void:
	if not is_on_floor():
		velocity.y -= gravity * delta
	
	if direction:
		velocity.x = direction.x * speed * delta
		velocity.z = direction.y * speed * delta
	else:
		velocity.x = move_toward(velocity.x, 0, speed * delta)
		velocity.z = move_toward(velocity.z, 0, speed * delta)
	
	move_and_slide()

	# TODO: in future could do simple delta-compression:
	# if global_position.distance_to(last_position) > EPSILON:
	var time = NetworkManager.get_time()
	sync_physics_state.rpc(
		self.global_position, self.velocity, self.direction,
		time
	)


func _physics_process_client(_delta: float) -> void:
	if direction.length() > 0:
		global_rotation.y = atan2(direction.x, direction.y)

	if not is_multiplayer_authority():
		# we dont wanna control other player's clients
		return

	var time = NetworkManager.get_time()
	if Input.is_action_just_pressed("ui_accept"):
		sync_jump.rpc(time)

	var input_dir := Input.get_vector("move_left", "move_right", "move_forward", "move_back")
	var move_dir := input_dir.rotated(-camera.global_rotation.y)
	sync_move_direction.rpc(move_dir, time)
	




func _physics_process(delta):
	if multiplayer.is_server():
		_physics_process_server(delta)
	else:
		_physics_process_client(delta)


const MOUSE_SENSITIVITY = 0.001


func _input(event):
	if event is InputEventMouseMotion:
		pass
	elif event is InputEventMouseButton:
		if event.button_index == 1:
			pass # TODO: kick ball, use tool, do something?



func _server_collide(body: RigidBody3D):
	var diff = body.global_position - self.global_position
	diff = diff.normalized()

	var restitution = 1.0

	var body_v: Vector3 = body.linear_velocity
	var self_v: Vector3 = self.velocity
	
	var relative_velocity = body_v - self_v
	var velocity_along_normal = relative_velocity.dot(diff)

	if velocity_along_normal > 0:
		# Don't resolve if velocities are separating
		return
	
	DebugDraw3D.draw_line(self.global_position, self.global_position + relative_velocity, Color(1, 1, 0))

	# Calculate impulse scalar
	var impulse_scalar = -(1 + restitution) * velocity_along_normal
	
	var impulse = impulse_scalar * diff
	body.linear_velocity += impulse

	if body is Ball:
		body.last_player_id = player_id

# server -> client
@rpc("any_peer", "call_remote", "unreliable_ordered", Util.UNRELIABLE_ORDERED)
func sync_physics_state(pos: Vector3, lin_vel: Vector3, move_dir: Vector2, send_time: float):
	bufferer.lerp_from_server(send_time, "global_position", pos)
	bufferer.lerp_from_server(send_time, "velocity", lin_vel)
	bufferer.do_from_server(send_time, func():
		# dont lerp direction, just set it directly.
		self.direction = move_dir
	)



# client -> server
@rpc("authority", "call_remote", "unreliable", Util.UNRELIABLE)
func sync_move_direction(move_dir: Vector2, send_time: float):
	# Smooth interpolation for non-authority players
	bufferer.do_from_client(send_time, func():
		direction = move_dir
		)

# client -> server
@rpc("authority", "call_remote", "reliable")
func sync_jump(send_time: float):
	if multiplayer.is_server() and is_on_floor():
		bufferer.do_from_client(send_time, func():
			velocity.y = jump_velocity		
			)
