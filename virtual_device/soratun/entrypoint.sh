#!/bin/sh
set -eu

# 非rootユーザーではデバイスファイルを作成できないため、ホストの/dev/net/tunを渡す
if [ ! -c /dev/net/tun ]; then
    echo "/dev/net/tun が見つかりません。コンテナに /dev/net/tun を渡してください" >&2
    exit 1
fi

exec /usr/local/bin/soratun "$@"
