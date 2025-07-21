class_name Landmine
extends SyncedRigidBody3D


@export var explosion_force: float = 5.0

@onready var detector: Area3D = $Detector


func _ready() -> void:
	super()
	detector.body_entered.connect(_on_body_entered)


func _physics_process(delta):
	super._physics_process(delta)


func _on_body_entered(body: Node) -> void:
	if !multiplayer.is_server():
		return
	
	if body == self:
		return
	
	if body is SyncedRigidBody3D:
		var force_direction = (body.global_position - global_position).normalized()
		body.apply_impulse(force_direction * explosion_force, body.global_position - global_position)
		NetworkManager.debug("Boom!")
		_despawn.rpc()


@rpc("authority", "call_local", "reliable")
func _despawn() -> void:
	queue_free()
