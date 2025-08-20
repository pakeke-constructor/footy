class_name SyncedParticles3D
extends GPUParticles3D


func _ready() -> void:
	finished.connect(_on_finished)
	if multiplayer.is_server():
		NetworkManager.replicate_spawn(self, ["transform"])
	restart() # Godot sets emitting to false in the editor when one shot is enabled and the particle finishes; restart it.


func _on_finished() -> void:
	if multiplayer.is_server():
		NetworkManager.replicate_destroy(self)
