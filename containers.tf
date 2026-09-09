# The box: the network everything joins, plus the two Twingate containers on it.
locals {
  gateway_config = templatefile("${path.module}/templates/gateway-config.yaml.tftpl", {
    network         = var.tg_network
    port            = local.gateway_port
    metrics_port    = local.metrics_port
    request_headers = var.gateway_request_headers
  })
}

# Not internal: the Gateway fetches JWKS at boot and the Connector needs to reach
# Twingate. Inbound is what the box closes off, not outbound.
resource "docker_network" "box" {
  name       = local.network_name
  driver     = "bridge"
  attachable = true

  ipam_config {
    subnet = local.subnet
  }

  lifecycle {
    precondition {
      condition     = length(local.host_exposed) == 0
      error_message = "Compose services ${join(", ", local.host_exposed)} expose ports to the host. Ports reachable from the host can accept headers from any client."
    }
  }
}

resource "docker_image" "gateway" {
  name = var.gateway_image

  # Without this, terraform destroy removes the image and the next apply re-pulls it.
  keep_locally = true
}

resource "docker_image" "connector" {
  name         = var.connector_image
  keep_locally = true
}

resource "docker_container" "gateway" {
  name    = "${local.name_prefix}gateway"
  image   = docker_image.gateway.image_id
  restart = "unless-stopped"

  # The image ENTRYPOINT is already ["/gateway", "start"].
  command = ["--config", "/etc/gateway/config.yaml"]

  networks_advanced {
    name         = docker_network.box.name
    ipv4_address = local.gateway_ipv4
  }

  # No ports block, on purpose. The Gateway is reachable only from inside this
  # network, via the Connector.

  # Uploaded rather than mounted, which keeps the leaf private key off the host
  # filesystem. owner and group must be 65532: the image is distroless nonroot, so
  # a root-owned key is unreadable and the Gateway exits.
  upload {
    file        = "/etc/gateway/config.yaml"
    content     = local.gateway_config
    owner       = "65532"
    group       = "65532"
    permissions = "0444"
  }

  upload {
    file        = "/etc/gateway/tls.crt"
    content     = tls_locally_signed_cert.leaf.cert_pem
    owner       = "65532"
    group       = "65532"
    permissions = "0444"
  }

  upload {
    file        = "/etc/gateway/tls.key"
    content     = tls_private_key.leaf.private_key_pem
    owner       = "65532"
    group       = "65532"
    permissions = "0400"
  }

  # Every upload field is ForceNew, so a config or certificate change replaces this
  # container on its own. Do not add create_before_destroy: the new container
  # cannot claim the Gateway address while the old one still holds it.

  depends_on = [twingate_gateway.main]
}

resource "docker_container" "connector" {
  name    = "${local.name_prefix}connector"
  image   = docker_image.connector.image_id
  restart = "unless-stopped"

  env = [
    "TWINGATE_NETWORK=${var.tg_network}",
    "TWINGATE_ACCESS_TOKEN=${twingate_connector_tokens.main.access_token}",
    "TWINGATE_REFRESH_TOKEN=${twingate_connector_tokens.main.refresh_token}",
    "TWINGATE_LABEL_DEPLOYED_BY=twingate-in-a-box",

    # Defaults to 0, which disables the metrics server entirely.
    "TWINGATE_METRICS_PORT=${local.metrics_port}",
  ]

  networks_advanced {
    name = docker_network.box.name
  }
}
