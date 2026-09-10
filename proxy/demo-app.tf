# A stand-in for something you already run, and a debugging tool worth keeping
# alongside your own apps: it renders the request it received at /headers, which
# separates "the Gateway isn't injecting" from "my app isn't reading them".
#
# It sits on its own bridge with no published ports, which is the same position
# an LXC or a VM is in: the Gateway reaches it because the host routes there, not
# because Terraform put them on a network together.
locals {
  demo_subnet = "172.29.0.0/24"
  demo_ipv4   = cidrhost(local.demo_subnet, 10)
  demo_port   = 8080

  demo_services = var.demo_app ? {
    echo = {
      address = local.demo_ipv4
      port    = local.demo_port
      groups  = ["Everyone"]
      alias   = "echo.lab.internal"
      name    = null

      # Per-Resource, so only this service sees the token. The Gateway-wide
      # headers deliberately omit it. /headers renders the full token.
      headers = { Authorization = "Bearer {{jwt}}" }
    }
  } : {}
}

resource "docker_network" "demo" {
  count = var.demo_app ? 1 : 0

  name   = "${local.name_prefix}apps"
  driver = "bridge"

  ipam_config {
    subnet = local.demo_subnet
  }

  lifecycle {
    # See modules/twingate-stack/network.tf: ipam_config is a ForceNew set that
    # Docker fills in behind us, so without this the network is replaced on every
    # apply, and the destroy hangs, because echo is still attached to it.
    ignore_changes = [ipam_config]
  }
}

resource "docker_image" "echo" {
  count = var.demo_app ? 1 : 0

  name = "ghcr.io/mccutchen/go-httpbin:v2.15.0"

  # Without this, terraform destroy removes the image and the next apply re-pulls it.
  keep_locally = true
}

resource "docker_container" "echo" {
  count = var.demo_app ? 1 : 0

  name    = "${local.name_prefix}echo"
  image   = docker_image.echo[0].image_id
  restart = "unless-stopped"

  networks_advanced {
    name         = docker_network.demo[0].name
    ipv4_address = local.demo_ipv4
  }
}
