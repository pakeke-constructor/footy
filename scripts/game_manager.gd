extends Node


enum Team {
	BLUE,
	RED
}

var team_scores: Dictionary[Team, int] = {
	Team.BLUE: 0,
	Team.RED: 0
}

var player_scores: Dictionary[int, int] = {}


func _ready() -> void:
	NetworkManager.player_connected.connect(_on_player_connected)
	NetworkManager.player_disconnected.connect(_on_player_disconnected)


func score_team(team: Team) -> void:
	assert(multiplayer.is_server())
	team_scores[team] += 1
	NetworkManager.debug("Team %s scored! Broadcasting team scores." % team)
	_update_team_scores.rpc(team_scores)


func score_player(player_id: int) -> void:
	assert(multiplayer.is_server())
	player_scores[player_id] += 1
	NetworkManager.debug("Player %s scored! Broadcasting player scores." % player_id)
	_update_player_scores.rpc(player_scores)


func _on_player_connected(id: int) -> void:
	if multiplayer.is_server():
		player_scores[id] = 0
		_update_team_scores.rpc_id(id, team_scores)
		_update_player_scores.rpc_id(id, player_scores)


func _on_player_disconnected(id: int) -> void:
	if multiplayer.is_server():
		player_scores.erase(id)
		_update_player_scores.rpc(player_scores)


@rpc("authority", "call_remote", "reliable")
func _update_team_scores(new_team_scores: Dictionary[Team, int]) -> void:
	team_scores = new_team_scores
	NetworkManager.debug("Team scores updated: %s" % team_scores)


@rpc("authority", "call_remote", "reliable")
func _update_player_scores(new_player_scores: Dictionary[int, int]) -> void:
	player_scores = new_player_scores
	NetworkManager.debug("Player scores updated: %s" % player_scores)
