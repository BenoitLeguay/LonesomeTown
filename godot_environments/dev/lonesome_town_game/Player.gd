extends KinematicBody2D

# variables to keep
export var speed: = 10

var _velocity: = Vector2.ZERO
var direction: = Vector2.ZERO

var attack_direction:= "None"
var attack_init_time := 0.0
var is_attacking := false
var players_attacked := []
var bullet_sent := false
var ranged_mode := false
export var time_to_wait_before_attack := 200000 #1000000 

# ai variables
export var ai_control: bool = false
var reward: float = 0.0

var health := 3
var is_dead := false

# main functions ==============================================================

func _ready():
	add_to_group("players")
	pass

func _process(delta):
	var curr_time = OS.get_ticks_usec()
	var time_elapsed_since_attack_init = curr_time - attack_init_time
	if time_elapsed_since_attack_init >= time_to_wait_before_attack / Engine.get_time_scale():
		attack_direction = "None"
		is_attacking = false
		players_attacked = []
		

func _physics_process(delta):
	execute_actions()
	ranged_mode = handle_ranged_mode(ranged_mode)
	direction = get_direction()
	_velocity = calculate_move_velocity(_velocity, direction, speed)
	_velocity = move_and_slide(_velocity)
	handle_attacks()
	reward -= 0.01
	if Input.is_action_just_pressed("melee_down"):
		print(position)
	
# collision functions =========================================================

# other funtions ==============================================================

func reinitialize():
	var _velocity: = Vector2.ZERO
	var direction: = Vector2.ZERO
	var attack_direction:= "None"
	reward = 0.0
	health = 3
	is_dead = false

func handle_ranged_mode(ranged):
	if !ai_control:
		ranged = Input.is_action_pressed("ranged_mode")
	return ranged
	
func create_bullet():
	if !bullet_sent:
		var bullet_scene = preload("res://src/items/Bullet.tscn")
		var bullet = bullet_scene.instance()
		var vec_attack_direction = str_direction_to_vector(attack_direction)
		bullet.shooter_path = get_path()
		bullet.direction = vec_attack_direction
		var path = str(get_owner().get_path()) + "/YSort"
		bullet.set_position(get_position() + vec_attack_direction * 50)
		get_node(path).add_child(bullet)
		bullet_sent = true

func handle_attacks():
	if attack_direction != "None":
		if ranged_mode:
			create_bullet()
		else:
			var attack_collision_shape = "melee_atk_" + attack_direction
			var overlapping_bodies = get_node(attack_collision_shape).get_overlapping_bodies()
			for body in overlapping_bodies:
				if body.is_in_group("players") and !players_attacked.has(body) and !is_self(body):
					var reward_from_action = body.reduce_health()
					reward += reward_from_action
					players_attacked.append(body)

func get_reward():
	return reward

func reset_reward():
	reward = 0.0
	
func is_self(node):
	if node.get_path() == get_path():
		return true
	else:
		return false


func reduce_health():
	var reward_start = reward
	health -=1
	handle_death()
	reward -=0.5
	return reward - reward_start
	
func handle_death():
	if health == 0:
		is_dead = true
		reward -=0.5

func choose_actions_from_remote_data(action):
	if action <=4:
		choose_direction_from_remote_data(action)
	else:
		direction = Vector2(0, 0) # probablement à changer plus tard.
		choose_attack_from_remote_data(action)

func choose_direction_from_remote_data(action):
	if action == 0:
		direction = Vector2(0, -1)
	elif action == 1:
		direction = Vector2(1, 0)
	elif action == 2:
		direction = Vector2(0, 1)
	elif action == 3:
		direction = Vector2(-1, 0)
	elif action == 4:
		direction = Vector2(0, 0)
	return direction

func choose_attack_from_remote_data(action):
	if is_attacking == false:
		if action == 5:
			apply_attack("up")
		elif action == 6:
			apply_attack("right")
		elif action == 7:
			apply_attack("down")
		elif action == 8:
			apply_attack("left")
		elif action == 9:
			apply_attack("up", true)
		elif action == 10:
			apply_attack("right", true)
		elif action == 11:
			apply_attack("down", true)
		elif action == 12:
			apply_attack("left", true)
		
func apply_attack(direction, ranged=false):
	attack_direction = direction
	attack_init_time = OS.get_ticks_usec()
	is_attacking = true
	bullet_sent = false
	ranged_mode = ranged

func execute_actions():
	if is_attacking == false and ai_control == false:
		if Input.is_action_just_pressed("melee_up"):
			apply_attack("up")
		elif Input.is_action_just_pressed("melee_right"):
			apply_attack("right")
		elif Input.is_action_just_pressed("melee_down"):
			apply_attack("down")
		elif Input.is_action_just_pressed("melee_left"):
			apply_attack("left")

func get_direction() -> Vector2:
	if ai_control != true:
		return Vector2(
			Input.get_action_strength("move_right") - Input.get_action_strength("move_left"), 
			Input.get_action_strength("move_down") - Input.get_action_strength("move_up")
		)
	else:
		return direction
		
func calculate_move_velocity( linear_velocity: Vector2, direction: Vector2, speed: int) -> Vector2:
	var out: = linear_velocity
	out = speed * direction
	return out

func str_direction_to_vector(str_direction):
	var vec_direction = Vector2.ZERO
	if str_direction == "up":
		vec_direction = Vector2(0, -1)
	elif str_direction == "right":
		vec_direction = Vector2(1, 0)
	elif str_direction == "down":
		vec_direction = Vector2(0, 1)
	elif str_direction == "left":
		vec_direction = Vector2(-1, 0)
	return vec_direction
		
