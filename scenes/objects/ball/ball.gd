class_name Ball
extends SyncedRigidBody3D


var last_player_id: int = -1


var bouncy_material = PhysicsMaterial.new()

func _ready() -> void:
	super() # calls _ready

	bouncy_material.bounce = 0.87  # Values > 1.0 for extra bouncy
	bouncy_material.friction = 0.5  # Low friction for realistic ball behavior

	physics_material_override = bouncy_material



func _physics_process(_dt):
	super._physics_process(_dt)



