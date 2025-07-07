
extends Node3D

@export var player_scene: PackedScene = preload("res://scenes/player/Player.tscn")
@export var ball_scene: PackedScene = preload("res://scenes/objects/ball/Ball.tscn")


var players = {}
var physics_objects = {}


func _ready():
    multiplayer.peer_connected.connect(_on_peer_connected)
    multiplayer.peer_disconnected.connect(_on_peer_disconnected)

    _spawn_physics_objects()


func _spawn_physics_objects():
    for i in range(5):
        var obj = ball_scene.instantiate()
        obj.position = Vector3(randf_range(-10, 10), 5, randf_range(-10, 10))
        obj.name = "PhysicsObject_" + str(i)
        add_child(obj)
        physics_objects[obj.name] = obj


func _on_peer_disconnected(id: int):
    if multiplayer.is_server():
        Util.debug("Player disconnected: ", id)
        if players.has(id):
            players[id].queue_free()
            players.erase(id)



func _on_peer_connected(id: int):
    if multiplayer.is_server():
        m_spawn_player.rpc(id)


# 
# @rpc(
#     "authority"|"any_peer", 
#     "call_remote"|"call_local", 
#     "unreliable"|"reliable"|"unreliable_ordered", 
#     channel=0
# )
#

@rpc("authority", "call_local", "reliable")
func m_spawn_player(id: int):
    var player = player_scene.instantiate()
    player.name = "Player_" + str(id)
    player.set_multiplayer_authority(id)
    Util.debug("player spawning!", id)

    players[id] = player
    add_child(player)





func host_game():
    Util.await_ready(self)
    var peer = ENetMultiplayerPeer.new()
    peer.create_server(8080, 4)
    multiplayer.multiplayer_peer = peer
    get_window().title = "SERVER"

    # create debug camera.
    # (Nice way to detect desyncs)
    if OS.is_debug_build():
        var camera = Camera3D.new()
        add_child(camera)
        camera.transform.origin = Vector3(0, 30, 0)
        camera.look_at(Vector3(0, 0, 0))
        camera.current = true
        Input.mouse_mode = Input.MOUSE_MODE_VISIBLE

    Util.debug("Server started")



func join_game(ip: String):
    Util.await_ready(self)
    var peer = ENetMultiplayerPeer.new()
    peer.create_client(ip, 8080)
    multiplayer.multiplayer_peer = peer

    get_window().title = "CLIENT"

    Util.debug("Connecting to server...")
