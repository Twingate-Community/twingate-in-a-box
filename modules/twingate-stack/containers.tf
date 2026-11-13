locals {
  gateway_config = templatefile("${path.module}/templates/gateway-config.yaml.tftpl", {
    network         = var.tg_network
    port            = local.gateway_port
    metrics_port    = local.gateway_metrics_port
    request_headers = var.request_headers
    ssh_username    = local.ssh_username
  })
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
  name    = "${var.name_prefix}gateway"
  image   = docker_image.gateway.image_id
  restart = "unless-stopped"

  # The image ENTRYPOINT is already ["/gateway", "start"].
  command = ["--config", "/etc/gateway/config.yaml"]

  # Either the box network at a fixed address, or the host's own namespace.
  network_mode = var.host_network ? "host" : null

  # Docker's DNS still answers every name on the box network. What it cannot
  # answer, such as a stopped service, it forwards, and by default it forwards to
  # the host. On a machine running the Twingate Client the host answers with the
  # Client's own address for that Resource, so the Gateway dials back into
  # Twingate, reaches itself, and loops. Forwarding to public resolvers instead
  # turns that into an immediate NXDOMAIN.
  dns = var.host_network ? null : local.gateway_upstream_dns

  dynamic "networks_advanced" {
    # skip this if on host network
    for_each = var.host_network ? [] : [1]

    content {
      name         = docker_network.box[0].name
      ipv4_address = local.gateway_ipv4
    }
  }

  # Uploaded rather than mounted, which keeps the leaf private key off the host
  # filesystem.
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

  upload {
    file        = "/etc/gateway/ssh-ca.key"
    content     = tls_private_key.ssh_ca.private_key_openssh
    owner       = "65532"
    group       = "65532"
    permissions = "0400"
  }

  # The container must not boot before the Gateway exists in Twingate.
  depends_on = [twingate_gateway.main]
}

resource "docker_container" "connector" {
  name    = "${var.name_prefix}connector"
  image   = docker_image.connector.image_id
  restart = "unless-stopped"

  env = [
    "TWINGATE_NETWORK=${var.tg_network}",
    "TWINGATE_ACCESS_TOKEN=${twingate_connector_tokens.main.access_token}",
    "TWINGATE_REFRESH_TOKEN=${twingate_connector_tokens.main.refresh_token}",
    "TWINGATE_LABEL_DEPLOYED_BY=twingate-in-a-box",

    # Defaults to 0, which disables the metrics server entirely.
    "TWINGATE_METRICS_PORT=${local.connector_metrics_port}",
  ]

  network_mode = var.host_network ? "host" : null

  dynamic "networks_advanced" {
    for_each = var.host_network ? [] : [1]

    content {
      name = docker_network.box[0].name
    }
  }
}
