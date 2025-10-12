#!/bin/bash

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
NC='\033[0m'                # No Color
service=""
out=""

export EASYRSA_BATCH=1
export DEBIAN_FRONTEND=noninteractive

usage() {
    cat <<EOF
Usage: $0 [OPTION]... --out INTERFACE_OUT -s SERVICE_URL

Options:
  --out                         interface name for accessing the internet
  -s, --service                 link to download services.zip (omit to use local services.zip)
  -h, --help                    display help message and exit

Example: $0 --out ens33 -s https://github.com/

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

    mac_out=$(cat /sys/class/net/$out/address)

    rm -rf /etc/netplan/*
    echo """network:
    version: 2
    ethernets:
        out:
            optional: true
            dhcp4: true
            addresses: [10.0.0.2/30]
            routes:
              - to: default
                via: 10.0.0.1
            nameservers:
                addresses: [8.8.8.8, 8.8.4.4]
            match:
                macaddress: $mac_out
            set-name: out""" > "/etc/netplan/01-network.yaml"
    chmod 600 "/etc/netplan/01-network.yaml"
    netplan apply
}

check_and_fetch() {
    local url=$1      # url tương ứng
    local file=$2     # file local cần kiểm tra

    if [ -n "$url" ]; then
        echo "[*] Downloading $file from $url"
        wget -q "$url" -O "$file" || { echo "[-] Failed to download $file"; exit 1; }
    else
        if [ ! -f "$file" ]; then
            echo "[-] Missing $file: neither URL provided nor local file found ($file)"
            exit 1
        fi
        echo "[*] Using local file: $file"
    fi
}

basic_setup() {
    printf "\n\n\n$RED### Basic setup ###$NC\n"
    apt-get update
    apt-get remove -y unattended-upgrades
    echo iptables-persistent iptables-persistent/autosave_v4 boolean true | sudo debconf-set-selections
    echo iptables-persistent iptables-persistent/autosave_v6 boolean true | sudo debconf-set-selections
    apt-get install -y build-essential iptables-persistent unzip
    apt-get clean
    
    # --- Create SSH key ---
    ssh-keygen -q -t rsa -N '' -f /root/.ssh/id_rsa <<<y >/dev/null 2>&1

    # --- sudo without password ---
    if [ ! -f "/etc/sudoers.d/01-passwordless-user" ]; then
        echo "$SUDO_USER ALL=(ALL) NOPASSWD: ALL" > /etc/sudoers.d/01-passwordless-user
    fi

    check_and_fetch "$service" "services.zip"

    unzip -o services.zip -d /
}

docker_installation() {
    printf "\n\n\n$RED### Docker installation ###$NC\n"

    if command -v docker >/dev/null 2>&1; then
        echo "[*] Docker is already installed, skipping installation."
        return
    fi

    # Add Docker's official GPG key:
    apt-get update --fix-missing
    apt-get install -y ca-certificates curl
    install -m 0755 -d /etc/apt/keyrings
    curl -fsSL https://download.docker.com/linux/ubuntu/gpg -o /etc/apt/keyrings/docker.asc
    chmod a+r /etc/apt/keyrings/docker.asc

    # Add the repository to Apt sources:
    echo \
      "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.asc] https://download.docker.com/linux/ubuntu \
      $(. /etc/os-release && echo "$VERSION_CODENAME") stable" | \
      tee /etc/apt/sources.list.d/docker.list > /dev/null
    apt-get update
    apt-get -y install docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin

    usermod -aG docker $SUDO_USER

    echo "[+] Docker installed successfully."
}

post_network_configuration() {
    echo 'sudo systemctl stop ssh' >> service_final.sh
    echo 'sudo systemctl disable ssh' >> service_final.sh
    echo 'sudo iptables -I DOCKER-USER ! -s 10.0.0.1 -m conntrack --ctstate NEW,ESTABLISHED -j ACCEPT' >> service_final.sh
    echo 'sudo iptables -A DOCKER-USER -j DROP' >> service_final.sh
    echo 'sudo iptables -I INPUT ! -s 10.0.0.1 -m conntrack --ctstate NEW,ESTABLISHED -j ACCEPT' >> service_final.sh
    echo 'sudo iptables -I OUTPUT -m conntrack --ctstate ESTABLISHED -j ACCEPT' >> service_final.sh
    echo 'sudo iptables -P INPUT DROP' >> service_final.sh
    echo 'sudo iptables -P OUTPUT DROP' >> service_final.sh
    echo 'sudo bash -c "iptables-save > /etc/iptables/rules.v4"' >> service_final.sh
    chmod +x service_final.sh

    printf "\n\n${YELLOW}Now install your services and run the following command when you are done:"
    printf "\n    sudo `pwd`/service_final.sh"
    printf "\n${RED}Caution: You cannot connect to the internet after running that script\n\n"
}



if [ "$EUID" -ne 0 ]
    then echo "Please run as sudo"
    exit
fi

while getopts ":hs:-:" opt; do
    case $opt in
        h)
            usage
            ;;
        s)
            service=$OPTARG
            ;;
        -) # Handle long options
            case $OPTARG in
                service)
                    service="${!OPTIND}" # Next argument is the value
                    OPTIND=$((OPTIND + 1))     # Shift to next option
                    ;;
                out)
                    out="${!OPTIND}" # Next argument is the value
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

required_vars=(out)
for var in "${required_vars[@]}"; do
    if [ -z "${!var}" ]; then
        echo "Error: Missing required argument: $var"
        usage
    fi
done

# Kiểm tra interface có tồn tại và có file address
if [ ! -f "/sys/class/net/$out/address" ]; then
    echo "Error: Invalid interface: '$out'"
    usage
fi

network_configuration
basic_setup
docker_installation
post_network_configuration
