extends Control

@export var game_scene: PackedScene
@onready var menu_buttons = $CenterContainer/VBoxContainer
@onready var match_setup = $CenterContainer/MatchSetup
@onready var round_value_label = %RoundValueLabel
@onready var increase_rounds_button = %IncreaseRoundsButton
@onready var decrease_rounds_button = %DecreaseRoundsButton
@onready var one_ball_button = %OneBallButton
@onready var two_ball_button = %TwoBallButton
@onready var beep1 = $Beep1
@onready var beep2 = $Beep2
@onready var explosion = $BallOutSound

var selected_mode = -1
var rounds = 3
var ball_count = 1
var round_key_timer = 0.0
var round_key_repeat_delay = 0.15
var round_input_cooldown = false
var ball_mode_input_cooldown = false
var menu_button_input_cooldown = false
var menu_button_repeat_time = 0.20
static var printed_name_once = false

func _ready():
	if !printed_name_once:
		print("Ping Pong - Created by Isaac D. Hoyos")
		printed_name_once = true
	menu_buttons.get_node("P1VSCOM2").pressed.connect(_on_p1_vs_com2)
	menu_buttons.get_node("P1VSP2").pressed.connect(_on_p1_vs_p2)
	menu_buttons.get_node("COM1VSCOM2").pressed.connect(_on_com1_vs_com2)
	menu_buttons.get_node("P1VSCOM2").grab_focus()
	increase_rounds_button.pressed.connect(_increase_rounds)
	decrease_rounds_button.pressed.connect(_decrease_rounds)
	increase_rounds_button.gui_input.connect(_on_increase_rounds_button_gui_input)
	decrease_rounds_button.gui_input.connect(_on_decrease_rounds_button_gui_input)
	one_ball_button.gui_input.connect(_on_one_ball_button_gui_input)
	two_ball_button.gui_input.connect(_on_two_ball_button_gui_input)
	one_ball_button.pressed.connect(_set_one_ball)
	two_ball_button.pressed.connect(_set_two_ball)
	match_setup.get_node("VBoxContainer/StartButton").pressed.connect(_start_selected_game)
	match_setup.visible = false
	update_round_label()
	update_ball_selection_visual()
	
func _input(event):
	if match_setup.visible:
		var focused = get_viewport().gui_get_focus_owner()
		if (focused == increase_rounds_button or focused == decrease_rounds_button) and event.is_action_pressed("ui_down", true):
			accept_event()
			if ball_count == 1:
				beep1.play()
				one_ball_button.grab_focus()
			else:
				beep2.play()
				two_ball_button.grab_focus()
			return
		if (focused == one_ball_button or focused == two_ball_button) and event.is_action_pressed("ui_up", true):
			accept_event()
			if ball_count == 1:
				if can_play_round_button_sound(decrease_rounds_button):
					beep1.play()
				decrease_rounds_button.grab_focus()
			else:
				if can_play_round_button_sound(increase_rounds_button):
					beep2.play()
				increase_rounds_button.grab_focus()
			return
		if (focused == one_ball_button or focused == two_ball_button) and event.is_action_pressed("ui_down", true):
			accept_event()
			if ball_count == 1:
				beep2.play()
			else:
				beep1.play()
			match_setup.get_node("VBoxContainer/StartButton").grab_focus()
			return
		if focused == match_setup.get_node("VBoxContainer/StartButton") and event.is_action_pressed("ui_up", true):
			accept_event()
			if ball_count == 1:
				beep1.play()
				one_ball_button.grab_focus()
			else:
				beep2.play()
				two_ball_button.grab_focus()
			return
	if menu_buttons.visible:
		var focused = get_viewport().gui_get_focus_owner()
		if event.is_action_pressed("ui_down", true):
			accept_event()
			if menu_button_input_cooldown:
				return
			menu_button_input_cooldown = true
			beep1.play()
			if focused == menu_buttons.get_node("P1VSCOM2"):
				menu_buttons.get_node("P1VSP2").grab_focus()
			elif focused == menu_buttons.get_node("P1VSP2"):
				menu_buttons.get_node("COM1VSCOM2").grab_focus()
			else:
				menu_buttons.get_node("P1VSCOM2").grab_focus()
			await get_tree().create_timer(menu_button_repeat_time).timeout
			menu_button_input_cooldown = false
			return
		if event.is_action_pressed("ui_up", true):
			accept_event()
			if menu_button_input_cooldown:
				return
			menu_button_input_cooldown = true
			beep2.play()
			if focused == menu_buttons.get_node("P1VSCOM2"):
				menu_buttons.get_node("COM1VSCOM2").grab_focus()
			elif focused == menu_buttons.get_node("P1VSP2"):
				menu_buttons.get_node("P1VSCOM2").grab_focus()
			else:
				menu_buttons.get_node("P1VSP2").grab_focus()
			await get_tree().create_timer(menu_button_repeat_time).timeout
			menu_button_input_cooldown = false
			return
	if event.is_action_pressed("quit_game") or event.is_action_pressed("reset_game"):
		if match_setup.visible:
			match_setup.visible = false
			menu_buttons.visible = true
			reset_match_setup()
			menu_buttons.get_node("P1VSCOM2").grab_focus()
		elif event.is_action_pressed("quit_game"):
			get_tree().quit()

