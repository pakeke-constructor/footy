
extends Node3D

@export var player_scene: PackedScene = preload("res://scenes/player/Player.tscn")
@export var ball_scene: PackedScene = preload("res://scenes/objects/ball/Ball.tscn")


var players = {}
var physics_objects = {}


func _ready():
	NetworkManager.player_connected.connect(_on_player_connected)
	NetworkManager.player_disconnected.connect(_on_player_disconnected)

	_spawn_physics_objects()

	set_physics_process(multiplayer.is_server())



func _spawn_physics_objects():
	for i in range(0):
		var obj = ball_scene.instantiate()
		obj.position = Vector3(randf_range(-10, 10), 5, randf_range(-10, 10))
		obj.name = "PhysicsObject_" + str(i)
		add_child(obj)
		physics_objects[obj.name] = obj


func _on_player_disconnected(id: int):
	if multiplayer.is_server():
		Util.debug("Player disconnected: ", id)
		if players.has(id):
			players[id].queue_free()
			players.erase(id)



func _on_player_connected(id: int):
	if multiplayer.is_server():
		m_spawn_player.rpc(id)


@rpc("authority", "call_local", "reliable")
func m_spawn_player(id: int):
	var player = player_scene.instantiate()
	player.name = "Player_" + str(id)
	player.set_multiplayer_authority(id)
	Util.debug("player spawning!", id)

	players[id] = player
	add_child(player)
