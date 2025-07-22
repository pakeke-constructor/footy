
extends Node
## Manages network connections for the game.



# 
# @rpc(
#     "authority"|"any_peer", 
#     "call_remote"|"call_local", 
#     "unreliable"|"reliable"|"unreliable_ordered", 
#     channel=0
# )
#




## VVV THIS IS THE MOST IMPORTANT VARIABLE IN THE ENTIRE CODEBASE.
const CLIENT_RTT = 0.1
# CLIENT_RTT is the artificial delay between player-input and server-reaction

# EG a CLIENT_RTT is 0.10 seconds, our systems will insert an "artificial" delay in, 
# so that the game feels consistent across all different pings.
# (For example 0.1 CLIENT_RTT =  100ms ping.)






## A player connected to the server.
signal player_connected(id: int)
## A player disconnected from the server.
signal player_disconnected(id: int)
## The server has disconnected.
signal server_disconnected()


## A tick has occured serverside. tickrate is generally constant, like 30 or 60 TPS.
signal server_tick(tick_number: int, time)



enum Mode {
	SERVER,
	CLIENT,
	OFFLINE
}


const PORT := 8080

## The current network mode.
var mode := Mode.OFFLINE

## Players connected to the server.
# TODO: Consider using a dataclass instead of a Dictionary for each player, and define the content.
var players: Dictionary[int, Dictionary] = {}

## Clientside player data to send to the server for announcing the player.
var player_data: Dictionary = {}


## World-time.
# The server keeps track of the current-time, and replicates it to client-side.
# Ideally, the server-time and client-time should be exactly equal across computers.
var time: float = 0.0

# A list of most recent times that are sent from the server.
# this smoothes out variance and network hitches
const TIME_BUFFER_SIZE := 10;
var time_buffer: Array[float] = []



# server-variables:
const TICKRATE = 30.0
const TICK_STEP := 1.0 / TICKRATE
# Server tickrate; X ticks per second.

var tick_number : int = 0
var time_since_tick = 0.0



func _ready() -> void:
	for i in range(TIME_BUFFER_SIZE):
		time_buffer.append(0.0)

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
	debug("Server started on port %d" % PORT)

	# Debug camera for server for debugging in headfull mode.
	# TODO: Consider making server also a player in the lobby.
	if OS.is_debug_build():
		var camera := Camera3D.new()
		add_child(camera)
		camera.position = Vector3(0, 30, 0)
		camera.look_at(Vector3.ZERO + Vector3(0.01, 0.01, 0.01))
		camera.current = true


func join_game(ip: String) -> void:
	var peer = ENetMultiplayerPeer.new()
	if peer.create_client(ip, PORT) != OK:
		push_error("Failed to connect to server at %s:%d" % [ip, PORT])
		return
	multiplayer.multiplayer_peer = peer
	debug("Attempting to connect to server at %s:%d" % [ip, PORT])


func _on_connected_to_server() -> void:
	mode = Mode.CLIENT
	debug("Connected to server")
	_broadcast_player.rpc_id(1, multiplayer.get_unique_id(), var_to_str(player_data))


func _on_connection_failed() -> void:
	debug("Connection to server failed")


func _on_peer_connected(id: int) -> void:
	debug("Peer connected: %d" % id)
	# player_connected.emit(id)


func _on_peer_disconnected(id: int) -> void:
	debug("Peer disconnected: %d" % id)
	player_disconnected.emit(id)
	players.erase(id)


func _on_server_disconnected() -> void:
	debug("Server disconnected")
	mode = Mode.OFFLINE
	multiplayer.multiplayer_peer = null
	server_disconnected.emit()
	players.clear()


func debug(message: String) -> void:
	match mode:
		Mode.SERVER:
			print("[SERVER]: %s" % message)
		Mode.CLIENT:
			print("(cl): %s" % message) # different makes it more readable
		Mode.OFFLINE:
			print("[OFFLINE]: %s" % message)



func _process(dt: float) -> void:
	# Increment world-time.
	time += dt

	match mode:
		Mode.CLIENT:
			for i in range(time_buffer.size()):
				time_buffer[i] += dt
		Mode.SERVER:
			if time_since_tick > TICK_STEP:
				server_tick.emit(tick_number)
				tick_number += 1
				# min, since if the server is lagging, we dont want it to get cooked.
				time_since_tick = 0.0
				_tick.rpc(tick_number, time)
			else:
				time_since_tick += dt;


@rpc("any_peer", "call_remote", "reliable")
func _broadcast_player(id: int, player_data_str: String) -> void:
	debug("Broadcasting player %d data to all peers" % id)
	# TODO: FIXME: this is extremely fragile, we are trusting client to send arbitrary JSON.
	# This should to be fixed at some point, If a bad actor sends malformed json it could crash server in the future
	_register_player.rpc(id, player_data_str)


@rpc("authority", "call_local", "reliable")
func _register_player(id: int, player_data_str: String) -> void:
	debug("Registering player %d with data: %s" % [id, player_data_str])
	players[id] = str_to_var(player_data_str)
	player_connected.emit(id)


func get_rtt(peer_id: int):
	var emp: ENetMultiplayerPeer = multiplayer.multiplayer_peer
	var peer : ENetPacketPeer = emp.get_peer(peer_id)
	var rtt = peer.get_statistic(peer.PEER_ROUND_TRIP_TIME) / 1000.0
	# ^^^ *AVERAGE* RTT for a reliable packet.
	return rtt


func get_sender_rtt():
	var peer_id : int = multiplayer.get_remote_sender_id()
	return get_rtt(peer_id)


@rpc("authority", "call_remote", "unreliable_ordered", Util.UNRELIABLE_ORDERED)
func _tick(tck_number: int, server_time: float) -> void:
	var rtt = get_sender_rtt()
	var now_time = server_time + (rtt / 2.0)
	time_buffer.push_back(now_time)
	time_buffer.pop_front()

	var sum = 0
	for x in time_buffer:
		sum += x
	time = sum / time_buffer.size()

	tick_number = tck_number


func get_time():
	return time
