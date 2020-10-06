import socket
import json
import numpy as np
import os
import subprocess

class GodotEnvironment:
    def __init__(self, params={}):
        self.host = None
        self.port = None

        self.socket = None
        self.client_socket = None

        self.godot_process = None
        self.is_godot_launched = False
        self.is_rendering = True

        self.set_params_from_dict(params)


    def set_params_from_dict(self, params={}):
        self.host = params.get("host", '127.0.0.1')
        self.port = params.get("port", 4242)


    # Connection functions =============================================================================================


    def initialize_socket(self):
        """
        Creates a socket
        :return:
        """
        self.socket = socket.socket(socket.AF_INET, socket.SOCK_STREAM)

    def end_connection(self):
        """Closes the socket, and then reset it. Also reset client socket."""
        self.socket.close()
        self.socket = None
        self.client_socket = None

    def wait_for_connection(self):
        """"""
        self.socket.bind((self.host, self.port))
        self.socket.listen()
        self.client_socket, addr = self.socket.accept()
        print('Connected by', addr)

    def create_request(self, initialization=False, termination=False, action=None):
        request = {}
        request["initialization"] = initialization
        request["termination"] = termination
        request["render"] = self.is_rendering
        if initialization == False and termination == False:
            if isinstance(action, np.ndarray):
                action = action.tolist()
            request["action"] = int(action)
        request = json.dumps(request).encode()
        #print(request)
        return request

    def get_environment_state(self):
        condition = False
        data_in = None
        while condition != True:
            data_in = self.client_socket.recv(10000)
            data_in = data_in.decode()
            if len(data_in) > 4:
                condition = True

        data_in = json.loads(data_in)  # TODO: change the format of the data, and therefore change that too
        #print(data_in)
        return data_in


    # main functions ===================================================================================================


    def reset(self, render):
        """
        Gets the initial state of the environment
        :return: the first state of the environment
        """

        if (render != self.is_rendering) and self.is_godot_launched:
            if self.socket is None:
                self.initialize_socket()
            self.wait_for_connection()

            termination_request = self.create_request(termination=True)
            self.client_socket.sendall(termination_request)
            self.end_connection()
            self.is_godot_launched = False
            self.is_rendering = render


        if self.socket is None:
            self.initialize_socket()

        if self.is_godot_launched == False:
            godot_path = os.path.join("c:/", "Users", "Hugo", "Desktop", "Godot_v3.2.3-stable_win64.exe")
            environment_path = os.path.join("c:/", "Users", "Hugo", "Documents", "AI", "projects", "LonesomeTown",
                                            "godot_environments", "test_tcp", "Godot-Test-v0.pck")
            command = "{} --main-pack {}".format(godot_path, environment_path)
            if not self.is_rendering:
                command = command + " --disable-render-loop --no-window"
            self.godot_process = subprocess.Popen(command, shell=True)
            self.is_godot_launched = True

        self.wait_for_connection()
        # send the first request
        first_request = self.create_request(initialization=True)
        self.client_socket.sendall(first_request)

        data_in = self.get_environment_state()
        state = data_in["state"]
        state[0] /= 250
        state[1] /= 150
        return state

    def step(self, action):
        """
        sending an action to the agent and returns the reward it earned, the new state of the environment and a boolean
        indicating whether the game is done.
        :param action: 2D array containing values between -1 and 1
        :return:
        """
        request = self.create_request(action=action)
        self.client_socket.sendall(request)

        data_in = self.get_environment_state()
        state = data_in["state"]
        state[0] /= 250
        state[1] /= 150
        reward = data_in["reward"]
        done = data_in["done"]
        n_frames = data_in["n_frames"]
        reward = reward/n_frames
        if done == True:
            self.end_connection()
        return state, reward, done, n_frames

    def render(self):
        if not self.is_rendering:
            self.is_rendering = True
            if self.is_godot_launched:
                #self.godot_process.kill()
                self.create_request(termination=True)
                self.is_godot_launched = False

    def dont_render(self):
        if self.is_rendering:
            self.is_rendering = False
            if self.is_godot_launched:
                self.create_request(termination=True)
                self.is_godot_launched = False

