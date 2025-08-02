extends Control


@onready var score_label: Label = $ScoreLabel
@onready var timer: Timer = $Timer


func _ready() -> void:
	timer.timeout.connect(_update_label)
	GameManager.team_scored.connect(func (team: GameManager.Team) -> void:
		_update_label()
	)
	_update_label()


func _update_label() -> void:
	var score_text = "BLUE: %d - RED: %d" % [
		GameManager.team_scores[GameManager.Team.BLUE],
		GameManager.team_scores[GameManager.Team.RED]
	]
	
	# Add match timer if the game is in progress
	if GameManager.state == GameManager.GameState.PLAYING:
		@warning_ignore("integer_division")
		var minutes: int = int(GameManager.match_time) / 60
		var seconds: int = int(GameManager.match_time) % 60
		score_text += "\n%02d:%02d" % [minutes, seconds]
	
	score_label.text = score_text
