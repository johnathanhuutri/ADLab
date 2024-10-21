# Attack & Defense Lab (module 2)

> 1 machine host all services of all teams

`central.sh` will generate ssh key and store in `/usr/share/.ssh/` so when writing docker, you will need to transfer public key from `/usr/share/.ssh/` to service folder which contains Dockerfile so when build docker, checker can put flag to that!

```bash
docker compose build --build-arg SSHKEY='<public-ssh-key>'
```

Example:

```bash
docker compose build --build-arg SSHKEY="`cat /home/user/.ssh/id_rsa.pub`"
```