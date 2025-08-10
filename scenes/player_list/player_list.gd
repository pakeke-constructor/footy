extends Control


@onready var label: RichTextLabel = $RichTextLabel


func _ready() -> void:
	GameManager.team_scored.connect(func(_team_id: int) -> void:
		_update_player_list()
	)
	GameManager.player_scored.connect(func(_player_id: int) -> void:
		_update_player_list()
	)
	
	NetworkManager.player_connected.connect(func(_id: int) -> void:
		_update_player_list()
	)
	
	NetworkManager.player_disconnected.connect(func(_id: int) -> void:
		_update_player_list()
	)

	_update_player_list()


func _update_player_list() -> void:
	var text = ""
	text += "[center][b][color=#4080FF]BLUE TEAM[/color][/b][/center]\n"
	
	var blue_players = _get_team_players(GameManager.Team.BLUE)
	if blue_players.is_empty():
		text += "[center][i]No players[/i][/center]\n"
	else:
		for player_id in blue_players:
			# TODO: Make server also a player
			if player_id == 1:
				continue
			var score = GameManager.player_scores.get(player_id, 0)
			# TODO: Add player username when available
			text += "[color=#4080FF]Player #" + str(player_id) + "[/color]: " + str(score) + " points\n"
	
	text += "\n"
	text += "[center][b][color=#FF4040]RED TEAM[/color][/b][/center]\n"
	
	var red_players = _get_team_players(GameManager.Team.RED)
	if red_players.is_empty():
		text += "[center][i]No players[/i][/center]\n"
	else:
		for player_id in red_players:
			# TODO: Make server also a player
			if player_id == 1:
				continue
			var score = GameManager.player_scores.get(player_id, 0)
			# TODO: Add player username when available
			text += "[color=#FF4040]Player #" + str(player_id) + "[/color]: " + str(score) + " points\n"
	
	label.text = text


func _get_team_players(team: GameManager.Team) -> Array:
	var players = []
	for player_id in GameManager.player_teams:
		if GameManager.player_teams[player_id] == team:
			players.append(player_id)
	return players

