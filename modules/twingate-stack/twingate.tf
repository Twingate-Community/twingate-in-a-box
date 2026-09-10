# One Remote Network holding one Connector and one Gateway, plus the CA
# registration that lets Clients trust what the Gateway presents.

resource "twingate_remote_network" "main" {
  name = "${var.name_prefix}network"
}

# certificate is write-only: it is never stored in state, and changing it forces
# replacement.
resource "twingate_x509_certificate_authority" "main" {
  name        = "${var.name_prefix}ca"
  certificate = tls_self_signed_cert.ca.cert_pem
}

resource "twingate_gateway" "main" {
  remote_network_id = twingate_remote_network.main.id
  address           = local.gateway_address
  x509_ca_id        = twingate_x509_certificate_authority.main.id

  # Do not change remote_network_id in place. The provider reads it from state on
  # update, so the change silently no-ops and then drifts on every plan.
}

resource "twingate_connector" "main" {
  remote_network_id = twingate_remote_network.main.id
  name              = "${var.name_prefix}connector"
}

# Managed rather than ephemeral: the ephemeral variant re-mints tokens on every
# plan, leaving the running Connector holding credentials Terraform has already
# rotated away from.
resource "twingate_connector_tokens" "main" {
  connector_id = twingate_connector.main.id
}
