class_name Player
extends CharacterBody3D

@export var speed = 150.0
@export var jump_velocity = 4.5
@export var kick_strength = 5.0
@export var sprint_multiplier = 1.5

var gravity = ProjectSettings.get_setting("physics/3d/default_gravity")
var player_id: int
var camera: OrbitCamera
@onready var detector: Area3D = %Detector
var current_item: Item

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

	var push_strength = 2;
	for i in get_slide_collision_count():
		var collision = get_slide_collision(i)
		var collider = collision.get_collider()
		
		if collider is RigidBody3D:
			var push_force = -collision.get_normal() * push_strength
			collider.apply_impulse(push_force, collision.get_position() - collider.global_position)

	# TODO: in future could do simple delta-compression:
	# if global_position.distance_to(last_position) > EPSILON:
	var time = NetworkManager.get_time()
	sync_physics_state.rpc(
		self.global_position, self.velocity, self.direction,
		time
	)


func _physics_process_client(delta: float) -> void:
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
	move_dir = move_dir.normalized() # Normalize to prevent diagonal speed boost
	if Input.is_action_pressed("sprint"):
		move_dir *= sprint_multiplier
		camera.fov = lerp(camera.fov, 90.0, delta * 5)
	else:
		camera.fov = lerp(camera.fov, 75.0, delta * 5)
	sync_move_direction.rpc(move_dir, time)
	sync_rotation.rpc(rotation, time)
	




func _physics_process(delta):
	if multiplayer.is_server():
		_physics_process_server(delta)
	else:
		_physics_process_client(delta)


const MOUSE_SENSITIVITY = 0.001


func _input(event):
	if not is_multiplayer_authority():
		return

	if event is InputEventMouseButton:
		if event.button_index == 1 && event.pressed:
			if current_item:
				current_item.use(self)
			else:
				_kick.rpc_id(1, -camera.global_transform.basis.z * kick_strength)
				_kick_particles.rpc_id(1, GameManager.ball.position)


@rpc("authority", "call_remote", "reliable")
func _kick(direction: Vector3):
	if not multiplayer.is_server():
		return
	
	if detector.has_overlapping_bodies():
		var balls := detector.get_overlapping_bodies().filter(
			func(b): return b is Ball and b != self
		) as Array[Node3D]
		if balls.size() > 0:
			balls.sort_custom(
				func(a, b): return a.global_position.distance_to(self.global_position) < b.global_position.distance_to(self.global_position)
			)
			var ball := balls[0] as Ball
			ball.apply_impulse(direction.normalized() * kick_strength, Vector3.ZERO)


@rpc("authority", "call_local", "reliable")
func _kick_particles(pos: Vector3):
	GameManager.spawn_object("res://scenes/particles/kick/kick.tscn", pos, Vector3.ZERO)


# server -> client
@rpc("any_peer", "call_remote", "unreliable_ordered", Util.UNRELIABLE_ORDERED)
func sync_physics_state(pos: Vector3, lin_vel: Vector3, move_dir: Vector2, send_time: float):
	bufferer.lerp_from_server(send_time, "global_position", pos)
	#bufferer.lerp_from_server(send_time, "velocity", lin_vel)
	bufferer.do_from_server(send_time, func():
		# dont lerp direction, just set it directly.
		self.direction = move_dir
	)



# client -> server
@rpc("authority", "call_remote", "unreliable_ordered", Util.UNRELIABLE_ORDERED)
func sync_move_direction(move_dir: Vector2, send_time: float):
	# Smooth interpolation for non-authority players
	bufferer.do_from_client(send_time, func():
		direction = move_dir
		)


@rpc("authority", "call_remote", "unreliable_ordered", Util.UNRELIABLE_ORDERED)
func sync_rotation(rot: Vector3, send_time: float):
	bufferer.do_from_client(send_time, func():
		rotation = rot
		)


# client -> server
@rpc("authority", "call_remote", "reliable")
func sync_jump(send_time: float):
	if multiplayer.is_server() and is_on_floor():
		bufferer.do_from_client(send_time, func():
			velocity.y = jump_velocity		
			)
