#!/usr/bin/env python3

import os
import random
import re
import checklib
import requests
import json
import sys
import copy
from checklib import *
from websockets.sync.client import connect
from websockets.exceptions import WebSocketException
from checklib import status

argv = copy.deepcopy(sys.argv)
sys.path.insert(0, os.path.abspath(os.path.join(os.path.dirname(__file__), "..")))

from backend import *

delims = ['username','password','id','email','if','and','or','sleep','where','like','rlike','substring','substr','concat','concat_ws','group_concat','case','when','then','as']

class Checker(BaseChecker):
    timeout: int = 20

    def __init__(self, *args, **kwargs):
        super(Checker, self).__init__(*args, **kwargs)
        self.cm = CheckMachine(self)
    
    def action(self, action, *args, **kwargs):
        try:
            super(Checker, self).action(action, *args, **kwargs)
        except requests.exceptions.ConnectionError:
            self.cquit(Status.DOWN, 'Connection error', 'Got requests connection error')
        except WebSocketException:
            self.cquit(Status.DOWN, 'Connection error', 'Got ws connection error')
        except ConnectionRefusedError:
            self.cquit(Status.DOWN, "Connection refused", "Connection refused")
    
    def check(self):
        sess = get_initialized_session()
        username_ok = 0
        while not username_ok:
            username_ok = 1
            username, password, email = Utils.rnd_lowercase(random.randint(4, 32)), Utils.rnd_string(random.randint(8,50)), Utils.rnd_string(random.randint(8,50)) + '@gmail.com'
            for delim in delims:
                if delim in username:
                    username_ok = 0
                    break
        self.cm.register(sess, username, password, email)
        self.cm.login(sess, username, password)

        res = self.cm.search(sess, username, email)
        if not res:
            self.cquit(Status.MUMBLE, 'Failed to search gmail', f'Failed to search gmail with user "{username}", password "{password}", email {email}')

        data = Utils.rnd_string(random.randint(10,1024))
        res, msg = self.cm.profile(sess, data)
        if not res:
            self.cquit(Status.MUMBLE, 'Failed to upload file', f'checker.check(): {msg}')
        ok, msg = self.cm.check_profile(sess, msg, data)
        if not ok:
            self.cquit(Status.MUMBLE, 'Upload file malfunctioned', msg)
        self.cm.game(sess)
        self.cm.fetch(sess)
        self.cm.convert(sess)
        self.cm.story(sess)

        self.cquit(Status.OK)

    def put(self, flag_id: str, flag: str, vuln: str):
        lock = FileLock(f"/tmp/.web1_{self.cm.port}")
        try:
            client = paramiko.SSHClient()
            client.set_missing_host_key_policy(paramiko.AutoAddPolicy())
            client.connect('192.168.0.1', port=self.cm.ssh_port, username='root', key_filename="/checkers/id_rsa")
            with lock:
                filename = f'/tmp/web1_{self.cm.port}'
                if not os.path.exists(filename) or int(open(filename, 'r').read())==0:
                    client.exec_command(f"echo {flag} > /flag1")
                    client.close()
                    open(filename, 'w').write('1')
                elif int(open(filename, 'r').read())==1:
                    client.exec_command(f"echo {flag} > /flag2")
                    client.close()
                    open(filename, 'w').write('0')
        except Exception as e:
            self.cquit(Status.MUMBLE, 'put failed', f'{e}')
        self.cquit(Status.OK)

    def get(self, flag_id: str, flag: str, vuln: str):
        client = paramiko.SSHClient()
        client.set_missing_host_key_policy(paramiko.AutoAddPolicy())
        client.connect('192.168.0.1', port=self.cm.ssh_port, username='root',  key_filename="/checkers/id_rsa")

        stdin, stdout, stderr = client.exec_command("cat /flag1")
        res1 = stdout.readline()
        if res1.strip()!=flag:
            stdin, stdout, stderr = client.exec_command("cat /flag2")
            res2 = stdout.readline()
            if res2.strip()!=flag:
                self.cquit(Status.CORRUPT, 'get failed', f'Flag: {res1};{res2}')
        client.close()
        self.cquit(Status.OK)


if __name__ == '__main__':
    c = Checker(argv[2])

    try:
        c.action(argv[1], *argv[3:])
    except c.get_check_finished_exception():
        cquit(Status(c.status), c.public, c.private)
