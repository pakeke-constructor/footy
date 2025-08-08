
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
const CLIENT_RTT = 0.03
# CLIENT_RTT is the artificial delay between player-input and server-reaction

# EG a CLIENT_RTT is 0.10 seconds, our systems will insert an "artificial" delay in, 
# so that the game feels consistent across all different pings.
# (For example 0.1 CLIENT_RTT =  100ms ping.)






## A player connected to the server.
signal player_connected(id: int)
## A player disconnected from the server.
signal player_disconnected(id: int)
## The server has connected to the client.
signal server_connected()
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
var players: Array[int] = []


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
	# NOTE: Can't just do `players = multiplayer.get_peers()` because it returns a PackedInt32Array.
	players = []
	for i in multiplayer.get_peers():
		players.append(i)
	players.append(multiplayer.get_unique_id())
	server_connected.emit()


func _on_connection_failed() -> void:
	debug("Connection to server failed")



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











#####################################################
# ---------------------------------------------------
# Node spawning/despawning.
#  (server authoritative)
# ---------------------------------------------------
#####################################################

var scene_cache = {} # [scene-path] -> PackedScene
# (so we dont load a new scene every time we spawn new obj)


var current_id = 1000

# It must be a Variant, because free'd nodes "dont count" as variants apparently
var id_to_node: Dictionary[int, Variant] = {}
var node_to_id: Dictionary[Variant, int] = {}

var node_to_properties: Dictionary[Variant, Array] = {}
# (We need this for replicating to clients later on, in _on_peer_connected)


func _clear_node_id(node) -> void:
	if node in node_to_id:
		var id = node_to_id[node]
		node_to_id.erase(node)
		id_to_node.erase(id)



func replicate_spawn(node: Node, properties: Array[String]) -> void:
	assert(multiplayer.is_server())
	debug("Replicating spawn: %s" % node.get_path())

	var id = current_id
	current_id += 1 # simple increment is fine and robust

	id_to_node[id] = node
	node_to_id[node] = id
	node_to_properties[node] = properties

	var property_dict: Dictionary[String, Variant] = {}
	for prop in properties:
		property_dict[prop] = node.get(prop)
	_PRIVATE_spawn_node.rpc(node.get_scene_file_path(), id, property_dict)



func replicate_destroy(node):
	assert(multiplayer.is_server())
	if is_instance_valid(node) and (not node.is_queued_for_deletion()):
		# queue-free it, if its not already queued.
		node.queue_free()

	if node in node_to_id:
		var id = node_to_id[node]
		_PRIVATE_destroy_node.rpc(id)
		_clear_node_id(node)




@rpc("authority", "call_remote", "reliable")
func _PRIVATE_spawn_node(scene_path: String, network_id: int, property_dict: Dictionary[String, Variant]) -> void:
	# WARNING::: DO NOT UNDER ANY CIRCUMSTANCES CALL THIS DIRECTLY.
	# it will mess shit up.
	var scene: PackedScene
	if scene_cache.has(scene_path):
		scene = scene_cache[scene_path]
	else:
		scene = load(scene_path) as PackedScene
		if not scene:
			push_error("Failed to load scene: %s" % scene_path)
			return
		scene_cache[scene_path] = scene

	var node: Node = scene.instantiate() as Node
	get_tree().current_scene.add_child(node)
	debug("Spawned %s, with properties: %s" % [node.get_path(), property_dict])

	node_to_id[node] = network_id
	id_to_node[network_id] = node

	for property_name in property_dict:
		if node.has_method("set_" + property_name) or property_name in node:
			node.set(property_name, property_dict[property_name])
		else:
			push_warning("Property '%s' not found on %s" % [property_name, node.name])



@rpc("authority", "call_remote", "reliable")
func _PRIVATE_destroy_node(network_id: int) -> void:
	var node: Node = id_to_node.get(network_id, null)
	if not node:
		debug("Node not found: %s" % network_id)
		return
	
	node.queue_free()
	_clear_node_id(node)
	debug("Destroyed object at path: %s" % network_id)




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

			# replicate destroy on any nodes that have been free'd:
			# (this means that we can call `queue_free()` on server-side and just forget about it; AMAZING.)
			var dead_nodes = []
			for node in node_to_id:
				if not is_instance_valid(node):
					dead_nodes.append(node)
			for node in dead_nodes:
				replicate_destroy(node)



func _on_peer_connected(id: int) -> void:
	debug("Peer connected: %d" % id)
	players.append(id)
	player_connected.emit(id)

	# The clients that just joined wont have received the previous events! Lets replicate stuff.
	if multiplayer.is_server():
		for node in node_to_id:
			if is_instance_valid(node):
				# replicate all existing nodes
				replicate_spawn(node, node_to_properties[node])


func _on_peer_disconnected(id: int) -> void:
	debug("Peer disconnected: %d" % id)
	player_disconnected.emit(id)
	players.erase(id)





func get_time():
	return time
