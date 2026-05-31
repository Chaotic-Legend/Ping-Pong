extends Node2D

enum GameMode {
	P1_VS_COM2,
	P1_VS_P2,
	COM1_VS_COM2
}

@onready var hud = $UI/HUD
@onready var game_field = $GameField
@onready var ball1 = $GameField/TheBall/Ball1
@onready var ball2 = $GameField/TheBall/Ball2
@onready var round_label = $UI/HUD/RoundLabel
@onready var round_wins_label = $UI/HUD/RoundWinsLabel
@onready var tie_breaker_label = $UI/HUD/TieBreakerLabel
@onready var left_paddle = $GameField/Paddles/LeftPaddle
@onready var right_paddle = $GameField/Paddles/RightPaddle
@onready var detector_left = $GameField/Environment/DetectorLeft
@onready var detector_right = $GameField/Environment/DetectorRight
@onready var line1 = $GameField/TheBall/LineBall1
@onready var line2 = $GameField/TheBall/LineBall2
@onready var ball_out_sound = $GameField/TheBall/BallOutSound
@onready var win_screen = $UI/HUD/WinScreen
@onready var winner_label = $UI/HUD/WinScreen/CenterContainer/VBoxContainer/WinnerLabel
@onready var final_score_label = $UI/HUD/WinScreen/CenterContainer/VBoxContainer/FinalScoreLabel
@onready var play_again_button = $UI/HUD/WinScreen/CenterContainer/VBoxContainer/PlayAgainButton

var final_score = 11
var game_mode = GameMode.P1_VS_COM2
var current_round = 1
var total_rounds = 3
var original_total_rounds = 3
var round_wins = Vector2i.ZERO
var score = Vector2i.ZERO
var ball_count = 1
var balls_out_this_point = 0
var match_started = false
var match_over = false
var round_running = false
var first_goal_scored = false
var tie_breaker_active = false
var can_pause = true
var can_debug_control = false
var path_lines_enabled = false
var is_resetting = false
var reset_token = 0
var ball1_paused_active = false
var ball2_paused_active = false
var left_start_pos
var right_start_pos
static var thanked_player_once = false

func _ready():
	center_game_field()
	ball1.modulate = Color.WHITE
	ball2.modulate = Color.GRAY
	line1.default_color = Color.WHITE
	line2.default_color = Color.GRAY
	left_start_pos = left_paddle.position
	right_start_pos = right_paddle.position
	set_process_input(true)
	set_game_mode(game_mode)
	detector_left.ball_out.connect(_on_detector_ball_out)
	detector_right.ball_out.connect(_on_detector_ball_out)
	ball1.debug_up_action = "ball1_up"
	ball1.debug_down_action = "ball1_down"
	ball1.debug_left_action = "ball1_left"
	ball1.debug_right_action = "ball1_right"
	ball1.bounced.connect(_on_ball_bounced)
	ball1.ball_collision.connect(_on_ball_collision)
	if ball_count == 2 and is_instance_valid(ball2):
		ball2.debug_up_action = "ball2_up"
		ball2.debug_down_action = "ball2_down"
		ball2.debug_left_action = "ball2_left"
		ball2.debug_right_action = "ball2_right"
		ball2.bounced.connect(_on_ball_bounced)
		ball2.ball_collision.connect(_on_ball_collision)
	randomize()
	if ball_count == 1 and is_instance_valid(ball2):
		ball2.queue_free()
	reset_game()
	
func center_game_field():
	var base_size = Vector2(1280, 720)
	var screen_size = get_viewport_rect().size
	game_field.position = (screen_size - base_size) * 0.5
	
func _on_ball_collision(_ball):
	if !get_tree().paused and round_running:
		if is_instance_valid(ball1) and ball1.visible and ball1.active:
			call_deferred("simulate_ball_movement", ball1)
		if is_instance_valid(ball2) and ball2.visible and ball2.active:
			call_deferred("simulate_ball_movement", ball2)

func set_game_mode(mode):
	game_mode = mode
	match game_mode:
		GameMode.P1_VS_COM2:
			left_paddle.is_ai = false
			right_paddle.is_ai = true
		GameMode.P1_VS_P2:
			left_paddle.is_ai = false
			right_paddle.is_ai = false
		GameMode.COM1_VS_COM2:
			left_paddle.is_ai = true
			right_paddle.is_ai = true
	left_paddle.ball_count = ball_count
	right_paddle.ball_count = ball_count

