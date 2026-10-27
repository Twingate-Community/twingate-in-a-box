# The Twingate side of the proxy. One Remote Network holding one Connector and
# one Gateway, sharing the host's network namespace.
locals {
  # Anything under the wildcard is already on the certificate. Only an alias
  # pointed somewhere else needs its own SAN, and only that will reissue the
  # certificate and restart the Gateway. Addresses need no coverage: they are
  # how the Gateway reaches the app, not what the browser validates.
  cert_dns_names = distinct([
    for app in values(local.web_apps) : app.published_as
    if !endswith(app.published_as, ".${var.wildcard_domain}")
  ])
}

module "stack" {
  source = "../modules/twingate-stack"

  name_prefix = local.name_prefix
  tg_network  = var.tg_network

  # The whole point of this variant. On its own bridge the Gateway could only
  # reach what Terraform put there. In the host's namespace it reaches whatever
  # the host reaches: LAN addresses, VMs, LXCs, other Docker bridges.
  host_network = true

  wildcard_domain = var.wildcard_domain
  cert_dns_names  = local.cert_dns_names

  request_headers = var.gateway_request_headers
  gateway_image   = var.gateway_image
  connector_image = var.connector_image
}
