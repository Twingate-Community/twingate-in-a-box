# The network the Gateway and Connector share, and the only way in to the Gateway.
# Outbound connections still possible to enable services to reach external dependencies.
#
# Skipped entirely if on host networking
resource "docker_network" "box" {
  count = var.host_network ? 0 : 1

  name       = local.network_name
  driver     = "bridge"
  attachable = true

  # Work around to avoid Docker replacing the network on every apply due to ipam_config changes.
  ipam_config {
    subnet = local.subnet
  }

  lifecycle {
    # The subnet is fixed by design, so there is nothing here to track. Changing
    # it means recreating the network by hand.
    ignore_changes = [ipam_config]
  }
}
