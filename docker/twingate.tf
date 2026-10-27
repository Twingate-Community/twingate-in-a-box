# The Twingate side of the box. One Remote Network holding one Connector and one
# Gateway, on a bridge that all Docker services join.
locals {
  # Anything under the wildcard is already on the certificate. Only an alias
  # pointed somewhere else needs its own SAN, and only that will reissue the
  # certificate and restart the Gateway.
  cert_dns_names = distinct([
    for service in values(local.twingate_services) : service.alias
    if !endswith(service.alias, ".${var.wildcard_domain}")
  ])
}

module "stack" {
  source = "../modules/twingate-stack"

  name_prefix = local.name_prefix
  tg_network  = var.tg_network

  wildcard_domain = var.wildcard_domain
  cert_dns_names  = local.cert_dns_names

  request_headers = var.gateway_request_headers
  gateway_image   = var.gateway_image
  connector_image = var.connector_image
}
