extends KinematicBody2D

# variables to keep
export var speed: = 10

var _velocity: = Vector2.ZERO
var direction: = Vector2.ZERO

# connectivity variables
var socket = StreamPeerTCP.new()
var is_really_connected = false
var data_to_send = {}


# ai variables
export var ai_control: bool = false
var reward: float = 0.0
var frames_since_last_action_received = 0
var frames_since_start = 0
var frames_when_data_sent = 0
export var threshold_frame: = 4

var is_first_step = false
var can_end_game = false
var no_information_sent = false
var prev_time = 0

var is_rendering = true

# main functions ==============================================================

func _ready():
	var err_message = socket.connect_to_host("127.0.0.1", 4242)
	#time_start = OS.get_unix_time()
	prev_time = OS.get_ticks_usec()

func _process(delta):
	var fps_used = 60
	if frames_since_start > 800:
		can_end_game = true
	if is_rendering == false:
		# délire du mec
		var cur_time = OS.get_ticks_usec()
		var fps_est = 1000000.0/(cur_time - prev_time)
		#print(fps_est)
		prev_time = cur_time
		# set the physics process speed
		fps_used = min(fps_est,1000)
		
	Engine.set_iterations_per_second(fps_used)
	# set the clock speed accordingly.
	Engine.set_time_scale(fps_used/60)
	
	# checking the connection
	check_connection()
	
	# if connected, do all the input and output functions when required.
	if is_really_connected:
		receive_and_process_data()
		prepare_and_send_data()
		
		
		

func _physics_process(delta):
	direction = get_direction()
	_velocity = calculate_move_velocity(_velocity, direction, speed)
	_velocity = move_and_slide(_velocity)
	reward -= 0.01
	frames_since_start +=1
	frames_since_last_action_received +=1
	
# collision functions =========================================================

func _on_chest_detector_body_entered(body):
	# when the character hits the chest, increase reward and end the game
	reward += 1
	can_end_game = true

# other funtions ==============================================================
	
func check_connection():
	# Checking connection to the server
	if socket.get_status() == 2 and !is_really_connected:
			is_really_connected = true
	
func get_information():
	# returne a boolean indicating if something has been received, and the length
	# in bytes of the received data sequence
	var has_received_something = false
	var received_bytes = socket.get_available_bytes()
	if received_bytes > 0:
		has_received_something = true
	return [received_bytes, has_received_something]
	
func process_remote_data(received_bytes):
	# process the input data. Detects whether it's the first data received.
	# If not, get the action to do.
	var converted_string = socket.get_string(received_bytes)
	var input_dict = JSON.parse(converted_string).result
	if input_dict["initialization"] == true:
		is_first_step = true
		is_rendering = input_dict["render"]
	elif input_dict["termination"] == true:
		get_tree().quit()
		socket.disconnect_from_host()
	else:
		direction = choose_direction_from_remote_data(input_dict["action"])

func receive_and_process_data():
	var has_received_something = false
	var input_information = get_information()
	var information_length = input_information[0]
	has_received_something = input_information[1]
	# if data recieved, process the data
	if has_received_something == true:
		process_remote_data(information_length)
		# take into account the frames passed since the sending of the last state
		frames_since_last_action_received -= frames_when_data_sent
		no_information_sent = true



func prepare_data_to_send():
	position = get_position()
	
	var data_to_send = {}
	data_to_send["state"] = [position.x, position.y]
	if is_first_step == false:
		data_to_send["reward"] = reward	
		data_to_send["n_frames"] = frames_since_last_action_received
		data_to_send["done"] = can_end_game
	
	return data_to_send
	
func prepare_and_send_data():
	# making a distinction between first sending and the others
	handle_first_sending()
	handle_other_sendings()

func send_data(data_to_send):
	# send data in the form of a dictionary put into ascii characters
	data_to_send = JSON.print(data_to_send).to_ascii()
	socket.put_data(data_to_send)
	
func handle_first_sending():
	# if this is the first time data is sent to python, the format of the 
	# data is different
	if is_first_step == true:
		#print("premier envoi:")
		data_to_send = prepare_data_to_send()
		send_data(data_to_send)
		no_information_sent = false
		is_first_step = false

func handle_other_sendings():
	# if four physical frames have passed since the last action received,
	# send data to python
	if frames_since_last_action_received >= threshold_frame and no_information_sent == true:
		#print("un envoi:")
		#print(no_information_sent)
		data_to_send = prepare_data_to_send()
		#print(data_to_send)
		send_data(data_to_send)
		frames_when_data_sent = frames_since_last_action_received
		no_information_sent = false
		
		if can_end_game == true:
			# handling the end of the game
			# it should be noted that the game keeps executing after 
			#reload_current_scene(), until the end of the process loop.
			socket.disconnect_from_host()
			get_tree().reload_current_scene()
		reward = 0.0

func choose_direction_from_remote_data(action):
	pass
	if action == 0:
		direction = Vector2(0, -1)
	elif action == 1:
		direction = Vector2(1, 0)
	elif action == 2:
		direction = Vector2(0, 1)
	elif action == 3:
		direction = Vector2(-1, 0)
	return direction

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





