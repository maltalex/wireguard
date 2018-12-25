FROM ubuntu:18.04

RUN apt-get update -y && apt-get install -y \
    curl \
    iproute2 \
    qrencode \ 
    software-properties-common \
    iptables \
    && rm -rf /var/lib/apt/lists/*

RUN add-apt-repository --yes ppa:wireguard/wireguard

COPY entrypoint.sh /

EXPOSE 51820

VOLUME /etc/wireguard

ENTRYPOINT /entrypoint.sh
