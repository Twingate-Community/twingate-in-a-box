# One Remote Network holding one Connector and one Gateway, plus the CA
# registrations that let Clients trust what the Gateway presents. The SSH CA is in
# ssh.tf.

resource "twingate_remote_network" "main" {
  name = "${var.name_prefix}network"
}

# certificate is write-only. It is never stored in state, and changing it forces
# replacement.
resource "twingate_x509_certificate_authority" "main" {
  name        = "${var.name_prefix}ca"
  certificate = tls_self_signed_cert.ca.cert_pem
}

resource "twingate_gateway" "main" {
  remote_network_id = twingate_remote_network.main.id
  address           = local.gateway_address
  x509_ca_id        = twingate_x509_certificate_authority.main.id
  ssh_ca_id         = twingate_ssh_certificate_authority.main.id
}

resource "twingate_connector" "main" {
  remote_network_id = twingate_remote_network.main.id
  name              = "${var.name_prefix}connector"
}

resource "twingate_connector_tokens" "main" {
  connector_id = twingate_connector.main.id
}
