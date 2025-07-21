extends Control


@onready var score_label: Label = $ScoreLabel
@onready var timer: Timer = $Timer


func _ready() -> void:
	timer.timeout.connect(_on_timer_timeout)
	_on_timer_timeout()


func _on_timer_timeout() -> void:
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
