# A stand-in for something you already run, and a debugging tool worth keeping
# alongside your own apps It renders the request it received at `/headers`, which
# helps debug potential deployment issues with the Gateway.

# This example is on its own subnet that the Gateway has access to. This
# pattern can be applied to deployments outside of Docker as well. The
# key is that the Gateway must be able to reach the subnet where the app resides.

locals {
  demo_subnet = "172.29.0.0/24"
  demo_ipv4   = cidrhost(local.demo_subnet, 10)
  demo_port   = 8080

  # You can toggle the demo app on or off with the `demo_app` variable.
  demo_services = var.demo_app ? {
    echo = {
      address = local.demo_ipv4
      port    = local.demo_port
      groups  = ["Everyone"]

      # Null so it picks up the default alias under wildcard_domain, which the
      # certificate already covers.
      alias = null
      name  = null

      https    = true
      tls_mode = "NONE"

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
    # This keeps the Docker network around between updates. If this is destroyed
    # before the containers running on it, the whole `terraform apply` hangs.
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
  # Only setup this container if the demo app is enabled.
  count = var.demo_app ? 1 : 0

  name    = "${local.name_prefix}echo"
  image   = docker_image.echo[0].image_id
  restart = "unless-stopped"

  networks_advanced {
    name         = docker_network.demo[0].name
    ipv4_address = local.demo_ipv4
  }
}
