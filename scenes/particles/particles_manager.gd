extends Node


func kick(position: Vector3) -> void:
	var scene := preload("res://scenes/particles/kick/kick.tscn")
	_spawn_particles(scene.instantiate(), position)


func explosion(position: Vector3) -> void:
	var scene := preload("res://scenes/particles/explosion/explosion.tscn")
	_spawn_particles(scene.instantiate(), position)


func _spawn_particles(instance: Node3D, position: Vector3) -> void:
	instance.transform.origin = position
	add_child(instance)
