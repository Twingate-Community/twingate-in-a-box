# A certificate-only SSH server for the box. It trusts one thing: certificates
# signed by the Twingate Gateway's SSH CA, for the gateway account.
#
# The CA public key is not baked in. Terraform generates it, and Compose mounts it
# at /etc/ssh/twingate-ca.pub.
FROM alpine:3.22

# The host key is generated here, so it stays the same across restarts and
# recreates. The Gateway pins it on first connect, so after rebuilding this image
# run `docker compose restart gateway`.
#
# adduser -D locks the account, and sshd refuses a locked account even with a
# valid certificate. * means "no password" rather than "locked".
RUN apk add --no-cache openssh-server \
 && ssh-keygen -q -t ed25519 -N '' -f /etc/ssh/ssh_host_ed25519_key \
 && adduser -D -s /bin/sh gateway \
 && sed -i 's/^gateway:!/gateway:*/' /etc/shadow

COPY sshd_config /etc/ssh/sshd_config

EXPOSE 22
CMD ["/usr/sbin/sshd", "-D", "-e"]
