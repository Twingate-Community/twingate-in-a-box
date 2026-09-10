# Define hard defaults for the proxy environment.
locals {
  # Prefixes the objects this creates in Twingate and in Docker. Different from
  # the box's, so both can run against the same account and the same daemon.
  name_prefix = "twingate-proxy-"
}
