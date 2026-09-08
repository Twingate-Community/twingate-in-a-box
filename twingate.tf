# The Twingate side of the box: one remote network holding one connector and one
# gateway, plus the CA registration that lets clients trust what the Gateway
# presents.
locals {
  # Groups named by any published service, looked up once each.
  group_names = distinct(flatten([
    for service in values(local.twingate_services) : service.group_names
  ]))

  group_ids = { for name, found in data.twingate_groups.by_name : name => found.groups[0].id }
}

resource "twingate_remote_network" "main" {
  name = "${local.name_prefix}network"
}

# certificate is write-only: it is never stored in state, and changing it
# replaces this resource.
resource "twingate_x509_certificate_authority" "main" {
  name        = "${local.name_prefix}ca"
  certificate = tls_self_signed_cert.ca.cert_pem
}

resource "twingate_gateway" "main" {
  remote_network_id = twingate_remote_network.main.id
  address           = "${local.gateway_ipv4}:${local.gateway_port}"
  x509_ca_id        = twingate_x509_certificate_authority.main.id

  # Do not change remote_network_id in place. The provider reads it from state on
  # update, so the change silently no-ops and then drifts on every plan.
}

resource "twingate_connector" "main" {
  remote_network_id = twingate_remote_network.main.id
  name              = "${local.name_prefix}connector"
}

# Managed rather than ephemeral: the ephemeral variant re-mints tokens on every
# plan, leaving the running connector holding credentials Terraform has already
# rotated away from.
resource "twingate_connector_tokens" "main" {
  connector_id = twingate_connector.main.id
}

data "twingate_groups" "by_name" {
  for_each = toset(local.group_names)
  name     = each.value

  lifecycle {
    postcondition {
      condition     = length(self.groups) > 0
      error_message = "No Twingate group named '${each.value}'. Check twingate.groups on the service."
    }
  }
}
