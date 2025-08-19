extends Node


func kick(position: Vector3) -> void:
	var scene := preload("res://scenes/particles/kick/kick.tscn")
	var instance: Node3D = scene.instantiate()
	instance.transform.origin = position
	add_child(instance)


func explosion(position: Vector3) -> void:
	var scene := preload("res://scenes/particles/explosion/explosion.tscn")
	var instance: Node3D = scene.instantiate()
	instance.transform.origin = position
	add_child(instance)
