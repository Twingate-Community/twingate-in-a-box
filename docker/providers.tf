terraform {
  # 1.11 is the floor for write-only attributes, which
  # twingate_x509_certificate_authority.certificate requires.
  required_version = ">= 1.11.0"

  required_providers {
    twingate = {
      source  = "Twingate/twingate"
      version = "~> 5.0"
    }
    docker = {
      source  = "kreuzwerker/docker"
      version = "~> 4.6"
    }
    tls = {
      source  = "hashicorp/tls"
      version = "~> 4.0"
    }
    # Writes the CA certificate out for installing in the host trust store.
    local = {
      source  = "hashicorp/local"
      version = "~> 2.5"
    }
  }
}

provider "twingate" {
  api_token = var.tg_api_token
  network   = var.tg_network
}

# No host set on purpose: inherits DOCKER_HOST, or the default local socket.
provider "docker" {}
