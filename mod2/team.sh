#!/bin/bash

RED='\033[0;31m'
NC='\033[0m'                # No Color
service=""
out=""
team=""

export EASYRSA_BATCH=1
export DEBIAN_FRONTEND=noninteractive

usage() {
    cat <<EOF
Usage: $0 [OPTION]... --out INTERFACE_OUT --team TEAM_NUMBER [-s SERVICE_URL]

Options:
  --out                         interface name for accessing the internet
  --team                        team number
  -s, --service                 link to download services.zip (omit to use local services.zip)
  -h, --help                    display help message and exit

Example: $0 --out ens33 --team 1 -s https://github.com/

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
            addresses: [10.254.$team.1/24]
            routes:
              - to: default
                via: 10.254.$team.254
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
    apt-get install -y build-essential openvpn unzip python3-pip
    apt-get clean
    ssh-keygen -q -t rsa -N '' -f /root/.ssh/id_rsa <<<y >/dev/null 2>&1

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

required_vars=(out team)
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
