
extends RigidBody3D

var last_position: Vector3
var last_velocity: Vector3
var sync_timer: float = 0.0
var sync_interval: float = 0.1  # 10 times per second

func _ready():
    # Only the server manages physics
    if multiplayer.is_server():
        set_lock_rotation_enabled(false)

func _physics_process(delta):
    if not multiplayer.is_server():
        return
    
    sync_timer += delta
    
    # Check if object moved significantly or timer expired
    if sync_timer >= sync_interval or global_position.distance_to(last_position) > 0.1:
        sync_timer = 0.0
        last_position = global_position
        last_velocity = linear_velocity
        
        sync_physics_state(global_position, linear_velocity, angular_velocity)


@rpc("authority", "unreliable")
func sync_physics_state(pos: Vector3, lin_vel: Vector3, ang_vel: Vector3):
    if multiplayer.is_server():
        return
    
    # Smooth interpolation for clients
    var tween = create_tween()
    tween.parallel().tween_property(self, "global_position", pos, sync_interval)
    linear_velocity = lin_vel
    angular_velocity = ang_vel

