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
			# TODO: Check who last touched the ball
			GameManager.score_team(team)
			if body.last_player_id != -1:
				GameManager.score_player(body.last_player_id)

