# Register a self signed CA with Twingate and issue a certificate for the Gateway.
# The Client uses this to verify communication with the Gateway
locals {
  # NOTE: each time a service address or alias changes, the Gateway's certificate must be regenerated and re-registered with Twingate. Otherwise, the Gateway will fail to start.
  cert_dns_names = distinct(concat(
    [for service in values(local.twingate_services) : service.address],
    compact([for service in values(local.twingate_services) : service.alias]),
  ))
}

resource "tls_private_key" "ca" {
  algorithm = "RSA"
  rsa_bits  = 4096
}

resource "tls_self_signed_cert" "ca" {
  private_key_pem = tls_private_key.ca.private_key_pem

  subject {
    common_name = "twingate-in-a-box-ca"
  }

  validity_period_hours = 8760
  is_ca_certificate     = true

  allowed_uses = [
    "digital_signature",
    "key_encipherment",
    "cert_signing",
    "crl_signing",
  ]
}

resource "tls_private_key" "leaf" {
  algorithm = "RSA"
  rsa_bits  = 4096
}

resource "tls_cert_request" "leaf" {
  private_key_pem = tls_private_key.leaf.private_key_pem

  subject {
    common_name = "twingate-in-a-box-gateway"
  }

  dns_names = local.cert_dns_names
}

resource "tls_locally_signed_cert" "leaf" {
  cert_request_pem   = tls_cert_request.leaf.cert_request_pem
  ca_private_key_pem = tls_private_key.ca.private_key_pem
  ca_cert_pem        = tls_self_signed_cert.ca.cert_pem

  validity_period_hours = 8760

  allowed_uses = [
    "digital_signature",
    "key_encipherment",
    "server_auth",
  ]
}
