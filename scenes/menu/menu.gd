

extends Control


@onready var world_scene = preload("res://scenes/world/World.tscn")
@onready var ip_input = $VBoxContainer/IPInput
@onready var host_button = $VBoxContainer/HostButton
@onready var join_button = $VBoxContainer/JoinButton


func _ready():
    host_button.pressed.connect(_on_host_pressed)
    join_button.pressed.connect(_on_join_pressed)

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
    get_tree().change_scene_to_packed(world_scene)
