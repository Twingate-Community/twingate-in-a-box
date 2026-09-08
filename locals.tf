# The box's network. Fixed -- everything here is reached through Twingate.
locals {
  network_name = "twingate"
  subnet       = "172.28.0.0/24"
  gateway_ipv4 = "172.28.0.250"
  gateway_port = 8443
}
