#!/bin/bash

if [ "$EUID" -ne 0 ]
	then echo "Please run as root"
	exit
fi

if [ ! "$1" ]; then
	echo "Usage: $0 <server-ip>"
	echo "Ex:    $0 123.123.123.123"
	exit
fi

# https://documentation.ubuntu.com/server/how-to/security/install-openvpn/
# https://www.digitalocean.com/community/tutorials/how-to-set-up-and-configure-an-openvpn-server-on-ubuntu-22-04
RED='\033[0;31m'
NC='\033[0m' # No Color
export EASYRSA_BATCH=1

printf "\n\n\n${RED}### Installing OpenVPN and Easy-RSA...${NC}\n"
echo 'apt update'
apt update
echo 'apt install openvpn openvpn easy-rsa'
apt install openvpn openvpn easy-rsa

printf "\n\n\n${RED}### Setting up the Certificate Authority...${NC}\n"
echo 'make-cadir /root/easy-rsa'
make-cadir /root/easy-rsa
echo 'cd /root/easy-rsa'
cd /root/easy-rsa
echo -e 'set_var EASYRSA_ALGO "ec"\nset_var EASYRSA_DIGEST "sha512"\n' >> vars
echo './easyrsa init-pki'
./easyrsa init-pki
echo './easyrsa build-ca'
./easyrsa build-ca

printf "\n\n\n${RED}### Creating server certificates and keys...${NC}\n"
./easyrsa gen-req server nopass
./easyrsa sign-req server server
openvpn --genkey --secret ta.key
cp pki/private/server.key /etc/openvpn/server/
cp pki/issued/server.crt /etc/openvpn/server/
cp pki/ca.crt /etc/openvpn/server/
cp ta.key /etc/openvpn/server

printf "\n\n\n${RED}### Generating client certificates and keys for proxy1...${NC}\n"
mkdir -p /root/proxy1/keys
chmod -R 700 /root/proxy1/keys
./easyrsa gen-req proxy1 nopass
./easyrsa sign-req client proxy1
cp pki/private/proxy1.key /root/proxy1/keys/
cp pki/issued/proxy1.crt /root/proxy1/keys/
cp pki/ca.crt /root/proxy1/keys/
cp ta.key /root/proxy1/keys/

printf "\n\n\n${RED}### Generating client certificates and keys for proxy2...${NC}\n"
mkdir -p /root/proxy2/keys
chmod -R 700 /root/proxy2/keys
./easyrsa gen-req proxy2 nopass
./easyrsa sign-req client proxy2
cp pki/private/proxy2.key /root/proxy2/keys/
cp pki/issued/proxy2.crt /root/proxy2/keys/
cp pki/ca.crt /root/proxy2/keys/
cp ta.key /root/proxy2/keys/

printf "\n\n\n${RED}### Generating client certificates and keys for client...${NC}\n"
mkdir -p /root/client/keys
chmod -R 700 /root/client/keys
./easyrsa gen-req client nopass
./easyrsa sign-req client client
cp pki/private/client.key /root/client/keys/
cp pki/issued/client.crt /root/client/keys/
cp pki/ca.crt /root/client/keys/
cp ta.key /root/client/keys/

printf "\n\n\n${RED}### Configuring OpenVPN server...${NC}\n"
cp /usr/share/doc/openvpn/examples/sample-config-files/server.conf /etc/openvpn/server/
sed -i 's/tls-auth ta.key 0/tls-crypt ta.key/g' /etc/openvpn/server/server.conf
sed -i 's/cipher AES-256-CBC/cipher AES-256-GCM\nauth SHA256/g' /etc/openvpn/server/server.conf
sed -i 's/dh dh2048.pem/dh none/g' /etc/openvpn/server/server.conf
sed -i 's/;client-config-dir ccd/client-config-dir ccd/g' /etc/openvpn/server/server.conf
sed -i 's/;client-to-client/client-to-client/g' /etc/openvpn/server/server.conf
sed -i 's/;duplicate-cn/duplicate-cn/g' /etc/openvpn/server/server.conf

printf "\n\n\n${RED}### Configuring static IP for proxies...${NC}\n"
mkdir /etc/openvpn/server/ccd
echo 'ifconfig-push 10.8.0.100 255.255.255.0' > /etc/openvpn/server/ccd/proxy1
echo 'ifconfig-push 10.8.0.200 255.255.255.0' > /etc/openvpn/server/ccd/proxy2

printf "\n\n\n${RED}### Adjusting Networking Configuration...${NC}\n"
sed -i 's/#net.ipv4.ip_forward=1/net.ipv4.ip_forward=1/g' /etc/openvpn/server/server.conf
echo 'net.ipv4.ip_forward=1' >> /etc/sysctl.conf
sysctl -p

printf "\n\n\n${RED}### Adjusting Firewall Configuration...${NC}\n"
ufw allow 1194/udp
ufw disable
ufw enable

printf "\n\n\n${RED}### Starting OpenVPN Server...${NC}\n"
systemctl start openvpn-server@server.service

