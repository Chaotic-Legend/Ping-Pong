extends Area2D

@export var is_ai = false
@export var is_player_two = false
@onready var cshape = $CollisionShape2D

const MAX_VELOCITY = 10.0

var active = true
var up_input = "rightpaddle_up"
var down_input = "rightpaddle_down"
var velocity = 0.0
var acceleration = 60.0
var slow_down_delta = 4.0
var ai_target_ypos1 = 360.0
var ai_target_ypos2 = 360.0
var ai_target_priority1 = 999999.0
var ai_target_priority2 = 999999.0
var ai_target_coming1 = false
var ai_target_coming2 = false
var ball_count = 1
var current_target_ball = 1
var ai_speed_multiplier = 1.0

func _ready():
	if is_player_two:
		up_input = "rightpaddle_up"
		down_input = "rightpaddle_down"

func _physics_process(delta: float) -> void:
	if !active:
		return
	var move_dir = 0.0
	if !is_ai:
		move_dir = Input.get_axis(up_input, down_input)
	else:
		move_dir = get_ai_movement_dir()
	velocity += move_dir * acceleration * delta
	if move_dir == 0.0:
		var stop_force = slow_down_delta
		if is_ai:
			stop_force = slow_down_delta * 3.0
		velocity = move_toward(velocity, 0.0, stop_force)
	var current_max_velocity = MAX_VELOCITY * 1.15
	if ball_count == 2:
		current_max_velocity = MAX_VELOCITY * 1.25
	if is_ai:
		var current_ai_speed_multiplier = ai_speed_multiplier
		if ball_count == 2:
			current_ai_speed_multiplier = 1.25
		velocity = clampf(velocity, -current_max_velocity * current_ai_speed_multiplier, current_max_velocity * current_ai_speed_multiplier)
	else:
		velocity = clampf(velocity, -current_max_velocity, current_max_velocity)
	position.y += velocity
	var shape = cshape.shape as RectangleShape2D
	var half_height = shape.size.y * 0.5
	var screen_height = get_viewport_rect().size.y
	var top_limit = half_height
	var bottom_limit = screen_height - half_height
	if position.y < top_limit:
		position.y = top_limit
		velocity = 0
	if position.y > bottom_limit:
		position.y = bottom_limit
		velocity = 0

func _on_body_entered(body: Node2D) -> void:
	if body is Ball:
		body.bounce_from_paddle(global_position.y, cshape.shape.get_rect().size.y)

func get_ai_movement_dir():
	var reaction_delay = 0.05
	var error_margin = 8.0
	var tracking_strength = 0.55
	var stop_distance = 35.0
	if ball_count == 2:
		reaction_delay = 0.01
		error_margin = 8.0
		tracking_strength = 1.0
		stop_distance = 8.0
	if randf() < reaction_delay:
		return 0
	var target_y = ai_target_ypos1
	if ball_count == 2:
		var switch_target = false
		if current_target_ball == 1:
			if !ai_target_coming1:
				switch_target = true
			elif ai_target_coming2 and ai_target_priority2 < ai_target_priority1 * 0.70:
				switch_target = true
		else:
			if !ai_target_coming2:
				switch_target = true
			elif ai_target_coming1 and ai_target_priority1 < ai_target_priority2 * 0.75:
				switch_target = true
		if switch_target:
			current_target_ball = 2 if current_target_ball == 1 else 1
		if current_target_ball == 2:
			target_y = ai_target_ypos2
	var noisy_target = target_y + randf_range(-error_margin, error_margin)
	var diff = noisy_target - global_position.y
	if abs(diff) < stop_distance:
		return 0
	return sign(diff) * tracking_strength
