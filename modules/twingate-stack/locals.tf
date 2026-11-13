# Hard defaults for the stack's own networking. Fixed rather than configurable.
locals {
  # Named after the domain on purpose. Docker DNS answers every network alias
  # again as <alias>.<network>, so a Compose service on this network resolves as
  # <service>.<wildcard_domain> with no config, and the wildcard certificate
  # already covers that name.
  network_name = var.wildcard_domain
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

  # The account every SSH session logs in as upstream, whatever username the client
  # typed. The Gateway puts it on the user certificate as the only principal, so an
  # SSH server needs this account to exist and nothing else.
  ssh_username = "gateway"

  # Where the Gateway's DNS lookups go once Docker's own records run out. See the
  # dns argument on the Gateway container for why it is not the host.
  gateway_upstream_dns = ["1.1.1.1", "9.9.9.9"]
}
