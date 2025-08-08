class_name Landmine
extends SyncedRigidBody3D


@export var explosion_effect: PackedScene

@export var explosion_force: float = 5.0
@export var explosion_radius: float = 3.0

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
		var direction = (body.global_position - global_position)
		var distance = direction.length()

		if distance < explosion_radius:
			direction = direction.normalized()
			var force = direction * explosion_force * (1.0 - (distance / explosion_radius))
			body.apply_impulse(force, global_position - body.global_position)

			# TODO: do particles here, once we have ParticlesService

			queue_free()

