# Attack & Defense Lab (module 2)

> 1 machine for checker, scoreboard
> 2 machines for teams containing services

## VMnet Configuration

In this lab, we will use **VMnet2** and **VMnet3**:
- **VMnet2** for central vs team1
- **VMnet3** for central vs team2

We need to install those VMnets in `Virtual Network Editor` before we can use. On taskbar, select `Edit -> Virtual Network Editor...`:

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

## VMware Configuration

### ------ **Central machine**

For **central machine**, we will need 3 subnets, one for internet access, one for team 1 and one for team 2, so we will add 3 network adapter to this **central machine** (remember to match VMnet with the correct adapter name):
- `Network Adapter` is set to **NAT**
- `Network Adapter 2` is set to **VMnet2**
- `Network Adapter 3` is set to **VMnet3**:

![](.images/central-vmware-adapter.png)

That's good! Let's setup our team machines!

### ------ **Team machine**

Now we will config `Network Adapter` of team 1 into **VMnet2**:

![](.images/team1-vmware-adapter.png)

Then we will config `Network Adapter` of team 2 into **VMnet3**:

![](.images/team2-vmware-adapter.png)

That's all we needed. Now let's setup necessary stuff!

## Setup

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
        proxy_pass 10.254.1.1:9001;
    }
    server {
        listen 40201;
        proxy_pass 10.254.2.1:9001;
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

Finally, go to `/ForcAD`, write your `config.yml` then run:

```bash
./control.py setup
./control.py build
./control.py start
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

**After you setup services on both team machine, let's config the VPN!** Let's download VPN configs of 2 teams to our host:

![](.images/download-team-configs-from-vps.png)

Then let's copy those configs to corresponding machines:

![](.images/copy-team-configs-to-team-machine.png)

Now, let's SSH to team 1, then move the file `team1.ovpn` from `/home/user/team1.ovpn` to `/etc/openvpn/team1.conf`:

![](.images/team1-move-vpn-config-to-openvpn-folder.png)

To start openvpn on team 1, type:

```bash
sudo systemctl start openvpn@team1
sudo systemctl enable openvpn@team1
```

If VPN is on, we can see ip is assigned and we can ping to server:

![](.images/team1-openvpn-connect.png)

On our host, or another host, run config `player.ovpn` first:

![](.images/host-run-openvpn-config.png)

Now let's try to SSH to team 1, whose IP is `10.8.0.11`:

![](.images/host-try-to-ssh-to-team1.png)

Setup for team 2 is similar:

![](.images/team2-openvpn-connect.png)

If everything is correct, we can SSH to our team 2:

![](.images/host-try-to-ssh-to-team2.png)
