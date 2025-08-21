class_name World
extends Node3D


@export var player_scene: PackedScene
@export var ball_scene: PackedScene

@onready var overview_camera: Camera3D = %OverviewCamera
@onready var game_hud: Control = %GameHud
@onready var lobby_screen: Control = %LobbyScreen
@onready var join_button: Button = %JoinButton

var ingame_players: Array[int] = []
var ball: Ball


func _ready() -> void:
	join_button.pressed.connect(_on_join_pressed)
	NetworkManager.player_connected.connect(_on_player_connected)
	NetworkManager.player_disconnected.connect(_despawn_player)

	join_button.disabled = GameManager.state != GameManager.GameState.WAITING
	GameManager.match_started.connect(func() -> void:
		join_button.disabled = false
	)
	GameManager.match_stopped.connect(func() -> void:
		join_button.disabled = true
	)

	if multiplayer.is_server():
		for id in NetworkManager.players:
			if id != multiplayer.get_unique_id():
				_spawn_player(id)
		
		respawn_ball()
		ball = get_node_or_null("Ball")


func _on_join_pressed() -> void:
	# TODO: Assign team based on player count on each teams
	_spawn_player.rpc_id(1, multiplayer.get_unique_id())
	lobby_screen.hide()
	game_hud.show()


func _on_player_connected(id: int) -> void:
	if multiplayer.is_server():
		for pid in ingame_players:
			if pid != id:
				NetworkManager.debug("Spawning player %d for new player %d" % [pid, id])
				_spawn_player.rpc_id(id, pid)


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
	player.name = "Player_%d" % id
	player.set_multiplayer_authority(id)
	add_child(player)
	ingame_players.append(id)
	NetworkManager.debug("Spawning player %s" % player.name)

	if multiplayer.is_server():
		_spawn_player.rpc(id)
		if ingame_players.size() >= 2:
			GameManager.start_match()


@rpc("authority", "call_remote", "reliable")
func _despawn_player(id: int) -> void:
	var player = get_node_or_null("Player_%d" % id)
	if player:
		player.queue_free()
		ingame_players.erase(id)
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
