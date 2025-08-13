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
	STOPPED,  # Match is not in progress
	PLAYING,  # Match is in progress
}

var team_scores: Dictionary[Team, int] = {
	Team.BLUE: 0,
	Team.RED: 0,
	Team.REFEREE: 0  # Referee doesn't score, but we include it for completeness
}

var player_scores: Dictionary[int, int] = {}
var player_teams: Dictionary[int, Team] = {}

var state: GameState = GameState.STOPPED
var ball: Ball
var match_time: float = 0.0


func _ready() -> void:
	NetworkManager.player_connected.connect(_on_player_connected)
	NetworkManager.player_disconnected.connect(_on_player_disconnected)


func _physics_process(delta: float) -> void:
	if multiplayer.is_server() and state == GameState.PLAYING:
		match_time += delta
		_update_match_time.rpc(match_time)


func join_team(team: Team) -> void:
	_set_team.rpc_id(1, multiplayer.get_unique_id(), team)


@rpc("authority", "call_remote", "reliable")
func score_team(team: Team) -> void:
	team_scores[team] += 1
	NetworkManager.debug("Team %s scored!" % team)
	team_scored.emit(team)
	if multiplayer.is_server():
		NetworkManager.debug("Broadcasting score event.")
		score_team.rpc(team)


@rpc("authority", "call_remote", "reliable")
func score_player(player_id: int) -> void:
	if player_id == -1:
		return
	player_scores[player_id] += 1
	NetworkManager.debug("Player %s scored!" % player_id)
	player_scored.emit(player_id)
	if multiplayer.is_server():
		NetworkManager.debug("Broadcasting score event.")
		score_player.rpc(player_id)


func _create_new_ball(pos: Vector3):
	var ball_scene = preload("res://scenes/objects/ball/Ball.tscn")
	ball = ball_scene.instantiate()
	get_tree().current_scene.add_child(ball)
	ball.global_position = pos


func respawn_ball() -> void:
	assert(multiplayer.is_server())
	if not ball:
		var ball_pos: Vector3 = Vector3(randf_range(-10, 10), 5, randf_range(-10, 10))
		_create_new_ball(ball_pos)
		return
	
	var ball_parent = ball.get_parent()
	ball.queue_free()
	await get_tree().create_timer(3.0).timeout
	var rand_pos: Vector3 = Vector3(randf_range(-10, 10), 5, randf_range(-10, 10))
	_create_new_ball(rand_pos)
	ball_parent.add_child(ball)
	ball.linear_velocity = Vector3.ZERO
	ball.angular_velocity = Vector3.ZERO
	ball.last_player_id = -1
	NetworkManager.debug("Ball respawned at %s" % ball.global_position)


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


# Returns a dictionary with the count of players on each team
func _get_team_counts() -> Dictionary[Team, int]:
	var counts: Dictionary[Team, int] = {
		Team.BLUE: 0,
		Team.RED: 0,
		Team.REFEREE: 0
	}
	
	for team in player_teams.values():
		counts[team] += 1
	
	return counts


# Not used for now, but we may need it to reshuffle teams when starting a new match
func reshuffle_teams() -> void:
	if not multiplayer.is_server():
		return
	
	var all_players = player_teams.keys()
	all_players.shuffle()
	
	var total_players = all_players.size()
	var needs_referee = total_players % 2 != 0
	
	# Calculate how many players should be on each team
	var blue_count = total_players / 2
	var red_count = total_players / 2
	
	if needs_referee:
		blue_count = (total_players - 1) / 2
		red_count = (total_players - 1) / 2
		
		# Assign referee (last player in shuffled list)
		var referee_id = all_players.back()
		change_team(referee_id, Team.REFEREE)
		all_players.pop_back()  # Remove referee from the list for team assignment
	else:
		# If we don't need a referee but have one, reassign them
		var counts = _get_team_counts()
		if counts[Team.REFEREE] > 0:
			for player_id in all_players.duplicate():
				if player_teams[player_id] == Team.REFEREE:
					# Keep them in the list for reassignment
					player_teams[player_id] = Team.BLUE  # Temporary assignment
	
	# Now assign remaining players to teams
	for i in range(all_players.size()):
		var player_id = all_players[i]
		var team = Team.BLUE if i < blue_count else Team.RED
		
		# Only update and emit signal if team is changing
		if player_teams[player_id] != team:
			change_team(player_id, team)
	
	# Broadcast the updated team assignments to all clients
	_update_player_teams.rpc(player_teams)
	NetworkManager.debug("Teams reshuffled randomly")



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
	state = GameState.STOPPED
	match_stopped.emit()

	if multiplayer.is_server():
		stop_match.rpc()


@rpc("any_peer", "call_remote", "reliable")
func _set_team(player_id: int, team: Team) -> void:
	var sender := multiplayer.get_remote_sender_id()
	if sender != player_id && sender != 1:
		NetworkManager.debug("Ignoring suspicious team change request from %d" % sender)
		return

	player_teams[player_id] = team
	NetworkManager.debug("Player %s joined team %s" % [player_id, team])
	
	# Emit signal that team assignments changed
	team_assignment_changed.emit(player_id, team)

	if multiplayer.is_server():
		_update_player_teams.rpc(player_teams)


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
