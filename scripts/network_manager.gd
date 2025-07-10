extends Node
## Manages network connections for the game.


## A player connected to the server.
signal player_connected(id: int)
## A player disconnected from the server.
signal player_disconnected(id: int)
## The server has disconnected.
signal server_disconnected()

enum Mode {
	SERVER,
	CLIENT,
	OFFLINE
}

## ENet channels for packet types.
## We want to use different channels for unreliable, reliable, and unordered
## since we don't want blocking.
enum Channel {
	UNRELIABLE = 1,
	RELIABLE = 2,
	UNORDERED = 3
}

const PORT := 8080

## The current network mode.
var mode := Mode.OFFLINE


func _ready() -> void:
	multiplayer.connected_to_server.connect(_on_connected_to_server)
	multiplayer.connection_failed.connect(_on_connection_failed)
	multiplayer.peer_connected.connect(_on_peer_connected)
	multiplayer.peer_disconnected.connect(_on_peer_disconnected)
	multiplayer.server_disconnected.connect(_on_server_disconnected)


func host_game() -> void:
	var peer = ENetMultiplayerPeer.new()
	if peer.create_server(PORT, 4) != OK:
		push_error("Failed to create server on port %d" % PORT)
		return
	multiplayer.multiplayer_peer = peer
	mode = Mode.SERVER
	_debug("Server started on port %d" % PORT)

	# Debug camera for server for debugging in headfull mode.
	# TODO: Consider making server also a player in the lobby.
	if OS.is_debug_build():
		var camera = Camera3D.new()
		add_child(camera)
		camera.position = Vector3(0, 30, 0)
		camera.look_at(Vector3.ZERO)
		camera.current = true


func join_game(ip: String) -> void:
	var peer = ENetMultiplayerPeer.new()
	if peer.create_client(ip, PORT) != OK:
		push_error("Failed to connect to server at %s:%d" % [ip, PORT])
		return
	multiplayer.multiplayer_peer = peer
	_debug("Attempting to connect to server at %s:%d" % [ip, PORT])


func _on_connected_to_server() -> void:
	mode = Mode.CLIENT
	_debug("Connected to server")


func _on_connection_failed() -> void:
	_debug("Connection to server failed")


func _on_peer_connected(id: int) -> void:
	_debug("Peer connected: %d" % id)
	player_connected.emit(id)


func _on_peer_disconnected(id: int) -> void:
	_debug("Peer disconnected: %d" % id)
	player_disconnected.emit(id)


func _on_server_disconnected() -> void:
	_debug("Server disconnected")
	mode = Mode.OFFLINE
	multiplayer.multiplayer_peer = null
	server_disconnected.emit()


func _debug(message: String) -> void:
	match mode:
		Mode.SERVER:
			print("[SERVER]: %s" % message)
		Mode.CLIENT:
			print("[CLIENT]: %s" % message)
		_:
			print("[OFFLINE]: %s" % message)
