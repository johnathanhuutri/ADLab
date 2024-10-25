# Attack & Defense Lab

This repo contains 3 labs and with each lab, you will need to config differently:
- Lab1: Central <--> Proxy <--> Service
- Lab2: Central <--> Service
- Lab3: Central

## Challenge Writing

```
FROM ubuntu:22.04

### DO NOT CHANGE THESE LINES ##################
ENV DEBIAN_FRONTEND=noninteractive

RUN apt-get update
RUN apt-get install -y openssh-server
RUN apt-get clean

RUN useradd -m ctf && \
	echo "ctf:ctf" | chpasswd && \
	echo /bin/bash | chsh ctf

# If you want to put and get flag via ssh, uncomment these lines below
# which means flag is 1 or 2 file only with binary getflag will read flag2
#ARG SSHKEY
#RUN mkdir /root/.ssh && \
	echo $SSHKEY > /root/.ssh/authorized_keys
#RUN touch /flag1 && \
	chmod 644 /flag1
#ADD getflag /getflag
#RUN touch /flag2 && \
	chmod 600 /flag2 && \
	chmod +xs /getflag
################################################

RUN apt-get update
RUN apt-get clean

ADD getflag /getflag
ADD web1/file /file

CMD ["/bin/sh"]
```

If everything is done, run the following command in bash to build

```bash
docker compose build
```

If you enable SSHKEY, you will need to pass public key data when building:

```bash
docker compose build --build-arg SSHKEY="`cat /root/.ssh/id_rsa.pub`"
```

After it built successful, we can run docker image now:

```
docker compose up --detach
```

## Checker Writing

In case you want to put and get flag via SSH, use `paramiko` in python to support that:

```python
import paramiko

HOSTNAME = '192.168.0.1'
PORT = 22
USERNAME = 'root'
PASSWORD = 'root'
PRIVATE_KEY = '/root/.ssh/id_rsa'

client = paramiko.SSHClient()
client.set_missing_host_key_policy(paramiko.AutoAddPolicy())
client.connect(HOSTNAME, port=PORT, username=USERNAME, password=PASSWORD)
# client.connect(HOSTNAME, port=PORT, username=USERNAME, key_filename=PRIVATE_KEY)
client.exec_command(f"echo {flag} > /flag1")
client.close()
```

If flag is 1, there are no problems. But if flag files are 2, 2 flags can be put in 1 file which will lead to `GET failed` so here is a workaround to deal with that:

```python
def put(self, flag_id: str, flag: str, vuln: str):
    lock = FileLock(f"/tmp/.web1_{self.cm.get_port()}")
    try:
        client = paramiko.SSHClient()
        client.set_missing_host_key_policy(paramiko.AutoAddPolicy())
        client.connect('192.168.0.1', port=self.cm.get_ssh_port(), username='root', key_filename="/checkers/id_rsa")
        with lock:
            filename = f'/tmp/web1_{self.cm.get_port()}'
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
    client.connect('192.168.0.1', port=self.cm.get_ssh_port(), username='root',  key_filename="/checkers/id_rsa")

    flag_path = ['/flag1', '/flag2']
    is_the_same = False
    for path in flag_path:
	    stdin, stdout, stderr = client.exec_command(f"cat {path}")
	    res = stdout.readline()
    	if res.strip()==flag:
    		is_the_same = True
    		break
    client.close()
    if not is_the_same:
        self.cquit(Status.CORRUPT, 'get failed', f'Flag: {res1};{res2}')
    else:
	    self.cquit(Status.OK)
```


When running `init.sh` script, the script has already generatee a ssh key and copied to `/ForcAD/checkers` so in case you want to put and get flag via ssh of root, you can write script using key at `/checkers/id_rsa`

## Troubleshoot

