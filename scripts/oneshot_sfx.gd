extends GPUParticles3D


func _ready() -> void:
	finished.connect(_on_finished)
	restart() # Godot sets emitting to false in the editor when one shot is enabled and the particle finishes; restart it.


func _on_finished() -> void:
	GameManager.destroy_object(get_path())