func _input(event):
	if match_over:
		if event.is_action_pressed("reset_game"):
			get_tree().paused = false
			get_tree().change_scene_to_file("res://scenes/mainmenu.tscn")
			return
		if event.is_action_pressed("quit_game"):
			get_tree().change_scene_to_file("res://scenes/mainmenu.tscn")
			return
		return
	if event.is_action_pressed("quit_game"):
		reset_token += 1
		get_tree().paused = false
		round_running = false
		can_pause = false
		is_resetting = true
		get_tree().change_scene_to_file("res://scenes/mainmenu.tscn")
		return
	if event.is_action_pressed("pause_game") and can_pause:
		var paused_now = !get_tree().paused
		if paused_now:
			ball1_paused_active = ball1.active
			ball2_paused_active = is_instance_valid(ball2) and ball2.active
			ball1.active = false
			if is_instance_valid(ball2):
				ball2.active = false
			left_paddle.active = false
			right_paddle.active = false
			get_tree().paused = true
		else:
			get_tree().paused = false
			ball1.active = ball1_paused_active
			if is_instance_valid(ball2):
				ball2.active = ball2_paused_active
			left_paddle.active = true
			right_paddle.active = true
	if event.is_action_pressed("reset_game"):
		get_tree().paused = false
		path_lines_enabled = false
		line1.visible = false
		line2.visible = false
		line1.clear_points()
		line2.clear_points()
		reset_game()
		
func _exit_tree():
	reset_token += 1
	get_tree().paused = false

func _process(_delta: float) -> void:
	center_game_field()
	if get_tree().paused:
		return
	if Input.is_action_just_pressed("ball_control"):
		if !can_debug_control:
			return
		ball1.debug_mode = !ball1.debug_mode
		if is_instance_valid(ball2):
			ball2.debug_mode = ball1.debug_mode
		if ball1.debug_mode:
			if left_paddle.is_ai:
				left_paddle.active = false
			if right_paddle.is_ai:
				right_paddle.active = false
			ball1.saved_speed_before_debug = ball1.speed
			ball1.saved_move_dir_before_debug = ball1.move_dir
			ball1.speed = ball1.START_SPEED
			if is_instance_valid(ball2):
				ball2.saved_speed_before_debug = ball2.speed
				ball2.saved_move_dir_before_debug = ball2.move_dir
				ball2.speed = ball2.START_SPEED
			line1.clear_points()
			line2.clear_points()
			line1.visible = false
			line2.visible = false
		else:
			if left_paddle.is_ai:
				left_paddle.active = true
			if right_paddle.is_ai:
				right_paddle.active = true
			reset_ai_targets()
			ball1.speed = ball1.saved_speed_before_debug
			ball1.move_dir = ball1.saved_move_dir_before_debug.normalized()
			if is_instance_valid(ball2):
				ball2.speed = ball2.saved_speed_before_debug
				ball2.move_dir = ball2.saved_move_dir_before_debug.normalized()
			if path_lines_enabled:
				line1.visible = true
				line2.visible = true
			call_deferred("simulate_ball_movement", ball1)
			if is_instance_valid(ball2) and ball2.visible and ball2.active:
				call_deferred("simulate_ball_movement", ball2)
	if Input.is_action_just_pressed("show_lines"):
		if ball1.debug_mode:
			path_lines_enabled = false
			line1.visible = false
			line2.visible = false
		else:
			path_lines_enabled = !path_lines_enabled
			line1.visible = path_lines_enabled
			line2.visible = path_lines_enabled

func get_ball_spawn_pos():
	return get_viewport_rect().size * 0.5

