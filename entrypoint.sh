#!/bin/bash

set -e

on_signal () {
	wg-quick down wg0
	exit 0
}

#install on entry since wg is a kernel module
apt-get update
DEBIAN_FRONTEND=noninteractive apt-get install -y linux-headers-$(uname -r) wireguard

if [[ ! -e /etc/wireguard/wg0.conf ]]; then
	echo "Generating configuration"

	: ${server:=$(curl checkip.amazonaws.com)}
	: ${server_port:=51820}

	: ${clients:=2}

	wg genkey | tee /etc/wireguard/server-privatekey | wg pubkey > /etc/wireguard/server-publickey

	cat > /etc/wireguard/wg0.conf <<-EOF
	[Interface]
	Address = 192.168.99.254/24
        PostUp = iptables -A FORWARD -i %i -j ACCEPT; iptables -A FORWARD -o %i -j ACCEPT; iptables -t nat -A POSTROUTING -o eth0 -j MASQUERADE
        PostDown = iptables -D FORWARD -i %i -j ACCEPT; iptables -D FORWARD -o %i -j ACCEPT; iptables -t nat -D POSTROUTING -o eth0 -j MASQUERADE
        ListenPort = 51820
	PrivateKey = $(cat /etc/wireguard/server-privatekey)
	EOF

	for (( client=1; client <= $clients; client+=1 )); do
		wg genkey | tee /etc/wireguard/client${client}-privatekey | wg pubkey > "/etc/wireguard/client${client}-publickey"

		cat >> /etc/wireguard/wg0.conf <<-EOF

		[Peer]
		PublicKey = $(cat /etc/wireguard/client${client}-publickey)
		AllowedIPs = 192.168.99.${client}/32
		EOF

		cat > /etc/wireguard/client${client}.conf <<-EOF
		[Interface]
		PrivateKey = $(cat /etc/wireguard/client${client}-privatekey)
		Address = 192.168.99.${client}/24
		DNS = 1.1.1.1, 1.0.0.1

		[Peer]
		PublicKey = $(cat /etc/wireguard/server-publickey)
		Endpoint = ${server}:${server_port}
		AllowedIPs = 0.0.0.0/0
		EOF

		echo "QR code for client ${client}:"
		qrencode -t ansiutf8 < /etc/wireguard/client${client}.conf
	done
else
	echo "Found existing configuration"
fi

wg-quick up wg0

trap on_signal SIGINT SIGTERM 

while [ 1 ]; do
	echo "**********************************************************************"
	date
	wg show
	sleep 60
done
