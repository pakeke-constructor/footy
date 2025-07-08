
extends CharacterBody3D

@export var speed = 5.0
@export var jump_velocity = 4.5

var gravity = ProjectSettings.get_setting("physics/3d/default_gravity")
var player_id: int

func _ready():
    player_id = get_multiplayer_authority()

    if is_multiplayer_authority():
        # Capture mouse for local player
        Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
        $Camera3D.current = true
    else:
        set_physics_process(false)
        set_process_input(false)
        $Camera3D.current = false

        var shape : CapsuleShape3D = $CapsuleShape.shape
        shape.radius *= 1.9
        shape.height *= 1.9
        # Collision size should be slightly bigger on server.
        # This ensures that we dont get lagback/jitters.


func _physics_process(delta):
    if not is_multiplayer_authority():
        return
    
    # Handle gravity
    if not is_on_floor():
        velocity.y -= gravity * delta
    
    # Handle jump
    if Input.is_action_just_pressed("ui_accept") and is_on_floor():
        velocity.y = jump_velocity
    
    # Handle movement
    var input_dir = Input.get_vector("move_left", "move_right", "move_forward", "move_back")
    var direction = (transform.basis * Vector3(input_dir.x, 0, input_dir.y)).normalized()
    
    if direction:
        velocity.x = direction.x * speed
        velocity.z = direction.z * speed
    else:
        velocity.x = move_toward(velocity.x, 0, speed)
        velocity.z = move_toward(velocity.z, 0, speed)
    
    move_and_slide()
    
    # Sync position to other players
    sync_player_state.rpc(global_position, velocity)



const MOUSE_SENSITIVITY = 0.001


func _input(event):
    if event is InputEventMouseMotion:
        var camera = $Camera3D
        rotate_y(-event.relative.x * MOUSE_SENSITIVITY)
        camera.rotate_x(-event.relative.y * MOUSE_SENSITIVITY)
        camera.rotation.x = clamp(camera.rotation.x, -PI/2, PI/2)

    elif event is InputEventMouseButton:
        if event.button_index == 1:
            pass # kick ball, use tool, do something?

            





@rpc("any_peer", "unreliable")
func sync_player_state(pos: Vector3, vel: Vector3):
    if is_multiplayer_authority():
        return
    
    # Smooth interpolation for non-authority players
    var tween = create_tween()
    tween.tween_property(self, "global_position", pos, 0.1)
    velocity = vel
