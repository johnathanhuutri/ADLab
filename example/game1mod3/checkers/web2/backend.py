import requests
from checklib import *
import websockets
import json
import random
import string
from requests_toolbelt import MultipartEncoder

PORT = 8888

class Utils:
    def rnd_string(length):
        return ''.join(random.choices(string.ascii_letters + string.digits, k=length))
    def rnd_lowercase(length):
        return ''.join(random.choices(string.ascii_lowercase, k=length))

class CheckMachine:
    @property
    def url(self):
        return f'http://{self.ip}:{self.port}/'

    @property
    def ip(self):
        return '192.168.0.1'

    @property
    def port(self):
        if self.c.host == '192.168.0.1':
            return 10102
        elif self.c.host == '192.168.0.2':
            return 10202

    @property
    def ssh_port(self):
        if self.c.host == '192.168.0.1':
            return 10122
        elif self.c.host == '192.168.0.2':
            return 10222

    def __init__(self, checker: BaseChecker):
        self.c = checker

    def register(self, session: requests.Session, username: str, password: str, email: str):
        resp = session.post(self.url + '/register.php', data={'username': username, 'password': password, 'email': email})
        self.c.check_response(resp, 'Failed to register', Status.MUMBLE)

    def login(self, session: requests.Session, username: str, password: str):
        resp = session.post(self.url + '/login.php', data={'username': username, 'password': password})
        self.c.check_response(resp, 'Failed to login', Status.MUMBLE)
        text = self.c.get_text(resp, 'Failed to get text')
        if 'Wrong username or password' in text:
                return False
        return True

    def search(self, session, username, email):
        resp = session.post(self.url + '/index.php', data={'username': username})
        self.c.check_response(resp, 'Failed to search', Status.MUMBLE)
        text = self.c.get_text(resp, 'search(): Failed to get text')
        if email not in text:
            return False
        return True

    def profile(self, session, data):
        fields = {
            'file': ('tmp.txt', data)
        }
        boundary = '----WebKitFormBoundary' + ''.join(random.sample(string.ascii_letters + string.digits, 16))
        data = MultipartEncoder(fields=fields, boundary=boundary)
        headers = {
            "Content-Type": data.content_type,
        }
        resp = session.post(self.url + '/profile.php', data=data, headers=headers)
        self.c.check_response(resp, 'Failed to upload file', Status.MUMBLE)
        text = self.c.get_text(resp, 'profile(): Failed to get text')
        if '/var/www/html' not in text:
            return False, text
        return True, text.split('/var/www/html')[1].split('.txt')[0] + '.txt'

    def check_profile(self, session, path, data):
        resp = session.get(self.url + path)
        self.c.check_response(resp, 'Failed to access uploaded file')
        text = self.c.get_text(resp, 'check_profile(): Failed to get text')
        if 'Not Found' in data:
            return False, 'File not found'
        if text != data:
            return False, f'Data was change: {data}\n{text}'
        return True, None

    def game(self, session):
        resp = session.get(self.url + f'/game.php?g1={random.randint(100000,999999999)}&g2={random.randint(100000,999999999)}')
        self.c.check_response(resp, 'Failed to play game')
        text = self.c.get_text(resp, 'game(): Failed to get text')
        if 'you not win this game!' not in text:
            self.c.cquit(Status.MUMBLE, 'Failed to play game', f'{text}')

    def fetch(self, session):
        urls = ['https://www.facebook.com/', 'https://mail.google.com/mail/u/0/#inbox', 'https://google.com']
        resp = session.get(self.url + f'/fetch.php?url={random.choice(urls)}')
        self.c.check_response(resp, 'Failed to fetch url')
        text = self.c.get_text(resp, f'fetch(): Failed to get text')
        if '1' not in text:
            self.c.cquit(Status.MUMBLE, 'Failed to fetch url', f'{text}')

    def convert(self, session):
        names = [Utils.rnd_string(random.randint(12,64)) for i in range(random.randint(1,5))]
        resp = session.get(self.url + f'/convert.php?map=strtoupper&names={",".join(names)}')
        self.c.check_response(resp, 'Failed to convert name')
        text = self.c.get_text(resp, f'fetch(): Failed to get text')
        for name in names:
            if name.upper() not in text:
                self.c.cquit(Status.MUMBLE, 'Failed to get uppercased name', f'{text}')

    def story(self, session):
        resp = session.get(self.url + f'/stories.php?dir=The_Forgotten_Key.html')
        self.c.check_response(resp, 'Failed to get story')
        text = self.c.get_text(resp, f'story(): Failed to get text')
        if 'The Forgotten Key' not in text:
            self.c.cquit(Status.MUMBLE, 'Failed to get The_Forgotten_Key.html')
        resp = session.get(self.url + f'/stories.php?dir=Echoes_of_Silence.html')
        self.c.check_response(resp, 'Failed to get story')
        text = self.c.get_text(resp, f'story(): Failed to get text')
        if 'Echoes of Silence' not in text:
            self.c.cquit(Status.MUMBLE, 'Failed to get Echoes_of_Silence.html')
        resp = session.get(self.url + f'/stories.php?dir=The_Last_Letter.html')
        self.c.check_response(resp, 'Failed to get story')
        text = self.c.get_text(resp, f'story(): Failed to get text')
        if 'The Last Letter' not in text:
            self.c.cquit(Status.MUMBLE, 'Failed to get The_Last_Letter.html')
        
