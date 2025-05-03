# Attack & Defense Lab (module 3)

> 1 machine host all services of all teams

## Application
- [ForcAD](https://github.com/pomo-mondreganto/ForcAD/releases/tag/v1.4.0)
- [Docker](https://docs.docker.com/engine/install/ubuntu/)
- Openvpn

## Machine Setup

First, we will need to install 2 network adapter, first one is set to **NAT** and second one is set to **Host-only**:

![](.images/vmware-network-adapter-config.png)

The script **`init.sh`** will config the **`Network Adapter 2`**'s ip to **`192.168.0.1/24`** so that bot can use this ip to check services.

- Building challenge

Script **init.sh** will also generate ssh key and store it in `/root/.ssh/` so when writing docker, you can take the template in challenge folder and build with command below:

```bash
docker compose build --build-arg SSHKEY="`cat /root/.ssh/id_rsa.pub`"
```

After it built successful, we can run challenge docker with the following command:

```bash
docker compose up --detach
```

- Building ForcAD

In this lab, I designed the checker to ssh as root to service docker and update flag in that so we will need to move the sshkey from `/root/.ssh/id_rsa` to `/ForcAD/id_rsa` so that it can include the key to checker container and the checker can work!

## Challenge Writing

There is a folder called `services` with hierarchy as following:
```
services
├── getflag
├── web1
│   ├── docker-compose.yml
│   ├── Dockerfile
└── web2
    ├── docker-compose.yml
    └── Dockerfile
```

For each challenge, you will need to build service for each team. Here is an example of `docker-compose.yml`:

```
services:
	team1web1:
		build: .
		hostname: web1team1
		ports:
			- "10101:80"
			- "10121:22"
	team2web1:
		build: .
		hostname: web1team2
		ports:
			- "10201:80"
			- "10221:22"
```

So in your `Dockerfile`, when you want to add `file2` into docker of chall web1, you will need to specify the path with the folder name and then file name as following:

```
ADD web1/file /file
```

Instead of:

```
ADD file /file
```

Because at `.`, which means at `services` folder, there is no file called `file2`. But in case you want to add `file1` into both of chall webs so you can add this line to both `Dockerfile`s:

```
ADD getflag /getflag
```

This is a valid command because at `.`, which means at `services` folder, there is a file called `file1`. Here is an example of your `Dockerfile` with some note in it:

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

There is a folder called `checkers` with its hierarchy as following:

```
checkers
├── requirements.txt
├── web1
│   └── checker.py
└── web2
    └── checker.py
```

When running `init.sh` script, the script has already generatee a ssh key and copied to `/ForcAD/checkers` so in case you want to put and get flag via ssh of root, you can write script using key at `/checkers/id_rsa`

## Troubleshoot

