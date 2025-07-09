
extends Area3D


signal server_collide(body: RigidBody3D)


func _ready():
    body_entered.connect(_on_body_entered)
    monitoring = true


func _on_body_entered(body: Node3D):
    if body is RigidBody3D:
        server_collide.emit(body)


