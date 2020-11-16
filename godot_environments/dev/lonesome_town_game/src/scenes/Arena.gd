extends Node2D

# connectivity variables
var socket = StreamPeerTCP.new()
var is_really_connected = false
var data_to_send = {}

var frames_since_last_action_received = 0
var frames_since_start = 0
var frames_when_data_sent = 0
export var threshold_frame: = 4

var is_first_step = false
var can_end_game = false
var information_sent = true
var prev_time = 0
export var hard_coded_fps := 0

var is_rendering = false

var agents_names = ["Player", "Player2"]


# Called when the node enters the scene tree for the first time.
func _ready():
	randomize()
	var err_message = socket.connect_to_host("127.0.0.1", 4243)
	#time_start = OS.get_unix_time()
	prev_time = OS.get_ticks_usec()
	set_random_players_positions()


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(_delta):
	if frames_since_start > 800 or is_a_player_dead():
		can_end_game = true
	set_execution_speed()
	# checking the connection
	check_connection()
	# if connected, do all the input and output functions when required.
	if is_really_connected:
		receive_and_process_data()
		prepare_and_send_data()
		
	
func _physics_process(_delta):
	frames_since_start +=1
	frames_since_last_action_received +=1
	
func set_execution_speed():
	var fps_used = 60
	if is_rendering == false:
		var cur_time = OS.get_ticks_usec()
		var fps_est = 1000000.0/(cur_time - prev_time)
		prev_time = cur_time
		fps_used = min(fps_est,1000)
	# set the physics process speed
	#print(fps_used)
	if hard_coded_fps != 0:
		fps_used = hard_coded_fps
	Engine.set_iterations_per_second(fps_used)
	# set the clock speed accordingly.
	Engine.set_time_scale(fps_used/60)
	
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
	
func send_actions_to_agents(agents_data):
	for agent_data in agents_data:
		var agent_path = "YSort/" + agent_data["name"]
		get_node(agent_path).choose_actions_from_remote_data(agent_data["action"])

func reinitialize_parameters():
	frames_since_start = 0
	frames_since_last_action_received = 0
	frames_when_data_sent = 0
	can_end_game = false

func reinitialize_players():
	set_random_players_positions()
	reinitialize_players_information()
	

func reinitialize():
	reinitialize_parameters()
	reinitialize_players()

func process_remote_data(received_bytes):
	# process the input data. Detects whether it's the first data received.
	# If not, get the action to do.
	var converted_string = socket.get_string(received_bytes)
	var input_dict = JSON.parse(converted_string).result
	if input_dict["initialization"] == true:
		is_first_step = true
		reinitialize()
		is_rendering = input_dict["render"]
	elif input_dict["termination"] == true:
		get_tree().quit()
		socket.disconnect_from_host()
	else:
		send_actions_to_agents(input_dict["agents_data"])
		#direction = choose_direction_from_remote_data(input_dict["action"])

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
		information_sent = false

func prepare_data_to_send():
	var data_to_send = {}
	data_to_send["agents_data"] = []
	for agent_name in agents_names:
		var agent_path = "YSort/" + agent_name
		var agent_position = vector2_to_array(get_node(agent_path).get_position())
		
		var other_agents_positions = []
		for other_agent_name in agents_names:
			if other_agent_name != agent_name:
				var other_agent_path = "YSort/" + other_agent_name
				var other_agent_position = vector2_to_array(get_node(other_agent_path).get_position())
				other_agents_positions += other_agent_position
		var state := []
		state += agent_position
		if !other_agents_positions.empty():
			state += other_agents_positions
		
		var agent_dict = {"name": agent_name, "state": state}
		if is_first_step == false:
			agent_dict["reward"] = get_node(agent_path).get_reward()
			
		data_to_send["agents_data"].append(agent_dict)# += agent_dict
		
	if is_first_step == false:
		data_to_send["n_frames"] = frames_since_last_action_received
		data_to_send["done"] = can_end_game
	
	return data_to_send
	
func vector2_to_array(vector):
	return [vector.x, vector.y]
	
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
		data_to_send = prepare_data_to_send()
		send_data(data_to_send)
		information_sent = true
		is_first_step = false

func handle_other_sendings():
	# if four physical frames have passed since the last action received,
	# send data to python
	if frames_since_last_action_received >= threshold_frame and information_sent == false:
		data_to_send = prepare_data_to_send()
		send_data(data_to_send)
		frames_when_data_sent = frames_since_last_action_received
		information_sent = true
		
		if can_end_game == true:
			# handling the end of the game
			# it should be noted that the game keeps executing after 
			#reload_current_scene(), until the end of the process loop.
			pass
			# I used to do the following
			#socket.disconnect_from_host()
			#get_tree().reload_current_scene()
		reset_agents_rewards()
		#reward = 0.0

func reset_agents_rewards():
	for agent_name in agents_names:
		var agent_path = "YSort/" + agent_name
		get_node(agent_path).reset_reward()

func is_a_player_dead():
	for player in get_tree().get_nodes_in_group("players"):
		if player.is_dead:
			return true
	return false
	
func set_random_players_positions():
	var spawn_points = get_tree().get_nodes_in_group("spawn points")
	var busy_spawn_points = []
	var players = get_tree().get_nodes_in_group("players")
	for player in players:
		var spawn_point = select_random_spawn_point(spawn_points, busy_spawn_points)
		busy_spawn_points += [spawn_point]
		player.set_position(spawn_point.get_position())
		
func select_random_spawn_point(spawn_points, busy_spawn_points):
	if busy_spawn_points.empty():
		var selected_spawn_point_index = randi() % spawn_points.size()
		return spawn_points[selected_spawn_point_index]
	else:
		var is_spawn_point_correct = false
		while !is_spawn_point_correct:
			var is_spawn_point_busy = false
			var selected_spawn_point_index = randi() % spawn_points.size()
			var selected_spawn_point = spawn_points[selected_spawn_point_index]
			for busy_spawn_point in busy_spawn_points:
				if busy_spawn_point == selected_spawn_point:
					is_spawn_point_busy = true
			if !is_spawn_point_busy:
				return selected_spawn_point
			
	
func reinitialize_players_information():
	var players = get_tree().get_nodes_in_group("players")
	for player in players:
		player.reinitialize()
