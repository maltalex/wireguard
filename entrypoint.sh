#!/bin/bash

set -e

on_signal () {
	wg-quick down wg0
	exit 0
}

#install on entry since wg is a kernel module
apt-get update
apt-get install -y linux-headers-$(uname -r) wireguard

if [[ ! -e /etc/wireguard/wg0.conf ]]; then
	echo "Generating configuration"
	: ${server_ip:='192.168.1.1/24'}
	: ${client_ip:='192.168.1.2/24'}

	: ${server:=$(curl checkip.amazonaws.com)}
	: ${server_port:=51820}

	wg genkey | tee /etc/wireguard/server-privatekey | wg pubkey > /etc/wireguard/server-publickey
	wg genkey | tee /etc/wireguard/client-privatekey | wg pubkey > /etc/wireguard/client-publickey

	cat > /etc/wireguard/wg0.conf <<-EOF
	[Interface]
	Address = $server_ip
	PostUp = iptables -t nat -A POSTROUTING -o eth0 -j MASQUERADE
	PostDown = iptables -t nat -D POSTROUTING -o eth0 -j MASQUERADE
	ListenPort = 51820
	PrivateKey = $(cat /etc/wireguard/server-privatekey)

	[Peer]
	PublicKey = $(cat /etc/wireguard/client-publickey)
	AllowedIPs = $client_ip
	EOF

	cat > /etc/wireguard/client.conf <<-EOF
	[Interface]
	PrivateKey = $(cat /etc/wireguard/client-privatekey)
	Address = $client_ip
	DNS = 1.1.1.1, 1.0.0.1

	[Peer]
	PublicKey = $(cat /etc/wireguard/server-publickey)
	Endpoint = ${server}:${server_port}
	AllowedIPs = 0.0.0.0/0
	EOF
else
	echo "Found existing configuration"
fi

echo "$(date): Client QR code:"
qrencode -t ansiutf8 < /etc/wireguard/client.conf

wg-quick up wg0

trap on_signal SIGINT SIGTERM 

while [ 1 ]; do
	echo "**********************************************************************"
	date
	wg show
	sleep 60
done
