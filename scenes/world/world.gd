class_name World
extends Node3D


@export var player_scene: PackedScene
@export var ball_scene: PackedScene

@onready var overview_camera: Camera3D = %OverviewCamera
@onready var game_hud: GameHUD = %GameHud
@onready var lobby_screen: Control = %LobbyScreen
@onready var join_button: Button = %JoinButton
@onready var players: Node = %Players

var ball: Ball


func _ready() -> void:
	join_button.pressed.connect(_on_join_pressed)
	NetworkManager.player_connected.connect(_on_player_connected)
	NetworkManager.player_disconnected.connect(_despawn_player)
	GameManager.match_stopped.connect(_on_match_stopped)

	if multiplayer.is_server():
		for id in NetworkManager.players:
			if id != multiplayer.get_unique_id():
				_spawn_player(id)
		
		respawn_ball()
		ball = get_node_or_null("Ball")


func _process(delta: float) -> void:
	if GameManager.state == GameManager.GameState.PLAYING:
		join_button.disabled = GameManager.match_time > 120.0
	else:
		join_button.disabled = false


func _on_join_pressed() -> void:
	# TODO: Assign team based on player count on each teams
	_spawn_player.rpc_id(1, multiplayer.get_unique_id())
	lobby_screen.hide()
	game_hud.show()


func _on_player_connected(id: int) -> void:
	if multiplayer.is_server():
		for pid in get_players():
			if pid != id:
				NetworkManager.debug("Spawning player %d for new player %d" % [pid, id])
				_spawn_player.rpc_id(id, pid)


func get_players() -> Array[int]:
	var player_ids: Array[int] = []
	for node in players.get_children():
		player_ids.append(int(node.name))
	return player_ids


@rpc("any_peer", "call_remote", "reliable")
func _spawn_player(id: int) -> void:
	# TODO: Make server also a player
	if id == 1:
		return

	var sender := multiplayer.get_remote_sender_id()
	if sender != id && sender != 1:
		NetworkManager.debug("Ignoring suspicious player spawn request from %d" % sender)
		return
	
	if get_node_or_null("Player_%d" % id):
		NetworkManager.debug("Player %d already exists, skipping spawn." % id)
		return

	var player = player_scene.instantiate() as Player
	player.name = str(id)
	player.set_multiplayer_authority(id)
	players.add_child(player)
	NetworkManager.debug("Spawning player %s" % player.name)

	if players.get_child_count() >= 2:
		game_hud.announce("Starting in 10 seconds!")

	if multiplayer.is_server():
		_spawn_player.rpc(id)
		if players.get_child_count() >= 2:
			await get_tree().create_timer(10.0).timeout
			GameManager.start_match()


@rpc("authority", "call_local", "reliable")
func _despawn_player(id: int) -> void:
	var player = players.get_node_or_null(str(id))
	if player:
		player.queue_free()
		NetworkManager.debug("Despawning player %s" % player.name)


func _create_new_ball(pos: Vector3):
	ball = ball_scene.instantiate()
	add_child(ball)
	ball.global_position = pos


func respawn_ball() -> void:
	assert(multiplayer.is_server())
	if not ball:
		var ball_pos: Vector3 = Vector3(randf_range(-10, 10), 5, randf_range(-10, 10))
		_create_new_ball(ball_pos)
		return
	
	ball.queue_free()
	await get_tree().create_timer(3.0).timeout
	var rand_pos: Vector3 = Vector3(randf_range(-10, 10), 5, randf_range(-10, 10))
	_create_new_ball(rand_pos)
	ball.linear_velocity = Vector3.ZERO
	ball.angular_velocity = Vector3.ZERO
	NetworkManager.debug("Ball respawned at %s" % ball.global_position)


func _on_match_stopped() -> void:
	if multiplayer.is_server():
		NetworkManager.debug("Match stopped, despawning the following players: " + str(get_players()))
		for player in get_players():
			_despawn_player.rpc(player)

	lobby_screen.visible = true
