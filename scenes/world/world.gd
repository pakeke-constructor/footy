extends Node3D


@export var player_scene: PackedScene
@export var ball_scene: PackedScene

@onready var overview_camera: Camera3D = %OverviewCamera
@onready var game_hud: Control = %GameHud
@onready var join_blue_button: Button = %JoinBlue
@onready var join_red_button: Button = %JoinRed


func _ready() -> void:
	join_blue_button.pressed.connect(_on_join_blue_pressed)
	join_red_button.pressed.connect(_on_join_red_pressed)

	for id in NetworkManager.players:
		if id != multiplayer.get_unique_id():
			_spawn_player(id)


func _on_join_blue_pressed() -> void:
	pass # TODO: Implement


func _on_join_red_pressed() -> void:
	pass # TODO: Implement


@rpc("authority", "call_remote", "reliable")
func _spawn_player(id: int) -> void:
	# TODO: Make server also a player
	if id == 1:
		return

	var player = player_scene.instantiate() as Player
	player.name = "Player_%d" % id
	player.set_multiplayer_authority(id)
	add_child(player)
	NetworkManager.debug("Spawning player %s" % player.name)


@rpc("authority", "call_remote", "reliable")
func _despawn_player(id: int) -> void:
	var player = get_node_or_null("Player_%d" % id)
	if player:
		player.queue_free()
		NetworkManager.debug("Despawning player %s" % player.name)
