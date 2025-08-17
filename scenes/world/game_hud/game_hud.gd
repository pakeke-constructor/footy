extends Control


@onready var score_label_blue: Label = %ScoreLabelBlue
@onready var score_label_red: Label = %ScoreLabelRed
@onready var time_label: Label = %TimeLabel
@onready var goal_label_container: Control = %GoalLabelContainer
@onready var timer: Timer = $Timer
@onready var player_list: Control = %PlayerList
@onready var score_view_container: Control = %ScoreViewContainer


func _ready() -> void:
	GameManager.team_scored.connect(_on_team_scored)
	GameManager.match_started.connect(_on_match_started)
	GameManager.match_stopped.connect(_on_match_stopped)
	timer.timeout.connect(_on_timer_timeout)

	score_view_container.visible = GameManager.state == GameManager.GameState.PLAYING


func _process(_delta: float) -> void:
	player_list.visible = Input.is_key_pressed(KEY_TAB)


func _on_team_scored(_team: GameManager.Team) -> void:
	score_label_blue.text = str(GameManager.team_scores[GameManager.Team.BLUE])
	score_label_red.text = str(GameManager.team_scores[GameManager.Team.RED])

	goal_label_container.visible = true
	await get_tree().create_timer(3.0).timeout
	goal_label_container.visible = false


func _on_match_started() -> void:
	score_view_container.visible = true


func _on_match_stopped() -> void:
	score_view_container.visible = false


func _on_timer_timeout() -> void:
	if GameManager.state == GameManager.GameState.PLAYING:
		var minutes: int = int(GameManager.match_time / 60)
		var seconds: int = int(GameManager.match_time) % 60
		time_label.text = "%02d:%02d" % [minutes, seconds]
