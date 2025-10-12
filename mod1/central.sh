#!/bin/bash

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
NC='\033[0m' # No Color
forcad=""
checker=""
out=""
team1=""
team2=""

export EASYRSA_BATCH=1
export DEBIAN_FRONTEND=noninteractive

usage() {
    cat <<EOF
Usage: $0 [OPTION]... --out INTERFACE_OUT --team1 INTERFACE_TEAM1 --team2 INTERFACE_TEAM2 [-f FORCAD_URL] [-c CHECKER_URL]

Options:
  -f, --forcad                  link to download ForcAD.zip (omit to use local ForcAD.zip)
  -c, --checker                 link to download checkers.zip (omit to use local checkers.zip)
  --out                         interface name for accessing the internet
  --team1                       interface name for communicating with team1
  --team2                       interface name for communicating with team2
  -h, --help                    display help message and exit

Example: $0 --out ens33 --team1 ens37 --team2 ens38 -f https://github.com/ -c https://github.com/

EOF
    exit
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

network_configuration() {
    printf "\n\n\n${RED}### Network configuration ###${NC}\n"

    mac_out=$(cat /sys/class/net/$out/address)
    mac_team1=$(cat /sys/class/net/$team1/address)
    mac_team2=$(cat /sys/class/net/$team2/address)

    # --- Check & apply netplan if not configured ---
    if [ ! -f /etc/netplan/01-network.yaml ]; then
        printf "${YELLOW}Applying new Netplan configuration...${NC}"
        rm -rf /etc/netplan/*
        cat <<EOF > /etc/netplan/01-network.yaml
network:
    version: 2
    ethernets:
        lo:
            addresses:
                - 127.0.0.1/8
                - 10.254.0.254/32
        out:
            optional: true
            dhcp4: true
            nameservers:
                addresses: [8.8.8.8, 8.8.4.4]
            match:
                macaddress: $mac_out
            set-name: out
        team1:
            optional: true
            dhcp4: false
            addresses: [10.254.1.254/24]
            match:
                macaddress: $mac_team1
            set-name: team1
        team2:
            optional: true
            dhcp4: false
            addresses: [10.254.2.254/24]
            match:
                macaddress: $mac_team2
            set-name: team2
EOF
        chmod 600 /etc/netplan/01-network.yaml
        netplan apply
    else
        printf "${GREEN}Netplan already configured, skipping...${NC}"
    fi

    # --- IP forwarding ---
    echo 'net.ipv4.ip_forward = 1' > /etc/sysctl.d/99-ipforward.conf
    sudo sysctl --system

    # --- Add iptables rules ---
    iptables -P FORWARD DROP
    iptables -A FORWARD -i team1 -o out ! -d 192.168.0.0/16 -j ACCEPT
    iptables -A FORWARD -i out -o team1 -j ACCEPT
    iptables -A FORWARD -i team2 -o out ! -d 192.168.0.0/16 -j ACCEPT
    iptables -A FORWARD -i out -o team2 -j ACCEPT
    iptables -t nat -A POSTROUTING -o out -j MASQUERADE
}

basic_setup() {
    printf "\n\n\n${RED}### Basic setup ###${NC}\n"

    apt-get update
    apt-get remove -y unattended-upgrades
    echo iptables-persistent iptables-persistent/autosave_v4 boolean true | sudo debconf-set-selections
    echo iptables-persistent iptables-persistent/autosave_v6 boolean true | sudo debconf-set-selections
    apt-get install -y build-essential iptables-persistent nginx jq openvpn unzip python3-pip
    apt-get clean

    # --- Save and auto restore when reboot ---
    iptables-save > /etc/iptables/rules.v4

    # --- Create SSH key ---
    ssh-keygen -q -t rsa -N '' -f /root/.ssh/id_rsa <<<y >/dev/null 2>&1

    # --- sudo without password ---
    if [ ! -f "/etc/sudoers.d/01-passwordless-user" ]; then
        echo "$SUDO_USER ALL=(ALL) NOPASSWD: ALL" > /etc/sudoers.d/01-passwordless-user
    fi

    check_and_fetch "$forcad" "ForcAD.zip"
    check_and_fetch "$checker" "checkers.zip"

    unzip -o ForcAD.zip -d /
    unzip -o checkers.zip -d /ForcAD
}

docker_installation() {
    printf "\n\n\n${RED}### Docker installation ###${NC}\n"

    if command -v docker >/dev/null 2>&1; then
        echo "[*] Docker is already installed, skipping installation."
        return
    fi

    # Add Docker's official GPG key
    apt-get update --fix-missing
    apt-get install -y ca-certificates curl
    install -m 0755 -d /etc/apt/keyrings
    curl -fsSL https://download.docker.com/linux/ubuntu/gpg -o /etc/apt/keyrings/docker.asc
    chmod a+r /etc/apt/keyrings/docker.asc

    # Add the repository to Apt sources
    echo \
      "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.asc] https://download.docker.com/linux/ubuntu \
      $(. /etc/os-release && echo "$VERSION_CODENAME") stable" | \
      tee /etc/apt/sources.list.d/docker.list > /dev/null
    apt-get update
    apt-get -y install docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin

    usermod -aG docker $SUDO_USER

    echo "[+] Docker installed successfully."
}

forcad_setup() {
    printf "\n\n\n${RED}### ForcAD configuration ###${NC}\n"

    cd /ForcAD
    find checkers -name checker.py -type f -exec chmod +x {} \;
    cp /root/.ssh/id_rsa ./checkers
    chmod 644 ./checkers/id_rsa
    pip3 install -r cli/requirements.txt
    cd -
}



if [ "$EUID" -ne 0 ]
    then echo "Please run as sudo"
    exit
fi

while getopts ":hf:c:-:" opt; do
    case $opt in
        h)
            usage
            ;;
        c)
            checker=$OPTARG
            ;;
        f)
            forcad=$OPTARG
            ;;
        -) # Handle long options
            case $OPTARG in
                forcad)
                    forcad="${!OPTIND}" # Next argument is the value
                    OPTIND=$((OPTIND + 1))     # Shift to next option
                    ;;
                checker)
                    checker="${!OPTIND}" # Next argument is the value
                    OPTIND=$((OPTIND + 1))    # Shift to next option
                    ;;
                out)
                    out="${!OPTIND}" # Next argument is the value
                    OPTIND=$((OPTIND + 1))     # Shift to next option
                    ;;
                team1)
                    team1="${!OPTIND}" # Next argument is the value
                    OPTIND=$((OPTIND + 1))    # Shift to next option
                    ;;
                team2)
                    team2="${!OPTIND}" # Next argument is the value
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

required_vars=(out team1 team2)
for var in "${required_vars[@]}"; do
    if [ -z "${!var}" ]; then
        echo "Error: Missing required argument: $var"
        usage
    fi

    # Kiểm tra interface có tồn tại và có file address
    if [ ! -f "/sys/class/net/${!var}/address" ]; then
        echo "Error: Invalid interface: '${!var}'"
        usage
    fi
done

network_configuration
basic_setup
docker_installation
forcad_setup