### Install server ################################################
printf "\n\n\n${RED}Generating proxy1 configuration - proxy1.ovpn${NC}\n"
mkdir /root/proxy1/files
cp /usr/share/doc/openvpn/examples/sample-config-files/client.conf /root/proxy1/
sed -i "s/remote my-server-1 1194/remote $1 1194/g" /root/proxy1/client.conf
sed -i 's/ca ca.crt/;ca ca.crt/g' /root/proxy1/client.conf
sed -i 's/cert client.crt/;cert client.crt/g' /root/proxy1/client.conf
sed -i 's/key client.key/;key client.key/g' /root/proxy1/client.conf
sed -i 's/tls-auth ta.key 1/;tls-auth ta.key 1/g' /root/proxy1/client.conf
sed -i 's/cipher AES-256-CBC/cipher AES-256-GCM\nauth SHA256/g' /root/proxy1/client.conf
echo 'key-direction 1' >> /root/proxy1/client.conf

echo '''#!/bin/bash
 
KEY_DIR=~/proxy1/keys
OUTPUT_DIR=~/proxy1/files
BASE_CONFIG=~/proxy1/client.conf
 
cat ${BASE_CONFIG} \
    <(echo -e "<ca>") \
    ${KEY_DIR}/ca.crt \
    <(echo -e "</ca>\n<cert>") \
    ${KEY_DIR}/${1}.crt \
    <(echo -e "</cert>\n<key>") \
    ${KEY_DIR}/${1}.key \
    <(echo -e "</key>\n<tls-crypt>") \
    ${KEY_DIR}/ta.key \
    <(echo -e "</tls-crypt>") \
    > ${OUTPUT_DIR}/${1}.ovpn''' > /root/proxy1/make_config.sh
chmod 700 /root/proxy1/make_config.sh
cd /root/proxy1
./make_config.sh proxy1

printf "\n\n\n${RED}Generating proxy2 configuration - proxy2.ovpn${NC}\n"
mkdir /root/proxy2/files
cp /usr/share/doc/openvpn/examples/sample-config-files/client.conf /root/proxy2/
sed -i "s/remote my-server-1 1194/remote $1 1194/g" /root/proxy2/client.conf
sed -i 's/ca ca.crt/;ca ca.crt/g' /root/proxy2/client.conf
sed -i 's/cert client.crt/;cert client.crt/g' /root/proxy2/client.conf
sed -i 's/key client.key/;key client.key/g' /root/proxy2/client.conf
sed -i 's/tls-auth ta.key 1/;tls-auth ta.key 1/g' /root/proxy2/client.conf
sed -i 's/cipher AES-256-CBC/cipher AES-256-GCM\nauth SHA256/g' /root/proxy2/client.conf
echo 'key-direction 1' >> /root/proxy2/client.conf

echo '''#!/bin/bash
 
KEY_DIR=~/proxy2/keys
OUTPUT_DIR=~/proxy2/files
BASE_CONFIG=~/proxy2/client.conf
 
cat ${BASE_CONFIG} \
    <(echo -e "<ca>") \
    ${KEY_DIR}/ca.crt \
    <(echo -e "</ca>\n<cert>") \
    ${KEY_DIR}/${1}.crt \
    <(echo -e "</cert>\n<key>") \
    ${KEY_DIR}/${1}.key \
    <(echo -e "</key>\n<tls-crypt>") \
    ${KEY_DIR}/ta.key \
    <(echo -e "</tls-crypt>") \
    > ${OUTPUT_DIR}/${1}.ovpn''' > /root/proxy2/make_config.sh
chmod 700 /root/proxy2/make_config.sh
cd /root/proxy2
./make_config.sh proxy2

printf "\n\n\n${RED}Generating client configuration - client.ovpn${NC}\n"
mkdir -p /root/client/files
cp /usr/share/doc/openvpn/examples/sample-config-files/client.conf /root/client/
sed -i "s/remote my-server-1 1194/remote $1 1194/g" /root/client/client.conf
sed -i 's/ca ca.crt/;ca ca.crt/g' /root/client/client.conf
sed -i 's/cert client.crt/;cert client.crt/g' /root/client/client.conf
sed -i 's/key client.key/;key client.key/g' /root/client/client.conf
sed -i 's/tls-auth ta.key 1/;tls-auth ta.key 1/g' /root/client/client.conf
sed -i 's/cipher AES-256-CBC/cipher AES-256-GCM\nauth SHA256/g' /root/client/client.conf
echo 'key-direction 1' >> /root/client/client.conf

echo '''#!/bin/bash
 
KEY_DIR=~/client/keys
OUTPUT_DIR=~/client/files
BASE_CONFIG=~/client/client.conf
 
cat ${BASE_CONFIG} \
    <(echo -e "<ca>") \
    ${KEY_DIR}/ca.crt \
    <(echo -e "</ca>\n<cert>") \
    ${KEY_DIR}/${1}.crt \
    <(echo -e "</cert>\n<key>") \
    ${KEY_DIR}/${1}.key \
    <(echo -e "</key>\n<tls-crypt>") \
    ${KEY_DIR}/ta.key \
    <(echo -e "</tls-crypt>") \
    > ${OUTPUT_DIR}/${1}.ovpn''' > /root/client/make_config.sh
chmod 700 /root/client/make_config.sh
cd /root/client
./make_config.sh client