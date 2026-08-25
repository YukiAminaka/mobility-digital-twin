#!/bin/sh
set -eu

if [ ! -c /dev/net/tun ]; then
    mkdir -p /dev/net
    mknod /dev/net/tun c 10 200
    chmod 0600 /dev/net/tun
fi

exec /usr/local/bin/soratun "$@"
