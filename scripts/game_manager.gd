extends Node


enum Team {
	BLUE,
	RED
}

var team_scores: Dictionary[Team, int] = {
	Team.BLUE: 0,
	Team.RED: 0
}


func _ready() -> void:
	NetworkManager.player_connected.connect(_on_player_connected)


func score(team: Team) -> void:
	assert(multiplayer.is_server())
	team_scores[team] += 1
	NetworkManager.debug("Team %s scored! Broadcasting scores." % team)
	_update_scores.rpc(team_scores)


func _on_player_connected(id: int) -> void:
	if multiplayer.is_server():
		_update_scores.rpc_id(id, team_scores)


@rpc("authority", "call_remote", "reliable")
func _update_scores(scores: Dictionary[Team, int]) -> void:
	team_scores = scores
	NetworkManager.debug("Scores updated: %s" % str(team_scores))
