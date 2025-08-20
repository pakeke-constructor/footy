extends Node


signal team_scored(team: Team)
signal player_scored(player_id: int)
signal match_started
signal match_stopped
signal team_assignment_changed(player_id: int, team: Team)

enum Team {
	BLUE,
	RED,
	REFEREE
}

enum GameState {
	WAITING,	## Waiting for players
	PLAYING,	## Match is in progress
}

var team_scores: Dictionary[Team, int] = {
	Team.BLUE: 0,
	Team.RED: 0,
	Team.REFEREE: 0  # Referee doesn't score, but we include it for completeness
}

var player_scores: Dictionary[int, int] = {}
var player_teams: Dictionary[int, Team] = {}

var state: GameState = GameState.WAITING
var match_time: float = 0.0


func _ready() -> void:
	NetworkManager.player_connected.connect(_on_player_connected)
	NetworkManager.player_disconnected.connect(_on_player_disconnected)


func _physics_process(delta: float) -> void:
	if multiplayer.is_server() and state == GameState.PLAYING:
		match_time += delta
		_update_match_time.rpc(match_time)


@rpc("authority", "call_remote", "reliable")
func score_team(team: Team) -> void:
	if state != GameState.PLAYING:
		return

	team_scores[team] += 1
	for id in player_teams:
		if player_teams[id] == team:
			player_scores[id] += 1
			player_scored.emit(id)
	NetworkManager.debug("Team %s scored!" % team)
	team_scored.emit(team)
	if multiplayer.is_server():
		NetworkManager.debug("Broadcasting score event.")
		score_team.rpc(team)


func get_world() -> World:
	return get_tree().current_scene as World


func _on_player_connected(id: int) -> void:
	if multiplayer.is_server():
		player_scores[id] = 0
		_update_team_scores.rpc_id(id, team_scores)
		_update_player_scores.rpc(player_scores)
		_update_player_teams.rpc(player_teams)
		_update_game_state.rpc_id(id, state)
		_update_match_time.rpc_id(id, match_time)


func _on_player_disconnected(id: int) -> void:
	if multiplayer.is_server():
		player_scores.erase(id)
		player_teams.erase(id)
		_update_player_scores.rpc(player_scores)
		_update_player_teams.rpc(player_teams)


func reshuffle_teams() -> void:
	if not multiplayer.is_server():
		return
	
	var all_players := get_world().ingame_players
	all_players.shuffle()
	
	var total_players = all_players.size()
	var needs_referee = total_players % 2 != 0
	var team_size = total_players / 2

	if needs_referee:
		var ref_id = all_players.pop_back()
		change_team(ref_id, Team.REFEREE)
	
	for i in all_players.size():
		var id := all_players[i]
		var team := Team.BLUE if i < team_size else Team.RED
		if player_teams[id] != team:
			change_team(id, team)
	
	_update_player_teams.rpc(player_teams)
	NetworkManager.debug("Teams reshuffled")


func change_team(player_id: int, new_team: Team) -> void:
	player_teams[player_id] = new_team
	team_assignment_changed.emit(player_id, new_team)


@rpc("authority", "call_remote", "reliable")
func start_match() -> void:
	team_scores = {
		Team.BLUE: 0,
		Team.RED: 0,
		Team.REFEREE: 0
	}
	state = GameState.PLAYING
	match_time = 0.0
	match_started.emit()

	if multiplayer.is_server():
		start_match.rpc()


@rpc("authority", "call_remote", "reliable")
func stop_match() -> void:
	state = GameState.WAITING
	match_stopped.emit()

	if multiplayer.is_server():
		stop_match.rpc()


@rpc("authority", "call_remote", "reliable")
func _update_team_scores(new_team_scores: Dictionary[Team, int]) -> void:
	team_scores = new_team_scores
	NetworkManager.debug("Team scores updated: %s" % team_scores)


@rpc("authority", "call_remote", "reliable")
func _update_player_scores(new_player_scores: Dictionary[int, int]) -> void:
	player_scores = new_player_scores
	NetworkManager.debug("Player scores updated: %s" % player_scores)


@rpc("authority", "call_remote", "reliable")
func _update_game_state(new_state: GameState) -> void:
	state = new_state
	NetworkManager.debug("Game state updated: %s" % state)


@rpc("authority", "call_remote", "unreliable_ordered")
func _update_match_time(new_time: float) -> void:
	match_time = new_time


@rpc("authority", "call_remote", "reliable")
func _update_player_teams(new_player_teams: Dictionary) -> void:
	for player_id in new_player_teams:
		change_team(player_id, new_player_teams[player_id])

	NetworkManager.debug("Player teams updated: %s" % player_teams)
