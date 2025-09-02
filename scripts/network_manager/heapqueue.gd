class_name HeapQueue
extends RefCounted

var _heap: Array = []
var _compare_func: Callable

func _init(compare_function: Callable = _default_compare):
	_compare_func = compare_function


# Default comparison function (min-heap behavior)
func _default_compare(a, b) -> bool:
	return a < b


func add(item):
	_heap.append(item)
	_heapify_up(_heap.size() - 1)


func pop():
	if _heap.is_empty():
		return null
	
	var result = _heap[0]
	var last = _heap.pop_back()
	
	if not _heap.is_empty():
		_heap[0] = last
		_heapify_down(0)
	
	return result


func peek():
	return _heap[0] if not _heap.is_empty() else null


func size() -> int:
	return _heap.size()


func is_empty() -> bool:
	return _heap.is_empty()


func _heapify_up(index: int):
	if index == 0:
		return

	@warning_ignore("integer_division")
	var parent: int = (index - 1) / 2
	if _compare_func.call(_heap[index], _heap[parent]):
		_swap(index, parent)
		_heapify_up(parent)


func _heapify_down(index: int):
	var left = 2 * index + 1
	var right = 2 * index + 2
	var target: int = index
	
	if left < _heap.size() and _compare_func.call(_heap[left], _heap[target]):
		target = left
	
	if right < _heap.size() and _compare_func.call(_heap[right], _heap[target]):
		target = right
	
	if target != index:
		_swap(index, target)
		_heapify_down(target)


func _swap(i: int, j: int):
	var temp = _heap[i]
	_heap[i] = _heap[j]
	_heap[j] = temp
