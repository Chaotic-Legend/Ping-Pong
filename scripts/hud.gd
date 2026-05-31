extends Control

@onready var left_score = %LeftScore
@onready var right_score = %RightScore
@onready var pause_label = %PauseLabel
@onready var ball_out_sound = %BallOutSound

func _process(_delta):
	pause_label.visible = get_tree().paused

func set_new_score(score):
	left_score.text = str(score.x)
	right_score.text = str(score.y)

func reset_score():
	left_score.text = "0"
	right_score.text = "0"
	
func _on_play_again_button_pressed():
	ball_out_sound.play()
	await ball_out_sound.finished
	get_tree().paused = false
	get_tree().change_scene_to_file("res://scenes/mainmenu.tscn")
