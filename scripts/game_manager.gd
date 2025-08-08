extends Node


signal team_scored(team: Team)
signal player_scored(player_id: int)
signal match_started
signal match_stopped

enum Team {
	BLUE,
	RED
}

enum GameState {
	STOPPED,  # Match is not in progress
	PLAYING,  # Match is in progress
}

var team_scores: Dictionary[Team, int] = {
	Team.BLUE: 0,
	Team.RED: 0
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
	ball.global_position = pos
	get_tree().current_scene.add_child(ball)


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
		_update_game_state.rpc_id(id, state)
		_update_match_time.rpc_id(id, match_time)


func _on_player_disconnected(id: int) -> void:
	if multiplayer.is_server():
		player_scores.erase(id)
		_update_player_scores.rpc(player_scores)


@rpc("authority", "call_remote", "reliable")
func start_match() -> void:
	team_scores = {
		Team.BLUE: 0,
		Team.RED: 0
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

	if multiplayer.is_server():
		NetworkManager.debug("Broadcasting team join event.")
		_set_team.rpc(player_id, team)


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