func reset_match_setup():
	selected_mode = -1
	rounds = 3
	ball_count = 1
	update_round_label()
	update_ball_selection_visual()

func _on_p1_vs_com2():
	selected_mode = 0
	explosion.play()
	show_match_setup()

func _on_p1_vs_p2():
	selected_mode = 1
	explosion.play()
	show_match_setup()

func _on_com1_vs_com2():
	selected_mode = 2
	explosion.play()
	show_match_setup()

func show_match_setup():
	menu_buttons.visible = false
	match_setup.visible = true
	match_setup.get_node("HBoxContainer/DecreaseRoundsButton").grab_focus()
	
func update_focus_neighbors():
	if ball_count == 1:
		decrease_rounds_button.focus_neighbor_bottom = one_ball_button.get_path()
		increase_rounds_button.focus_neighbor_bottom = one_ball_button.get_path()
		match_setup.get_node("VBoxContainer/StartButton").focus_neighbor_top = one_ball_button.get_path()
	else:
		decrease_rounds_button.focus_neighbor_bottom = two_ball_button.get_path()
		increase_rounds_button.focus_neighbor_bottom = two_ball_button.get_path()
		match_setup.get_node("VBoxContainer/StartButton").focus_neighbor_top = two_ball_button.get_path()
	
func can_play_round_button_sound(button):
	if button == increase_rounds_button:
		return rounds < 10
	if button == decrease_rounds_button:
		return rounds > 1
	return true
	
func _on_increase_rounds_button_gui_input(event):
	if event.is_action_pressed("ui_right", true) or event.is_action_pressed("ui_accept", true):
		accept_event()
		if round_input_cooldown or rounds >= 10:
			return
		round_input_cooldown = true
		beep2.play()
		_increase_rounds()
		increase_rounds_button.grab_focus()
		await get_tree().create_timer(0.20).timeout
		round_input_cooldown = false
	if event.is_action_pressed("ui_left", true):
		accept_event()
		if can_play_round_button_sound(decrease_rounds_button):
			beep1.play()
		decrease_rounds_button.grab_focus()

func _on_decrease_rounds_button_gui_input(event):
	if event.is_action_pressed("ui_left", true) or event.is_action_pressed("ui_accept", true):
		accept_event()
		if round_input_cooldown or rounds <= 1:
			return
		round_input_cooldown = true
		beep1.play()
		_decrease_rounds()
		decrease_rounds_button.grab_focus()
		await get_tree().create_timer(0.20).timeout
		round_input_cooldown = false
	if event.is_action_pressed("ui_right", true):
		accept_event()
		if can_play_round_button_sound(increase_rounds_button):
			beep2.play()
		increase_rounds_button.grab_focus()
	
func _increase_rounds():
	if rounds >= 10:
		return
	rounds += 1
	beep2.play()
	update_round_label()

func _decrease_rounds():
	if rounds <= 1:
		return
	rounds -= 1
	beep1.play()
	update_round_label()

func update_round_label():
	decrease_rounds_button.disabled = rounds <= 1
	increase_rounds_button.disabled = rounds >= 10
	round_value_label.text = str(rounds)
	
func _on_one_ball_button_gui_input(event):
	if event.is_action_pressed("ui_right", true):
		accept_event()
		if ball_mode_input_cooldown:
			return
		ball_mode_input_cooldown = true
		_set_two_ball()
		two_ball_button.grab_focus()
		await get_tree().create_timer(0.20).timeout
		ball_mode_input_cooldown = false
		
func _on_two_ball_button_gui_input(event):
	if event.is_action_pressed("ui_left", true):
		accept_event()
		if ball_mode_input_cooldown:
			return
		ball_mode_input_cooldown = true
		_set_one_ball()
		one_ball_button.grab_focus()
		await get_tree().create_timer(0.20).timeout
		ball_mode_input_cooldown = false

func _set_one_ball():
	if ball_count == 1:
		return
	ball_count = 1
	beep1.play()
	update_ball_selection_visual()

func _set_two_ball():
	if ball_count == 2:
		return
	ball_count = 2
	beep2.play()
	update_ball_selection_visual()

func update_ball_selection_visual():
	one_ball_button.self_modulate = Color(0.6, 0.6, 0.6)
	two_ball_button.self_modulate = Color(0.6, 0.6, 0.6)
	one_ball_button.mouse_filter = Control.MOUSE_FILTER_STOP
	two_ball_button.mouse_filter = Control.MOUSE_FILTER_STOP
	if ball_count == 1:
		one_ball_button.self_modulate = Color.WHITE
		one_ball_button.mouse_filter = Control.MOUSE_FILTER_IGNORE
	else:
		two_ball_button.self_modulate = Color.WHITE
		two_ball_button.mouse_filter = Control.MOUSE_FILTER_IGNORE
	update_focus_neighbors()

func _start_selected_game():
	explosion.play()
	await explosion.finished
	var scene = game_scene.instantiate()
	match selected_mode:
		0: scene.game_mode = scene.GameMode.P1_VS_COM2
		1: scene.game_mode = scene.GameMode.P1_VS_P2
		2: scene.game_mode = scene.GameMode.COM1_VS_COM2
	scene.total_rounds = rounds
	scene.ball_count = ball_count
	get_tree().root.add_child(scene)
	get_tree().current_scene.queue_free()
	get_tree().current_scene = scene
