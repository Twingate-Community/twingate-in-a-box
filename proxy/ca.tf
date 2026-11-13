# The Gateway serves a certificate signed by the proxy CA. Browsers only trust
# it once this file is in the host trust store, so Terraform writes it out. The
# install and removal commands are in the README.
#
# This file is the CA certificate, not its private key, so it is safe to hand to
# anyone who needs access. The private key lives in terraform.tfstate, which is
# why that file must never be shared.

resource "local_file" "ca_cert" {
  content  = module.stack.ca_cert_pem
  filename = "${path.module}/ca.pem"

  file_permission = "0644"
}
