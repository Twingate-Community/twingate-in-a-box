# Hard defaults for the stack's own networking. Fixed rather than configurable.
locals {
  network_name = "twingate"
  subnet       = "172.28.0.0/24"
  gateway_ipv4 = "172.28.0.250"
  gateway_port = 8443

  # On the box network these are two addresses, so both can serve 9090. Sharing
  # the host namespace there is only one, and the second to start would fail to
  # bind, so the Connector moves up one and both stay scrapeable.
  gateway_metrics_port   = 9090
  connector_metrics_port = var.host_network ? 9091 : local.gateway_metrics_port

  # On a bridge the Connector dials a fixed address inside a network nothing else
  # can reach. Sharing the host namespace there is no such address, so it dials
  # loopback.
  gateway_address = var.host_network ? "127.0.0.1:${local.gateway_port}" : "${local.gateway_ipv4}:${local.gateway_port}"
}
