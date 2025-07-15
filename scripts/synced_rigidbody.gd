

extends RigidBody3D

class_name SyncedRigidBody3D


# server-side delta-compression
var last_position := Vector3(0,0,0)


# these are only used on client-side, for lerping.
var target_position: Vector3 = Vector3(0,0,0)
var target_linear_velocity: Vector3 = Vector3(0,0,0)
var target_angular_velocity: Vector3 = Vector3(0,0,0)
var target_rotation: Vector3 = Vector3(0,1,0)

var time_since_sync := 0.0


const EPSILON := 0.01


func _ready():
	# Only the server manages physics
	set_physics_process(multiplayer.is_server())


func _physics_process(_delta):
	# simple delta-compression:
	if global_position.distance_to(last_position) > EPSILON:
		sync_physics_state.rpc(global_position, global_rotation, linear_velocity, angular_velocity)
		last_position = self.global_position


func _process(delta):
	if not multiplayer.is_server():
		# only operate on clientside:
		# lerp towards target_position, target_rotation,
		# .... etc. (Use x as a lerp value)
		time_since_sync += delta
		var x = clamp(time_since_sync / NetworkManager.TICK_STEP, 0, 1)

		global_position = global_position.lerp(target_position, x)
		global_rotation = global_rotation.lerp(target_rotation, x)
		linear_velocity = linear_velocity.lerp(target_linear_velocity, x)
		angular_velocity = angular_velocity.lerp(target_angular_velocity, x)
		


@rpc("authority", "call_remote", "unreliable_ordered", Util.UNRELIABLE_ORDERED)
func sync_physics_state(pos: Vector3, rot: Vector3, lin_vel: Vector3, ang_vel: Vector3):
	linear_velocity = target_linear_velocity
	angular_velocity = target_angular_velocity
	global_rotation = target_rotation
	global_position = target_position

	target_position = pos
	target_linear_velocity = lin_vel
	target_angular_velocity = ang_vel
	target_rotation = rot

	time_since_sync = 0.0;

