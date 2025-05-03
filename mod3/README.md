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

Script **init.sh** will also generate ssh key and store it in `/root/.ssh/` so when writing docker, you can take the template in `services` folder and build with command below:

```bash
docker compose build --build-arg SSHKEY="`cat /root/.ssh/id_rsa.pub`"
```

After it built successful, we can run challenge docker with the following command:

```bash
docker compose up --detach
```

- Building ForcAD

In this module, I think I will want the checker to ssh as root to service docker and update flag so we will need to move the sshkey from `/root/.ssh/id_rsa` to `/ForcAD/id_rsa` so that it can include the key to checker container and the checker can work!

## Challenge Writing

There is a folder called `services` with hierarchy as following:
```
services
├── servicectl.sh 
├── web1
│   ├── docker-compose.yml
│   ├── Dockerfile
└── web2
    ├── docker-compose.yml
    └── Dockerfile
```

In each challenge folder, you will need to build service for each team by specifying in `docker-compose.yml`. Here is an example of `docker-compose.yml`:

```
services:
	team1web1:
		build: .
		hostname: team1web1
		ports:
			- "10101:80"
			- "10121:22"
	team2web1:
		build: .
		hostname: team2web1
		ports:
			- "10201:80"
			- "10221:22"
```

If you want to start or stop services, just use the script `servicectl.sh` I have manually created:

```bash
./servicectl.sh start
./servicectl.sh stop
```

It will automatically build and add SSH key to docker

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

When running `init.sh` script, the script has already generated a ssh key and copied to `/ForcAD/checkers` so in case you want to put and get flag via ssh of root, you can write script using key at `/checkers/id_rsa`

## Troubleshoot

