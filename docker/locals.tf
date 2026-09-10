# Define hard defaults for the box environment.
locals {
  # Prefixes the objects this creates in Twingate, so they are recognizable in
  # an account that holds more than the box.
  name_prefix = "twingate-in-a-box-"

  # The stack module creates this network and docker-compose.yaml joins it by
  # name, so the string lives in three places and they have to agree. It cannot
  # come from the module's output: compose.tf derives service addresses from it,
  # and those feed the certificate names back into the module call.
  network_name = "twingate"
}
