extends Control


@onready var score_label: Label = $ScoreLabel
@onready var timer: Timer = $Timer


func _ready() -> void:
	timer.timeout.connect(_on_timer_timeout)
	_on_timer_timeout()


func _on_timer_timeout() -> void:
	score_label.text = "BLUE: %d - RED: %d" % [
		GameManager.team_scores[GameManager.Team.BLUE],
		GameManager.team_scores[GameManager.Team.RED]
	]
