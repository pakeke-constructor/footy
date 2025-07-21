

extends RigidBody3D

class_name SyncedRigidBody3D


var bufferer: Bufferer

# server-side delta-compression
var last_position := Vector3(0,0,0)

var global_rotation_quat: Quaternion


const EPSILON := 0.01


func _ready():
	# Only the server manages physics
	bufferer = Bufferer.new(self)
	self.add_child(bufferer)

	Util.disable_physics_clientside(self)



func _physics_process(_delta):
	if multiplayer.is_server():
		# simple delta-compression
		if global_position.distance_to(last_position) > EPSILON:
			var time = NetworkManager.get_time()
			sync_rigidbody_state.rpc(
				global_position, 
				global_transform.basis.get_rotation_quaternion(),
				linear_velocity, angular_velocity,
				time
			)
			last_position = self.global_position
	else:
		global_rotation = global_rotation_quat.get_euler()




@rpc("authority", "call_remote", "unreliable_ordered", Util.UNRELIABLE_ORDERED)
func sync_rigidbody_state(pos: Vector3, rot: Quaternion, lin_vel: Vector3, ang_vel: Vector3, send_time: float):
	bufferer.lerp_from_server(send_time, "global_position", pos)
	bufferer.lerp_from_server(send_time, "global_rotation_quat", rot, Util.lerp_quarternion)
	bufferer.lerp_from_server(send_time, "linear_velocity", lin_vel)
	bufferer.lerp_from_server(send_time, "angular_velocity", ang_vel)
