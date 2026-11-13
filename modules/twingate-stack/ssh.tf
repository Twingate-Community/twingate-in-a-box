# The SSH CA. The Gateway holds the private key and signs two kinds of short-lived
# certificate with it: a host certificate it presents to SSH clients, and a user
# certificate it presents to the SSH server upstream. Twingate gets the public key
# so Clients can trust the first, and SSH servers get it so they accept the second.

resource "tls_private_key" "ssh_ca" {
  algorithm = "ED25519"
}

resource "twingate_ssh_certificate_authority" "main" {
  name       = "${var.name_prefix}ssh-ca"
  public_key = tls_private_key.ssh_ca.public_key_openssh
}
