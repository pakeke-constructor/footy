

extends Control


@onready var world_scene = preload("res://scenes/world/World.tscn")
@onready var ip_input = $VBoxContainer/IPInput
@onready var host_button = $VBoxContainer/HostButton
@onready var join_button = $VBoxContainer/JoinButton


var is_client := false
var is_server := false


func parse_args():
    var args := OS.get_cmdline_args()
    
    for arg in args:
        if arg == "--server":
            is_server = true
        elif arg == "--client":
            is_client = true


func _ready():
    host_button.pressed.connect(_on_host_pressed)
    join_button.pressed.connect(_on_join_pressed)

    parse_args()

    await get_tree().root.ready

    if is_server:
        _on_host_pressed()
    elif is_client:
        _on_join_pressed()


func _on_host_pressed():
    NetworkManager.host_game()
    var main = world_scene.instantiate()
    get_tree().root.add_child(main)
    Util.await_ready(main)
    queue_free()


func _on_join_pressed():
    NetworkManager.join_game(ip_input.text if ip_input.text != "" else "127.0.0.1")
    var main = world_scene.instantiate()
    get_tree().root.add_child(main)
    Util.await_ready(main)
    queue_free()
