extends Node


func kick(position: Vector3) -> void:
	var scene := preload("res://scenes/particles/kick/kick.tscn")
	_spawn_particles(scene.instantiate(), position)


func explosion(position: Vector3) -> void:
	var scene := preload("res://scenes/particles/explosion/explosion.tscn")
	_spawn_particles(scene.instantiate(), position)


func _spawn_particles(instance: GPUParticles3D, position: Vector3) -> void:
	instance.transform.origin = position
	instance.emitting = true
	instance.finished.connect(_destroy_particles.bind(instance))
	add_child(instance)
	NetworkManager.replicate_spawn(instance, ["transform", "emitting"])


func _destroy_particles(instance: GPUParticles3D) -> void:
	NetworkManager.replicate_destroy(instance)
