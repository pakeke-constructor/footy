class_name Goal
extends Area3D


## The team tha gets the score when a ball enters this goal.
@export var team: GameManager.Team


func _ready() -> void:
	body_entered.connect(_on_body_entered)


func _on_body_entered(body: Node3D) -> void:
	# Ensure the server is authoritative.
	if multiplayer.is_server():
		if body is Ball:
			# TODO: Implement referee behavior (rules to be fleshed out)
			GameManager.score_team(team)
			GameManager.respawn_ball()


