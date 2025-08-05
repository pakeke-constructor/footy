

extends Control


@onready var world_scene = preload("res://scenes/world/World.tscn")
@onready var host_button: Button = %HostButton
@onready var ip_input: LineEdit = %IPInput
@onready var join_button: Button = %JoinButton


func _ready():
	host_button.pressed.connect(_on_host_pressed)
	join_button.pressed.connect(_on_join_pressed)
	NetworkManager.server_connected.connect(_on_server_connected)

	await get_tree().root.ready

	if DisplayServer.get_name() == "headless" or "--server" in OS.get_cmdline_args():
		_on_host_pressed()
	elif "--client" in OS.get_cmdline_args():
		_on_join_pressed()


func _on_host_pressed():
	NetworkManager.host_game()
	get_tree().change_scene_to_packed(world_scene)


func _on_join_pressed():
	NetworkManager.join_game(ip_input.text if ip_input.text != "" else "127.0.0.1")


func _on_server_connected():
	get_tree().change_scene_to_packed(world_scene)