func reset_game():
	reset_token += 1
	var my_token = reset_token
	is_resetting = true
	match_over = false
	win_screen.visible = false
	can_pause = false
	can_debug_control = false
	round_running = false
	balls_out_this_point = 0
	first_goal_scored = false
	get_tree().paused = false
	score = Vector2i.ZERO
	current_round = 1
	round_wins = Vector2i.ZERO
	original_total_rounds = total_rounds
	tie_breaker_active = false
	hud.reset_score()
	tie_breaker_label.visible = false
	round_wins_label.visible = false
	reset_ai_targets()
	line1.clear_points()
	line2.clear_points()
	line1.visible = path_lines_enabled
	line2.visible = path_lines_enabled
	var spawn_pos = get_ball_spawn_pos()
	set_ball_enabled(ball1, true)
	ball1.debug_mode = false
	ball1.active = false
	ball1.visible = false
	ball1.reset(spawn_pos)
	if is_instance_valid(ball2):
		set_ball_enabled(ball2, true)
		ball2.debug_mode = false
		ball2.active = false
		ball2.visible = false
		ball2.reset(spawn_pos)
		if ball_count == 2:
			set_ball_enabled(ball2, false)
	left_paddle.position = left_start_pos
	right_paddle.position = right_start_pos
	left_paddle.velocity = 0
	right_paddle.velocity = 0
	left_paddle.active = true
	right_paddle.active = true
	await get_tree().process_frame
	if my_token != reset_token:
		return
	is_resetting = false
	start_match()

func start_match():
	match_started = true
	current_round = 1
	start_round()

func start_round():
	reset_token += 1
	var my_token = reset_token
	reset_ai_targets()
	can_pause = false
	can_debug_control = false
	round_running = false
	is_resetting = true
	balls_out_this_point = 0
	var spawn_pos = get_ball_spawn_pos()
	ball1.active = false
	ball1.visible = false
	ball1.reset(spawn_pos)
	if ball_count == 2 and is_instance_valid(ball2):
		ball2.active = false
		ball2.visible = false
		set_ball_enabled(ball2, false)
		ball2.global_position = Vector2(-9999, -9999)
	line1.clear_points()
	line2.clear_points()
	is_resetting = false
	round_label.visible = true
	round_label.text = "ROUND " + str(current_round)
	tie_breaker_label.visible = tie_breaker_active
	round_wins_label.text = str(round_wins.x) + " - " + str(round_wins.y)
	round_wins_label.visible = !tie_breaker_active
	await get_tree().create_timer(2.5, false).timeout
	if my_token != reset_token:
		return
	round_label.visible = false
	tie_breaker_label.visible = false
	round_wins_label.visible = false
	if !ball1.debug_mode:
		await get_tree().create_timer(0.5, false).timeout
		if my_token != reset_token:
			return
	ball1.visible = true
	can_pause = true
	if !ball1.debug_mode:
		await get_tree().create_timer(0.5, false).timeout
		if my_token != reset_token:
			return
	launch_ball(ball1)
	round_running = true
	if ball_count == 2 and is_instance_valid(ball2):
		if ball1.debug_mode:
			while ball1.global_position.distance_to(spawn_pos) < 100.0:
				await get_tree().physics_frame
				if my_token != reset_token:
					return
		else:
			await get_tree().create_timer(0.3, false).timeout
			if my_token != reset_token:
				return
		ball2.reset(spawn_pos)
		set_ball_enabled(ball2, true)
		ball2.active = false
		ball2.visible = true
		if !ball1.debug_mode:
			await get_tree().create_timer(0.5, false).timeout
			if my_token != reset_token:
				return
		launch_ball(ball2)
	can_debug_control = true

func launch_ball(ball):
	if get_tree().paused or is_resetting:
		return
	if !is_instance_valid(ball):
		return
	set_ball_enabled(ball, true)
	ball.visible = true
	ball.active = true
	ball.set_physics_process(true)
	ball.speed = ball.START_SPEED
	var direction_x = [-1, 1].pick_random()
	var direction_y = randf_range(-0.8, 0.8)
	if ball_count == 2 and ball == ball2 and is_instance_valid(ball1):
		direction_x = -sign(ball1.move_dir.x)
		if direction_x == 0:
			direction_x = [-1, 1].pick_random()
	ball.move_dir = Vector2(direction_x, direction_y).normalized()
	call_deferred("simulate_ball_movement", ball)

