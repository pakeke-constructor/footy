extends Node3D


@export var player_scene: PackedScene
@export var ball_scene: PackedScene

@onready var overview_camera: Camera3D = %OverviewCamera
@onready var game_hud: Control = %GameHud
@onready var team_selector: Control = %TeamSelector
@onready var join_blue_button: Button = %JoinBlue
@onready var join_red_button: Button = %JoinRed


func _ready() -> void:
	join_blue_button.pressed.connect(_on_join_blue_pressed)
	join_red_button.pressed.connect(_on_join_red_pressed)

	for id in NetworkManager.players:
		if id != multiplayer.get_unique_id():
			_spawn_player(id)
	
	_spawn_ball()


func _on_join_blue_pressed() -> void:
	GameManager.join_team(GameManager.Team.BLUE)
	_spawn_player.rpc_id(1, multiplayer.get_unique_id())
	team_selector.hide()
	game_hud.show()


func _on_join_red_pressed() -> void:
	GameManager.join_team(GameManager.Team.RED)
	_spawn_player.rpc_id(1, multiplayer.get_unique_id())
	team_selector.hide()
	game_hud.show()


@rpc("any_peer", "call_remote", "reliable")
func _spawn_ball() -> void:
	if get_node_or_null("Ball"):
		NetworkManager.debug("Ball already exists, skipping spawn.")
		return
	
	var ball = ball_scene.instantiate() as Ball
	ball.name = "Ball"
	add_child(ball)
	NetworkManager.debug("Spawning ball %s" % ball.name)


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
	NetworkManager.debug("Spawning player %s" % player.name)

	if multiplayer.is_server():
		_spawn_player.rpc(id)


@rpc("authority", "call_remote", "reliable")
func _despawn_player(id: int) -> void:
	var player = get_node_or_null("Player_%d" % id)
	if player:
		player.queue_free()
		NetworkManager.debug("Despawning player %s" % player.name)
