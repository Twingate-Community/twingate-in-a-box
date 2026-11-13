# A certificate-only SSH server for the box. It trusts one thing: certificates
# signed by the Twingate Gateway's SSH CA, for the gateway account.
#
# The CA public key is not baked in. Terraform generates it, and Compose mounts it
# at /etc/ssh/twingate-ca.pub.
FROM alpine:3.22

# adduser -D locks the account, and sshd refuses a locked account even with a
# valid certificate. * means "no password" rather than "locked".
RUN apk add --no-cache openssh-server \
 && adduser -D -s /bin/sh gateway \
 && sed -i 's/^gateway:!/gateway:*/' /etc/shadow

COPY sshd_config /etc/ssh/sshd_config
COPY --chmod=0755 entrypoint.sh /entrypoint.sh

EXPOSE 22
CMD ["/entrypoint.sh"]
