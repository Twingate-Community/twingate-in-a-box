# The Twingate side of the box. One Remote Network holding one Connector and one
# Gateway, on a bridge that all Docker services join.
locals {
  # NOTE: a change to any service address or alias forces a regeneration of the certificate.
  # This will cause the Gateway to restart, disrupting any active connections.
  cert_dns_names = distinct(concat(
    [for service in values(local.twingate_services) : service.address],
    compact([for service in values(local.twingate_services) : service.alias]),
  ))
}

module "stack" {
  source = "../modules/twingate-stack"

  name_prefix = local.name_prefix
  tg_network  = var.tg_network

  # Every published address is a Docker DNS name.
  cert_dns_names = local.cert_dns_names

  request_headers = var.gateway_request_headers
  gateway_image   = var.gateway_image
  connector_image = var.connector_image
}
