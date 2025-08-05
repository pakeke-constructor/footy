

extends Node

func _ready():
	if not OS.is_debug_build():
		# TODO: is this working??
		# This probably needs to be tested.
		queue_free()

func _input(event):
	if not OS.is_debug_build():
		return

	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == Key.KEY_P:
			get_tree().root.print_tree_pretty()
		elif event.keycode == Key.KEY_Q:
			Input.mouse_mode = Input.MOUSE_MODE_VISIBLE

		# todo: add more debug-tools here.


