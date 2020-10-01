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

        self.set_params_from_dict(params)


    def set_params_from_dict(self, params={}):
        self.host = params.get("host", '127.0.0.1')
        self.port = params.get("port", 4242)

    def initialize_socket(self):
        self.socket = socket.socket(socket.AF_INET, socket.SOCK_STREAM)

    def end_connection(self):
        self.socket.close()

    def wait_for_connection(self):
        self.socket.bind((self.host, self.port))
        self.socket.listen()
        self.client_socket, addr = self.socket.accept()
        print('Connected by', addr)

    def create_request(self, initialization=False, action=None):
        request = {}
        request["initialization"] = initialization
        if isinstance(action, np.ndarray):
            action = action.tolist()
        request["action"] = action
        request = json.dumps(request).encode()
        return request

    def get_environment_state(self):
        condition = False
        data_in = None
        while condition != True:
            data_in = self.client_socket.recv(80)
            # print(data_in)
            data_in = data_in.decode()
            if len(data_in) > 4:
                condition = True
        # print(data_in)
        data_in = json.loads(data_in)  # TODO: change the format of the data, and therefore change that too
        return data_in

    def reset(self):
        """
        Gets the initial state of the environment
        :return: the first state of the environment
        """
        self.initialize_socket()
        subprocess.Popen("{} --main-pack {}".format(
            os.path.join("c:/", "Users", "Hugo", "Desktop", "Godot_v3.2.3-stable_win64.exe"),
            os.path.join("c:/", "Users", "Hugo", "Documents", "dev", "godot_projects", "test_tcp",
                         "Godot-Test-v0.pck")), shell=True)
        print("coucou")
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
        #print(data_in)
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
        pass