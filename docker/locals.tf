# Define hard defaults for the box environment. Only change if you know what you are doing.
locals {
  # Prefixes the objects this creates in Twingate, so they are recognizable in
  # an account that holds more than the box.
  name_prefix = "twingate-in-a-box-"

  # The stack module creates this network and docker-compose.yaml joins it by
  # name, so the string lives in three places and they have to agree.
  network_name = "twingate"
}
