

class_name NetworkBufferer

extends RefCounted

# Internal structure to hold buffered events
class BufferedEvent:
	var execute_time: float
	var execute_func: Callable
	
	func _init(time: float, func_callable: Callable):
		execute_time = time
		execute_func = func_callable


var _buffer: HeapQueue = HeapQueue.new(func(ev1:BufferedEvent, ev2:BufferedEvent): return ev1.execute_time < ev2.execute_time)


func add(time_when_should_execute: float, execute_func: Callable) -> void:
	var ev = BufferedEvent.new(time_when_should_execute, execute_func)
	# TODO: ^^^^ this is a bit inefficient, as it incurs an allocation.
	# If there are perf issues in future maybe take a look at this.
	_buffer.add(ev)


func add_from_client(send_time: float, execute_func: Callable) -> void:
	add(send_time + NetworkManager.CLIENT_RTT/2.0, execute_func)


func add_from_server_interp(send_time: float, execute_func: Callable) -> void:
	# we subtract `TICK_STEP` because we intend on interpolating 
	add(send_time + (NetworkManager.CLIENT_RTT/2.0) - NetworkManager.TICK_STEP, execute_func)

func add_from_server(send_time: float, execute_func: Callable) -> void:
	# we subtract `TICK_STEP` because the way our 
	add(send_time + (NetworkManager.CLIENT_RTT/2.0) - NetworkManager.TICK_STEP, execute_func)





func poll(current_time: float) -> void:
	var i = 0;
	while _buffer.size() > 0 and _buffer.peek().execute_time <= current_time:
		var ev = _buffer.pop()
		ev.execute_func.call()

		i += 1
		if (i > 5000): # just for safety.
			push_error("Too many events in queue!")


