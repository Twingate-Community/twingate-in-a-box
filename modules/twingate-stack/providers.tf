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
  }
}

# No provider blocks on purpose. Both configurations are inherited from whichever
# root calls this, and a module that configures its own providers cannot be used
# with count or for_each.
