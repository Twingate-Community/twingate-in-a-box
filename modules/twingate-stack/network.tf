# The network the Gateway and Connector share, and the only way in to the Gateway.
#
# Not internal: the Gateway fetches JWKS at boot and the Connector needs to reach
# Twingate. Inbound is what this closes off, not outbound.
#
# Not created at all when host_network is set, since both containers are in the
# host's namespace and there is nothing to join.
resource "docker_network" "box" {
  count = var.host_network ? 0 : 1

  name       = local.network_name
  driver     = "bridge"
  attachable = true

  # gateway is declared even though Docker would pick it, because ipam_config is a
  # ForceNew set: Docker reads its own choice back into state, the configured
  # element then never matches, and the network is replaced on every apply.
  ipam_config {
    subnet = local.subnet
  }

  lifecycle {
    # ipam_config is a ForceNew set, and Docker fills in fields we never declare:
    # a gateway address, an empty aux_address. Those come back on refresh, the
    # configured element stops matching the stored one, and the network is
    # replaced on every apply. That takes the Gateway with it, and then hangs on
    # the way out because the apps are still attached.
    #
    # The subnet is fixed by design, so there is nothing here to track. Changing
    # it means recreating the network by hand.
    ignore_changes = [ipam_config]
  }
}
