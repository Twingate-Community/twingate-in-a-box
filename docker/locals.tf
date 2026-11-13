# Define hard defaults for the box environment. Only change if you know what you are doing.
locals {
  # Prefixes the objects this creates in Twingate, so they are recognizable in
  # an account that holds more than the box.
  name_prefix = "twingate-in-a-box-"

  # Every published service is reachable as <service>.box.internal. The stack
  # module names the Docker network after this domain, and Docker DNS registers
  # each service on it under <service>.<network>, so one name serves as the
  # Twingate address, the upstream the Gateway dials, and what users type. The
  # wildcard certificate covers it for web apps and SSH alike.
  #
  # docker-compose.yaml declares the network by this name, so the two must agree.
  domain = "box.internal"

  # The key services list under networks: in docker-compose.yaml.
  compose_network = "twingate"
}
