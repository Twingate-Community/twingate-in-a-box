# Define hard defaults for the box environment.
locals {
  # Prefixes the objects this creates in Twingate, so they are recognizable in
  # an account that holds more than the box.
  name_prefix = "twingate-in-a-box-"

  network_name = "twingate"
  subnet       = "172.28.0.0/24"
  gateway_ipv4 = "172.28.0.250"
  gateway_port = 8443

  # Served by the Gateway and the connector both, on their own addresses.
  # Unpublished, and nothing scrapes it yet.
  metrics_port = 9090
}