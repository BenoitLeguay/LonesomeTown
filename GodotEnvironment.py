import socket
import json
import numpy as np
import os
import subprocess
import ast

class GodotEnvironment:
    def __init__(self, params={}):
        self.host = None
        self.port = None

        self.godot_path_str = None
        self.env_path_str = None

        self.socket = None
        self.client_socket = None

        self.godot_process = None
        self.is_godot_launched = False
        self.is_rendering = True

        self.agent_names = None
        self.state_min = None
        self.state_max = None

        self.display_actions = None
        self.display_states = None

        self.set_params_from_dict(params)


    def set_params_from_dict(self, params={}):
        self.host = params.get("host", '127.0.0.1')
        self.port = params.get("port", 4242)
        self.godot_path_str = params.get("godot path", "")
        self.env_path_str = params.get("environment path", "")
        self.agent_names = params.get("agent names", [])
        self.state_min = np.array(params.get("state min", [0, 0]))
        self.state_max = np.array(params.get("state min", [1000, 1000]))
        self.display_actions = params.get("display actions", False)
        self.display_states = params.get("display states", False)


    # Connection functions =============================================================================================


    def initialize_socket(self):
        self.socket = socket.socket(socket.AF_INET, socket.SOCK_STREAM)

    def end_connection(self):
        """Closes the socket, and then reset it. Also reset client socket."""
        self.socket.close()
        self.socket = None
        self.client_socket = None

    def wait_for_connection(self):
        """
        Runs until a connection is made
        :return:
        """
        self.socket.bind((self.host, self.port))
        self.socket.listen()
        self.client_socket, addr = self.socket.accept()
        print('Connected by', addr)

    def create_request(self, initialization=False, termination=False, agents_data=None):
        """
        Handles the type of request to be sent and shape the request into the correct form.
        :param initialization: boolean, indicates if the request must be in the form of an initialization request.
        :param termination: boolean, indicates if the request must be in the form of an termination request.
        :param agents_data: list of dictionaries contaning the fields "name" (string) and "action" (int) the value of
        the action to be taken by the actor.
        :return: The request is a dictionary stored into a string, ready to be sent to the simulator
        """
        request = {}
        request["initialization"] = initialization
        request["termination"] = termination
        request["render"] = self.is_rendering
        if initialization == False and termination == False:
            for n_agent in range(len(agents_data)):
                # convert the actions to the correct type
                if isinstance(agents_data[n_agent]["action"], np.integer):
                    agents_data[n_agent]["action"] = int(agents_data[n_agent]["action"])
            request["agents_data"] = agents_data
            #if isinstance(action, np.ndarray):
            #    action = action.tolist()
            #request["action"] = int(action)
        request = json.dumps(request).encode()
        #print(request)
        return request

    def get_environment_state(self):
        """
        Receive data and format it to the correct shape
        :return:
        """
        data_in = None
        condition = False
        # stay in the loop until data is received
        while condition != True:
            data_in = self.client_socket.recv(10000)
            data_in = data_in.decode()
            if len(data_in) > 4:
                condition = True
        # convert data to json and then to the appropriated format (for states)
        data_in = json.loads(data_in)  # TODO: change the format of the data, and therefore change that too
        for n_agent, agent_data in enumerate(data_in["agents_data"]):
            if isinstance(agent_data['state'], str):
                data_in["agents_data"][n_agent]["state"] = ast.literal_eval(agent_data["state"])
        return data_in


    # main functions ===================================================================================================


    def reset(self, render):
        """
        Initialize the environment and returns its first state.
        To do so, it:
        - handles the rendering type
        - Creates a godot simulation instance in a subprocess if it is needed
        - Creates a tcp connexion with the simulation
        - Gets the initial state of the environment through the tcp connection
        - Scale the state
        :param render: boolean, indicates whether the simulator displays, in which case the game executes at normal
        speed.
        In the other case, the game executes at a higher rate (max 17 times faster, for now)
        :return: initial state of the environment (dictionary)
        """
        # Handling the case where we changed te rendering type and the godot engine is launched (not the first time the
        # class is used). We want to close the godot session and create a new one with a different rendering parameter.
        if (render != self.is_rendering) and self.is_godot_launched:
            if self.socket is None:
                self.initialize_socket()
            self.wait_for_connection()

            termination_request = self.create_request(termination=True)
            self.client_socket.sendall(termination_request)
            self.end_connection()
            self.is_godot_launched = False
            self.is_rendering = render

        # Initializing the socket if it's not already done.
        if self.socket is None:
            self.initialize_socket()

        # Initializing a subprocess where a godot instance is launched, if it doesn't exist yet.
        if not self.is_godot_launched:
            godot_path = os.path.abspath(os.path.join(os.sep, *self.godot_path_str.split("/")))
            environment_path = os.path.abspath(os.path.join(os.sep, *self.env_path_str.split("/")))
            command = "{} --main-pack {}".format(godot_path, environment_path)
            if not self.is_rendering:
                command = command + " --disable-render-loop --no-window"
            self.godot_process = subprocess.Popen(command, shell=True)
            self.is_godot_launched = True

        # Creating the connexion with the simulator
        self.wait_for_connection()
        # Send the first request to get the initial state of the simulation
        first_request = self.create_request(initialization=True)
        self.client_socket.sendall(first_request)

        # Get the first state of the simulation, scale it and return it
        data_in = self.get_environment_state()
        if self.display_states:
            print(data_in)
        states_data = data_in["agents_data"]
        #states_data = self.scale_states_data(states_data)

        return states_data

    def step(self, actions_data):
        """
        sending an action to the godot agent and returns the reward it earned, the new state of the environment and a
        boolean indicating whether the game is done.
        :param action: dictionary
        :return:states_data (dic), rewards_data (dic), done (boolean), n_frames (int)
        """
        request = self.create_request(agents_data=actions_data)
        if self.display_actions:
            print(request)
        self.client_socket.sendall(request)

        data_in = self.get_environment_state()
        if self.display_states:
            print(data_in)

        agents_data = data_in["agents_data"]
        # splitting data
        states_data = []
        rewards_data = []
        for agent_data in agents_data:
            state_data = {"name": agent_data["name"], "state": agent_data["state"]}
            states_data.append(state_data)
            reward_data = {"name": agent_data["name"], "reward": agent_data["reward"]}
            rewards_data.append(reward_data)

        n_frames = data_in["n_frames"]
        # scaling reward
        for n_agent in range(len(agents_data)):
            agents_data[n_agent]["reward"] /= n_frames
        # scaling states
        # states_data = self.scale_states_data(states_data)

        # handling ending condition
        done = data_in["done"]
        if done:
            self.end_connection()

        return states_data, rewards_data, done, n_frames

    def scale_states_data(self, states_data):
        """
        Scale states data in a dictionary
        :param states_data: dictionary
        :return: dictionary
        """
        for state_id, state_data in enumerate(states_data):
            state = state_data["state"]
            state = self.scale_state(state)
            states_data[state_id]["state"] = state
        return states_data

    def scale_state(self, state):
        """ Scale a single state (np array)"""
        scaled_state = (state - self.state_min) / (self.state_max - self.state_min)
        return scaled_state