func _on_detector_ball_out(is_left, ball):
	if is_resetting or !round_running:
		return
	if !is_instance_valid(ball):
		return
	ball.active = false
	ball.visible = false
	set_ball_enabled(ball, false)
	ball.global_position = Vector2(-9999, -9999)
	if is_left:
		score.y += 1
	else:
		score.x += 1
	hud.set_new_score(score)
	ball_out_sound.play()
	if ball == ball1:
		line1.clear_points()
	elif ball == ball2:
		line2.clear_points()
	if score.x >= final_score or score.y >= final_score:
		first_goal_scored = true
		round_running = false
		end_round()
		return
	if ball_count == 2:
		balls_out_this_point += 1
		if balls_out_this_point < 2:
			if ball == ball1:
				if left_paddle.is_ai:
					left_paddle.ai_target_coming1 = false
					left_paddle.ai_target_priority1 = 999999.0
				if right_paddle.is_ai:
					right_paddle.ai_target_coming1 = false
					right_paddle.ai_target_priority1 = 999999.0
			elif ball == ball2:
				if left_paddle.is_ai:
					left_paddle.ai_target_coming2 = false
					left_paddle.ai_target_priority2 = 999999.0
				if right_paddle.is_ai:
					right_paddle.ai_target_coming2 = false
					right_paddle.ai_target_priority2 = 999999.0
			return
	first_goal_scored = true
	round_running = false
	reset_after_goal()

func reset_after_goal():
	reset_token += 1
	var my_token = reset_token
	is_resetting = true
	reset_ai_targets()
	can_pause = first_goal_scored
	can_debug_control = false
	round_running = false
	balls_out_this_point = 0
	var spawn_pos = get_ball_spawn_pos()
	ball1.active = false
	ball1.visible = true
	ball1.reset(spawn_pos)
	set_ball_enabled(ball1, true)
	ball1.active = false
	if ball_count == 2 and is_instance_valid(ball2):
		ball2.active = false
		ball2.visible = false
		set_ball_enabled(ball2, false)
		ball2.global_position = Vector2(-9999, -9999)
	line1.clear_points()
	line2.clear_points()
	await get_tree().process_frame
	if my_token != reset_token:
		return
	is_resetting = false
	if !ball1.debug_mode:
		await get_tree().create_timer(1.5, false).timeout
		if my_token != reset_token:
			return
	launch_ball(ball1)
	round_running = true
	if ball_count == 2 and is_instance_valid(ball2):
		if ball1.debug_mode:
			while ball1.global_position.distance_to(spawn_pos) < 100.0:
				await get_tree().physics_frame
				if my_token != reset_token:
					return
		else:
			await get_tree().create_timer(0.3, false).timeout
			if my_token != reset_token:
				return
		ball2.reset(spawn_pos)
		ball2.visible = true
		ball2.active = false
		set_ball_enabled(ball2, false)
		if !ball1.debug_mode:
			await get_tree().create_timer(0.5, false).timeout
			if my_token != reset_token:
				return
		set_ball_enabled(ball2, true)
		launch_ball(ball2)
	can_pause = true
	can_debug_control = true

func end_round():
	if score.x > score.y:
		round_wins.x += 1
	elif score.y > score.x:
		round_wins.y += 1
	current_round += 1
	score = Vector2i.ZERO
	hud.reset_score()
	reset_ai_targets()
	if current_round > total_rounds:
		if round_wins.x == round_wins.y and !tie_breaker_active:
			tie_breaker_active = true
			total_rounds += 1
			start_round()
		else:
			total_rounds = original_total_rounds
			show_win_screen()
	else:
		start_round()

func reset_round():
	start_round()
	
func show_win_screen():
	match_over = true
	reset_token += 1
	get_tree().paused = false
	can_pause = false
	can_debug_control = false
	round_running = false
	is_resetting = true
	ball1.active = false
	ball1.visible = false
	set_ball_enabled(ball1, false)
	if is_instance_valid(ball2):
		ball2.active = false
		ball2.visible = false
		set_ball_enabled(ball2, false)
	line1.clear_points()
	line2.clear_points()
	round_label.visible = false
	tie_breaker_label.visible = false
	round_wins_label.visible = false
	var winner_text = ""
	if round_wins.x > round_wins.y:
		match game_mode:
			GameMode.P1_VS_COM2:
				winner_text = "PLAYER 1 WINS"
			GameMode.P1_VS_P2:
				winner_text = "PLAYER 1 WINS"
			GameMode.COM1_VS_COM2:
				winner_text = "COM 1 WINS"
	else:
		match game_mode:
			GameMode.P1_VS_COM2:
				winner_text = "COM 2 WINS"
			GameMode.P1_VS_P2:
				winner_text = "PLAYER 2 WINS"
			GameMode.COM1_VS_COM2:
				winner_text = "COM 2 WINS"
	winner_label.text = winner_text
	final_score_label.text = "FINAL SCORE " + str(round_wins.x) + " - " + str(round_wins.y)
	win_screen.visible = true
	play_again_button.grab_focus()
	if !thanked_player_once:
		print("\nThank you so much for playing my game")
		thanked_player_once = true

