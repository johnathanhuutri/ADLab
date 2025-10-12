#!/bin/bash

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
NC='\033[0m'                # No Color
in=""
out=""
team=""

export EASYRSA_BATCH=1
export DEBIAN_FRONTEND=noninteractive

usage() {
    cat <<EOF
Usage: $0 [OPTION]... --out INTERFACE_OUT --team TEAM_NUMBER -s SERVICE_URL

Options:
  --out                         interface name for accessing outside (the internet)
  --in                          interface name for accessing inside (service)
  --team                        team number
  -h, --help                    display help message and exit

Example: $0 --out ens33 --in ens37 --team 1

EOF
    exit
}

network_configuration() {
    printf "\n\n\n$RED### Network configuration ###$NC\n"

    # Check internet
    if ping -c 1 -W 2 8.8.8.8 > /dev/null 2>&1; then
        echo "[*] Network config successful"
        return
    fi

    mac_in=$(cat /sys/class/net/$in/address)
    mac_out=$(cat /sys/class/net/$out/address)

    rm -rf /etc/netplan/*
    echo """network:
    version: 2
    ethernets:
        out:
            optional: true
            dhcp4: true
            addresses: [10.254.$team.1/24]
            routes:
              - to: default
                via: 10.254.$team.254
            nameservers:
                addresses: [8.8.8.8, 8.8.4.4]
            match:
                macaddress: $mac_out
            set-name: out
        in:
            optional: true
            dhcp4: true
            addresses: [10.0.0.1/30]
            match:
                macaddress: $mac_in
            set-name: in""" > "/etc/netplan/01-network.yaml"
    chmod 600 "/etc/netplan/01-network.yaml"
    netplan apply

    # --- IP forwarding ---
    echo 'net.ipv4.ip_forward = 1' > /etc/sysctl.d/99-ipforward.conf
    sudo sysctl --system

    # --- Add iptables rules ---
    iptables -t nat -A PREROUTING -p tcp ! --dport 22 ! -s 10.0.0.1 -i out -j DNAT --to-destination 10.0.0.2    # ssh to team, not service
    iptables -t nat -A POSTROUTING -o out -j MASQUERADE             # service can access internet to install services
}

basic_setup() {
    printf "\n\n\n$RED### Basic setup ###$NC\n"
    apt-get update
    apt-get remove -y unattended-upgrades
    echo iptables-persistent iptables-persistent/autosave_v4 boolean true | sudo debconf-set-selections
    echo iptables-persistent iptables-persistent/autosave_v6 boolean true | sudo debconf-set-selections
    apt-get install -y build-essential iptables-persistent openvpn
    apt-get clean
    
    # --- Save and auto restore when reboot ---
    iptables-save > /etc/iptables/rules.v4

    # --- Create SSH key ---
    ssh-keygen -q -t rsa -N '' -f /root/.ssh/id_rsa <<<y >/dev/null 2>&1

    # --- sudo without password ---
    if [ ! -f "/etc/sudoers.d/01-passwordless-user" ]; then
        echo "$SUDO_USER ALL=(ALL) NOPASSWD: ALL" > /etc/sudoers.d/01-passwordless-user
    fi

    rm team.sh
}



if [ "$EUID" -ne 0 ]
    then echo "Please run as sudo"
    exit
fi

while getopts ":h-:" opt; do
    case $opt in
        -) # Handle long options
            case $OPTARG in
                in)
                    in="${!OPTIND}" # Next argument is the value
                    OPTIND=$((OPTIND + 1))    # Shift to next option
                    ;;
                out)
                    out="${!OPTIND}" # Next argument is the value
                    OPTIND=$((OPTIND + 1))    # Shift to next option
                    ;;
                team)
                    team="${!OPTIND}" # Next argument is the value
                    OPTIND=$((OPTIND + 1))    # Shift to next option
                    ;;
                help)
                    usage
                    ;;
                *)
                    echo "Invalid option --$OPTARG"
                    usage
                    ;;
            esac
            ;;
        \?) # Invalid short option
            echo "Invalid option: -$OPTARG"
            usage
            ;;
        :) # Missing argument
            echo "Option -$OPTARG requires an argument."
            usage
            ;;
    esac
done

required_vars=(in out team)
for var in "${required_vars[@]}"; do
    if [ -z "${!var}" ]; then
        echo "Error: Missing required argument: $var"
        usage
    fi
done

# Kiểm tra interface có tồn tại và có file address
if [ ! -f "/sys/class/net/$in/address" ]; then
    echo "Error: Invalid interface: '$in'"
    usage
fi
if [ ! -f "/sys/class/net/$out/address" ]; then
    echo "Error: Invalid interface: '$out'"
    usage
fi

network_configuration
basic_setup
