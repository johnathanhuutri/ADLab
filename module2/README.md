# Attack & Defense Lab (module 2)

> 1 machine host all services of all teams

`central.sh` will generate ssh key and store in `/usr/share/.ssh/` so when writing docker, you will need to transfer that key to `/root/.ssh` in your docker so that checker can put flag to that!