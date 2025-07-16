class_name Goal
extends Area3D


func _ready() -> void:
	body_entered.connect(_on_body_entered)


func _on_body_entered(body: Node3D) -> void:
	# Ensure the server is authoritative.
	if multiplayer.is_server():
		if body is Ball:
			NetworkManager.debug("Goal!!!")

