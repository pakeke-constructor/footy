extends Node


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


@rpc("authority", "call_remote", "reliable")
func score_team(team: Team) -> void:
	team_scores[team] += 1
	NetworkManager.debug("Team %s scored!" % team)
	if multiplayer.is_server():
		NetworkManager.debug("Broadcasting score event.")
		score_team.rpc(team)


@rpc("authority", "call_remote", "reliable")
func score_player(player_id: int) -> void:
	player_scores[player_id] += 1
	NetworkManager.debug("Player %s scored!" % player_id)
	if multiplayer.is_server():
		NetworkManager.debug("Broadcasting score event.")
		score_player.rpc(player_id)


@rpc("authority", "call_local", "reliable")
func respawn_ball() -> void:
	if not ball:
		return

	var ball_parent = ball.get_parent()
	ball_parent.remove_child(ball)
	await get_tree().create_timer(3.0).timeout
	ball_parent.add_child(ball)
	ball.global_position = Vector3(randf_range(-10, 10), 5, randf_range(-10, 10))
	ball.linear_velocity = Vector3.ZERO
	ball.angular_velocity = Vector3.ZERO
	ball.last_player_id = -1
	NetworkManager.debug("Ball respawned at %s" % ball.global_position)


# TODO: Test with spawning multiple objects from the same scene path.
@rpc("authority", "call_remote", "reliable")
func spawn_object(scene_path: String, position: Vector3, rotation: Vector3 = Vector3.ZERO) -> void:
	var scene = load(scene_path) as PackedScene
	if not scene:
		push_error("Failed to load scene: %s" % scene_path)
		return

	var instance = scene.instantiate() as Node
	get_tree().current_scene.add_child(instance)
	instance.global_position = position
	instance.global_rotation = rotation
	NetworkManager.debug("Spawned %s at %s" % [instance.name, position])

	if multiplayer.is_server():
		spawn_object.rpc(scene_path, position, rotation)


@rpc("authority", "call_local", "reliable")
func destroy_object(node_path: NodePath) -> void:
	var node = get_tree().current_scene.get_node(node_path)
	if not node:
		NetworkManager.error("Node not found: %s" % node_path)
		return
	
	node.queue_free()
	NetworkManager.debug("Destroyed object at path: %s" % node_path)


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

	if multiplayer.is_server():
		start_match.rpc()


@rpc("authority", "call_remote", "reliable")
func stop_match() -> void:
	state = GameState.STOPPED

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
