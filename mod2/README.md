# Attack & Defense Lab (module 2)

> 1 machine for checker, scoreboard

> 2 machines for teams containing services

## VMware configuration

### ------ **Central machine**

First, we will need to install 3 network adapter on **central** machine (remember to match VMnet with the correct adapter name):
- `Network Adapter` is set to **NAT**
- `Network Adapter 2` is set to **VMnet1**
- `Network Adapter 3` is set to **VMnet2**:

![](.images/central-vmware-adapter.png)

Then we go to `Edit -> Virtual Network Editor...`:

![](.images/path-virtual-network-editor.png)

As you can see I don't have VMnet2 and VMnet3, so let's add them. Click at `Change Settings` to gain permission:

![](.images/virtual-network-editor-change-settings.png)

To add new VMnet, just click at `Add Network..`:

![](.images/add-new-vmnet.png)

Then select VMnet2 and click `OK`:

![](.images/select-new-vmnet2.png)

Do the same with VMnet3:

![](.images/select-new-vmnet3.png)

Check again and we see that VMnet2 and VMnet3 have been added successfully. Now click `Apply` and `OK` to close this popup:

![](.images/click-apply-and-ok-after-adding-vmnet.png)

That's good! Let's setup our team machines!

### ------ **Team machine**

Now we will config `Network Adapter` of team 1 into **VMnet1**:

![](.images/team1-vmware-adapter.png)

Then we will config `Network Adapter` of team 2 into **VMnet2**:

![](.images/team2-vmware-adapter.png)

That's all we needed. Now let's setup necessary stuff!

## Configuration

### ------ **Central machine**

On central, we already have access to Internet because of NAT adapter so let's config on central first. We will transfer `central.sh` into machine using `scp` and then run that script with these required parameters:

```bash
./central.sh [OPTION]... --out INTERFACE_OUT --team1 INTERFACE_TEAM1 --team2 INTERFACE_TEAM2 -f FORCAD_URL -c CHECKER_URL
```

Explanation:
- `INTERFACE_OUT`: general ip that all team will use to attack (or view scoreboard)
- `INTERFACE_TEAM1`: ip of server to communicate with team1
- `INTERFACE_TEAM2`: ip of server to communicate with team2
- `FORCAD_URL`: link to download ForcAD.zip
- `CHECKER_URL`: link to download checkers.zip

In my example, let's check all interface name:

![](.images/central-check-interface-name.png)

So we can see ens33 is NAT, ens37 is VMnet2 and ens38 is VMnet3 (they are in the same order as Network Adapter Card). For `ForcAD.zip` and `checkers.zip`, you can get it from release section. Below is an example of full command running `central.sh`:

```bash
./central.sh --out ens33 --team1 ens37 --team2 ens38 -f https://github.com/ -c https://github.com/
```

> This script will also generate a new SSH key pair and put private key in `/ForcAD/checkers` just in case you need it.

Now we will want to **route traffic** from team 1 to team 2 and vice versa. We will use is `nginx` and below is an example for `/etc/nginx/nginx.conf` that you will want to modify:

```
worker_processes auto;
pid /run/nginx.pid;
include /etc/nginx/modules-enabled/*.conf;

events {
        worker_connections 768;
}

stream {
    server {
        listen 40101;
        proxy_pass 10.254.1.2:9001;
    }
    server {
        listen 40201;
        proxy_pass 10.254.2.2:9001;
    }
}
```

Explaination:
- `listen`: Port that central will bind on
- `proxy_pass`: Destination that central will redirect traffic to

Modify `/etc/nginx/nginx.conf` with your config, then run the command below to check if config is correct:

```
nginx -t
```

If config can work, we will get successful message:

![](.images/nginx-check-config.png)

Now we just need to restart nginx service to update with new configuration:

```
systemctl restart nginx
```

Central machine is now set. Let's setup on team machine!

### ------ **Team machine**

Let's copy the script `team.sh` into machine via `scp`, then `ssh` into it and we can run that script to setup team machine. The script require these parameters:

```bash
./team.sh [OPTION]... --out INTERFACE_OUT --team TEAM_NUMBER -s SERVICE_URL
```
Below is an example of full command running `team.sh`:

```bash
./team.sh --out ens33 --team 1 -s https://github.com/
```

If a challenge need to put flag via SSH, you can copy public key from `central` in `/root/.ssh/id_rsa.pub` into team machine.

Now we want to make team machine can be accessed from the internet, we will use openvpn to achieve that. With team 1, transfer `proxy1.ovpn` from vps (which hosts openvpn-server) to team machine at `/etc/openvpn/client` and rename it from `proxy1.ovpn` into `proxy1.conf`:

![](.images/vps-proxy1-ovpn-path.png)

![](.images/proxy1-ovpn-path.png)

To start openvpn on team 1 and with filename of config is `proxy1.conf`, we just need to type:

```bash
systemctl start openvpn-client@proxy1
```

Now team 1 has joined network of openvpn, we just need to generate and download `client.ovpn` from vps, then run on our host machine and we can SSH into team 1 machine from net:

![](.images/ssh-to-proxy1.png)

Setup for team 2 is similar as team 1, remember to change `TEAM_NUMBER` to `2`
