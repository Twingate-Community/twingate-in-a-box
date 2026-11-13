#!/bin/sh
set -eu

# The Gateway pins this server's host key in memory the first time it connects.
# A new key would fail every session until the Gateway restarts, so the key is
# generated once into a volume and reused when the container is recreated.
key=/etc/ssh/keys/ssh_host_ed25519_key
[ -f "$key" ] || ssh-keygen -q -t ed25519 -N '' -f "$key"

exec /usr/sbin/sshd -D -e
