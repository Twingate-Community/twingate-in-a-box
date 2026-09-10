# The Twingate side of the proxy: one Remote Network holding one Connector and
# one Gateway, sharing the host's network namespace.
locals {
  # A Client validates the name it dialed, and no verifier will match an IP
  # literal against a DNS SAN, so the published names are split by shape rather
  # than listed together.
  #
  # NOTE: adding a service regenerates the leaf, which requires replacing the
  # Gateway container and drops the other apps for a few seconds.
  cert_ip_addresses = distinct([
    for service in values(local.services) : service.address
    if can(cidrhost("${service.address}/32", 0))
  ])

  cert_dns_names = distinct(concat(
    [for service in values(local.services) : service.address if !can(cidrhost("${service.address}/32", 0))],
    compact([for service in values(local.services) : service.alias]),
  ))
}

module "stack" {
  source = "../modules/twingate-stack"

  name_prefix = local.name_prefix
  tg_network  = var.tg_network

  # The whole point of this variant. On its own bridge the Gateway could only
  # reach what Terraform put there. In the host's namespace it reaches whatever
  # the host reaches: LAN addresses, VMs, LXCs, other Docker bridges.
  host_network = true

  cert_dns_names    = local.cert_dns_names
  cert_ip_addresses = local.cert_ip_addresses

  request_headers = var.gateway_request_headers
  gateway_image   = var.gateway_image
  connector_image = var.connector_image
}
