# Template - Module 3

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