func set_ball_enabled(ball, enabled: bool):
	if !is_instance_valid(ball):
		return
	ball.visible = enabled
	ball.set_physics_process(enabled)
	if ball.has_node("CollisionShape2D"):
		ball.get_node("CollisionShape2D").set_deferred("disabled", !enabled)
	ball.set_deferred("collision_layer", 1 if enabled else 0)
	ball.set_deferred("collision_mask", 1 if enabled else 0)

func _on_ball_bounced(ball):
	if !get_tree().paused and round_running and is_instance_valid(ball):
		call_deferred("simulate_ball_movement", ball)

func simulate_ball_movement(ball, seconds: float = 30.0):
	if !is_instance_valid(ball):
		return
	if !ball.visible or !ball.active:
		return
	var line = line1 if ball == ball1 else line2
	var ball_pos = ball.cshape.global_position
	var dir = ball.move_dir.normalized()
	var bs = ball.get_size()
	var screen = get_viewport_rect().size
	var top = bs.y * 0.5
	var bottom = screen.y - (bs.y * 0.5)
	var left = left_paddle.global_position.x + (bs.x * 0.5)
	var right = right_paddle.global_position.x - (bs.x * 0.5)
	var points = PackedVector2Array()
	points.append(ball_pos)
	var dt = 1.0 / 120.0
	var steps = int(seconds * 120)
	for i in range(steps):
		if get_tree().paused:
			break
		ball_pos += dir * ball.speed * dt
		if ball_pos.y <= top:
			ball_pos.y = top
			dir.y = abs(dir.y)
		elif ball_pos.y >= bottom:
			ball_pos.y = bottom
			dir.y = -abs(dir.y)
		points.append(ball_pos)
		if i > 6 and ball_pos.x <= left and dir.x < 0:
			break
		if i > 6 and ball_pos.x >= right and dir.x > 0:
			break
	line.global_position = Vector2.ZERO
	line.clear_points()
	for p in points:
		line.add_point(p)
	var left_distance = abs(ball.global_position.x - left_paddle.global_position.x)
	var right_distance = abs(ball.global_position.x - right_paddle.global_position.x)
	var ball_speed = max(ball.speed, 1.0)
	var left_priority = left_distance / ball_speed
	var right_priority = right_distance / ball_speed
	var moving_left = ball.move_dir.x < 0
	var moving_right = ball.move_dir.x > 0
	if ball == ball1:
		if left_paddle.is_ai:
			left_paddle.ai_target_ypos1 = ball_pos.y
			left_paddle.ai_target_priority1 = left_priority
			left_paddle.ai_target_coming1 = moving_left
		if right_paddle.is_ai:
			right_paddle.ai_target_ypos1 = ball_pos.y
			right_paddle.ai_target_priority1 = right_priority
			right_paddle.ai_target_coming1 = moving_right
	elif ball == ball2:
		if left_paddle.is_ai:
			left_paddle.ai_target_ypos2 = ball_pos.y
			left_paddle.ai_target_priority2 = left_priority
			left_paddle.ai_target_coming2 = moving_left
		if right_paddle.is_ai:
			right_paddle.ai_target_ypos2 = ball_pos.y
			right_paddle.ai_target_priority2 = right_priority
			right_paddle.ai_target_coming2 = moving_right

func reset_ai_targets():
	var center_y = get_viewport_rect().size.y * 0.5
	left_paddle.ai_target_ypos1 = center_y
	left_paddle.ai_target_ypos2 = center_y
	left_paddle.ai_target_priority1 = 999999.0
	left_paddle.ai_target_priority2 = 999999.0
	left_paddle.ai_target_coming1 = false
	left_paddle.ai_target_coming2 = false
	left_paddle.current_target_ball = 1
	right_paddle.ai_target_ypos1 = center_y
	right_paddle.ai_target_ypos2 = center_y
	right_paddle.ai_target_priority1 = 999999.0
	right_paddle.ai_target_priority2 = 999999.0
	right_paddle.ai_target_coming1 = false
	right_paddle.ai_target_coming2 = false
	right_paddle.current_target_ball = 1
