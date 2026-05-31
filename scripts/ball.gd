extends CharacterBody2D
class_name Ball

signal bounced(ball)
signal ball_collision(ball)

@onready var cshape = $CollisionShape2D
@onready var beep1 = $Beep1
@onready var beep2 = $Beep2
@export var speed_increase_per_bounce = 20

const START_SPEED = 500
const MAX_SPEED = 1500
var saved_speed_before_debug = START_SPEED
var saved_move_dir_before_debug = Vector2(-1, 0)
var active = false
var debug_mode = false
var touching_bodies = {}
var ball_contact_cooldown = 0.0
var paddle_bounce_flip = 1
var last_paddle_hit_y = 999.0
var min_x_after_paddle = 0.45
var debug_up_action = "ball1_up"
var debug_down_action = "ball1_down"
var debug_left_action = "ball1_left"
var debug_right_action = "ball1_right"
var debug_collision_steps = 4
var debug_block_radius = 20.0
var touching_wall = false
var speed = START_SPEED
var move_dir = Vector2(-1, 0)
var last_paddle_move_dir = Vector2.ZERO
var same_path_threshold = 0.50
var wall_touch_time = 0.0
var wall_stuck_limit = 0.5

func _physics_process(delta: float) -> void:
	if ball_contact_cooldown > 0.0:
		ball_contact_cooldown -= delta
	if !active:
		return
	if debug_mode:
		var vertical_dir = Input.get_axis(debug_up_action, debug_down_action)
		var horizontal_dir = Input.get_axis(debug_left_action, debug_right_action)
		var debug_dir = Vector2(horizontal_dir, vertical_dir)
		var debug_current_bodies = {}
		if debug_dir != Vector2.ZERO:
			var old_pos = global_position
			var motion = debug_dir.normalized() * speed * delta
			global_position += motion
			var touching_something = test_move(global_transform, Vector2.ZERO)
			if touching_something and !touching_wall:
				touching_wall = true
				play_beep()
			elif !touching_something:
				touching_wall = false
			move_and_collide(Vector2.ZERO)
			for body in get_tree().get_nodes_in_group("balls"):
				if body != self and body is Ball:
					var touching = global_position.distance_to(body.global_position) < debug_block_radius
					if touching:
						debug_current_bodies[body] = true
						if !touching_bodies.has(body):
							touching_bodies[body] = true
							play_beep()
						global_position = old_pos
						velocity = Vector2.ZERO
		else:
			velocity = Vector2.ZERO
			touching_wall = false
		for body in touching_bodies.keys():
			if !debug_current_bodies.has(body):
				touching_bodies.erase(body)
		return
	velocity = move_dir.normalized() * speed
	move_and_slide()
	var current_bodies = {}
	for i in range(get_slide_collision_count()):
		var collision = get_slide_collision(i)
		var collider = collision.get_collider()
		if collider == null:
			continue
		current_bodies[collider] = true
		if touching_bodies.has(collider):
			continue
		touching_bodies[collider] = true
		if collider is Ball:
			if ball_contact_cooldown > 0.0:
				continue
			ball_contact_cooldown = 0.15
			var normal = (global_position - collider.global_position).normalized()
			if normal == Vector2.ZERO:
				normal = collision.get_normal()
			move_dir = move_dir.bounce(normal).normalized()
			var forced_y = randf_range(0.35, 0.65)
			if randf() < 0.5:
				forced_y *= -1
			move_dir.y = forced_y
			move_dir.x = sign(move_dir.x) * sqrt(1.0 - move_dir.y * move_dir.y)
			move_dir = move_dir.normalized()
			speed += speed_increase_per_bounce
			global_position += normal * 4.0
			play_beep()
			bounced.emit(self)
			ball_collision.emit(self)
		else:
			if collider.has_method("is_paddle_body"):
				bounce_from_paddle(collider.global_position.y, collider.cshape.shape.get_rect().size.y)
			else:
				var normal = collision.get_normal()
				if abs(normal.y) > abs(normal.x):
					move_dir.y *= -1
					if abs(move_dir.x) < 0.20:
						move_dir.x += 0.35 * [-1, 1].pick_random()
				else:
					move_dir.x *= -1
					if abs(move_dir.y) < 0.20:
						move_dir.y += 0.35 * [-1, 1].pick_random()
				move_dir = move_dir.normalized()
				velocity = move_dir * speed
				global_position += normal * 2.0
				play_beep()
	for body in touching_bodies.keys():
		if !current_bodies.has(body):
			touching_bodies.erase(body)

func bounce_from_paddle(paddle_y_pos, paddle_height):
	var hit_offset = (global_position.y - paddle_y_pos) / (paddle_height / 2.0)
	hit_offset = clamp(hit_offset, -1.0, 1.0)
	var min_y = 0.25
	var min_x = 0.45
	if abs(hit_offset) < min_y:
		if hit_offset >= 0.0:
			hit_offset = min_y
		else:
			hit_offset = -min_y
	var x_dir = -sign(move_dir.x)
	if x_dir == 0:
		x_dir = [-1, 1].pick_random()
	var new_dir = Vector2.ZERO
	new_dir.y = hit_offset
	new_dir.x = x_dir * sqrt(1.0 - new_dir.y * new_dir.y)
	new_dir = new_dir.normalized()
	if last_paddle_move_dir != Vector2.ZERO:
		var same_path = abs(new_dir.normalized().dot(last_paddle_move_dir.normalized())) > same_path_threshold
		if same_path:
			new_dir.y *= -1
			if abs(new_dir.y) < 0.45:
				new_dir.y = 0.45 * [-1, 1].pick_random()
			new_dir.x = x_dir * sqrt(1.0 - new_dir.y * new_dir.y)
			new_dir = new_dir.normalized()
	if abs(new_dir.x) < min_x:
		new_dir.x = x_dir * min_x
		if new_dir.y == 0.0:
			new_dir.y = 0.45 * [-1, 1].pick_random()
		else:
			new_dir.y = sign(new_dir.y) * sqrt(1.0 - new_dir.x * new_dir.x)
		new_dir = new_dir.normalized()
	move_dir = new_dir
	last_paddle_move_dir = move_dir
	var screen_height = get_viewport_rect().size.y
	var ball_half_height = get_size().y * 0.5
	var near_top_wall = global_position.y <= ball_half_height + 8.0
	var near_bottom_wall = global_position.y >= screen_height - ball_half_height - 8.0
	if near_top_wall and move_dir.y < 0.0:
		move_dir.y = abs(move_dir.y)
		move_dir.x = x_dir * sqrt(1.0 - move_dir.y * move_dir.y)
	if near_bottom_wall and move_dir.y > 0.0:
		move_dir.y = -abs(move_dir.y)
		move_dir.x = x_dir * sqrt(1.0 - move_dir.y * move_dir.y)
	move_dir = move_dir.normalized()
	speed += speed_increase_per_bounce
	speed = min(speed, MAX_SPEED)
	global_position.x += x_dir * (get_size().x * 0.5 + 6.0)
	play_beep()
	bounced.emit(self)

func reset(reset_pos):
	global_position = reset_pos
	speed = START_SPEED
	move_dir.x = [-1, 1].pick_random()
	move_dir.y = randf() * [-1, 1].pick_random()
	move_dir = move_dir.normalized()
	active = false
	touching_bodies.clear()
	ball_contact_cooldown = 0.0

func get_size():
	return cshape.shape.get_rect().size

func play_beep():
	var beep = [beep1, beep2].pick_random()
	beep.pitch_scale = [0.8, 1.0, 1.2].pick_random()
	beep.play()
