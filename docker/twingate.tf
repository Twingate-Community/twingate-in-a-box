# The Twingate side of the box. One Remote Network holding one Connector and one
# Gateway, on a bridge that all Docker services join.
locals {
  # Every address is under the wildcard, so it is already on the certificate.
  # Only an alias pointed somewhere else needs its own SAN, and only that will
  # reissue the certificate and restart the Gateway.
  aliases = compact([for service in values(local.twingate_services) : service.alias])

  cert_dns_names = distinct([
    for alias in local.aliases : alias if !endswith(alias, ".${local.domain}")
  ])
}

module "stack" {
  source = "../modules/twingate-stack"

  name_prefix = local.name_prefix
  tg_network  = var.tg_network

  wildcard_domain = local.domain
  cert_dns_names  = local.cert_dns_names

  request_headers = var.gateway_request_headers
  gateway_image   = var.gateway_image
  connector_image = var.connector_image
}
