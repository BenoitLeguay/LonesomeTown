extends KinematicBody2D

# variables to keep
export var speed: = 10

var _velocity: = Vector2.ZERO
var direction: = Vector2.ZERO

var attack:= "None"
var attack_init_time := 0.0
var is_attacking := false
var players_attacked := []

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
	if time_elapsed_since_attack_init >= 200000:
		attack = "None"
		is_attacking = false
		players_attacked = []

func _physics_process(delta):
	execute_actions()
	direction = get_direction()
	_velocity = calculate_move_velocity(_velocity, direction, speed)
	_velocity = move_and_slide(_velocity)
	reward -= 0.01
	handle_attacks()
	
# collision functions =========================================================

# other funtions ==============================================================
func handle_attacks():
	if attack != "None":
		var attack_collision_shape = "melee_atk_" + attack
		var overlapping_bodies = get_node(attack_collision_shape).get_overlapping_bodies()
		for body in overlapping_bodies:
			if body.is_in_group("players") and !players_attacked.has(body) and !is_self(body):
				body.reduce_health()
				reward +=1
				players_attacked.append(body)

func get_reward():
	return reward

func reset_reward():
	reward = 0.0
	
func is_self(node):
	#print(node.get_path())
	if node.get_path() == get_path():
		return true
	else:
		return false


func reduce_health():
	health -=1
	#print(get_path())
	print(health)
	reward -=0.5
	
func handle_death():
	if health == 0:
		is_dead = true
		reward -=1

func choose_actions_from_remote_data(action):
	if action <=4:
		choose_direction_from_remote_data(action)
	else:
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
	if action == 5:
		attack = "up"
		attack_init_time = OS.get_ticks_usec()
		is_attacking = true
	elif action == 6:
		attack = "right"
		attack_init_time = OS.get_ticks_usec()
		is_attacking = true
	elif action == 7:
		attack = "down"
		attack_init_time = OS.get_ticks_usec()
		is_attacking = true
	elif action == 8:
		attack = "left"
		attack_init_time = OS.get_ticks_usec()
		is_attacking = true

func execute_actions():
	if is_attacking == false:
		if Input.is_action_just_pressed("melee_up"):
			attack = "up"
			attack_init_time = OS.get_ticks_usec()
			is_attacking = true
		elif Input.is_action_just_pressed("melee_right"):
			attack = "right"
			attack_init_time = OS.get_ticks_usec()
			is_attacking = true
		elif Input.is_action_just_pressed("melee_down"):
			attack = "down"
			attack_init_time = OS.get_ticks_usec()
			is_attacking = true
		elif Input.is_action_just_pressed("melee_left"):
			attack = "left"
			attack_init_time = OS.get_ticks_usec()
			is_attacking = true
		

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
