

extends Node

class_name Bufferer


# Internal structure to hold buffered events
class BufferedEvent:
	var execute_time: float
	var execute_func: Callable
	
	func _init(time: float, func_callable: Callable):
		execute_time = time
		execute_func = func_callable




var _node: Node3D

var _buffer: HeapQueue = HeapQueue.new(func(ev1:BufferedEvent, ev2:BufferedEvent): return ev1.execute_time < ev2.execute_time)



var _lerps: Dictionary = {} # [property] -> target lerp values
var _times: Dictionary = {} # [property] -> current lerp time [0,1]



func _init(node3d: Node3D):
	_node = node3d



func _add(time_when_should_execute: float, execute_func: Callable) -> void:
	var ev = BufferedEvent.new(time_when_should_execute, execute_func)
	# TODO: ^^^^ this is a bit inefficient, as it incurs an allocation.
	# If there are perf issues in future maybe take a look at this.
	_buffer.add(ev)


func do_from_client(send_time: float, execute_func: Callable) -> void:
	assert(multiplayer.is_server())
	_add(send_time + NetworkManager.CLIENT_RTT/2.0, execute_func)


# use this for interpolating values sent from the server.
func lerp_from_server(send_time: float, property: String, val) -> void:
	assert(not multiplayer.is_server())
	# we subtract `TICK_STEP` because we interpolate over TICK_STEP duration
	_add(send_time + (NetworkManager.CLIENT_RTT/2.0) - NetworkManager.TICK_STEP, 
		func():
			if _lerps.has(property):
				# if there's an existing lerp; 
				# jump to the lerp target. Assuming packets are flowing smoothly,
				# this shouldn't be a big jump at all.
				_node[property] = _lerps[property]
			_times[property] = 0
			_lerps[property] = val
	)


func do_from_server(send_time: float, execute_func: Callable) -> void:
	# used for instantaneous events
	assert(not multiplayer.is_server())
	_add(send_time + (NetworkManager.CLIENT_RTT/2.0), execute_func)



func _process(dt:float) -> void:
	var i = 0;
	var world_time = NetworkManager.get_time()
	while _buffer.size() > 0 and _buffer.peek().execute_time <= world_time:
		var ev = _buffer.pop()
		ev.execute_func.call()
		i += 1
		if (i > 5000): # just for safety.
			push_error("Too many events in queue!")

	# progress ALL lerped properties
	for prop in _lerps.keys():
		var t = clamp(_times[prop] + dt/NetworkManager.TICK_STEP, 0, 1)
		_times[prop] = t
		_node[prop] = lerp(_node[prop], _lerps[prop], t)
