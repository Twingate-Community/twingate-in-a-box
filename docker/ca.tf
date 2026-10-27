# The Gateway serves a certificate signed by the box CA. Browsers only trust it
# once this file is in the host trust store, so Terraform writes it out.
#
# This file is the CA certificate, not its private key, so it is safe to hand to
# anyone who needs access. The private key lives in terraform.tfstate, which is
# why that file must never be shared.

resource "local_file" "ca_cert" {
  content  = module.stack.ca_cert_pem
  filename = "${path.module}/ca.pem"

  file_permission = "0644"
}

output "ca_cert_install" {
  description = "Install the box CA so browsers trust the Gateway."

  value = {
    file = abspath(local_file.ca_cert.filename)

    macos_install = "sudo security add-trusted-cert -d -r trustRoot -k /Library/Keychains/System.keychain ${abspath(local_file.ca_cert.filename)}"
    macos_remove  = "sudo security delete-certificate -c '${local.name_prefix}ca' /Library/Keychains/System.keychain"

    # update-ca-certificates only reads files ending in .crt.
    linux_install = "sudo cp ${abspath(local_file.ca_cert.filename)} /usr/local/share/ca-certificates/${local.name_prefix}ca.crt && sudo update-ca-certificates"
    linux_remove  = "sudo rm /usr/local/share/ca-certificates/${local.name_prefix}ca.crt && sudo update-ca-certificates --fresh"

    windows_install = "certutil -addstore -f Root ${abspath(local_file.ca_cert.filename)}"
    windows_remove  = "certutil -delstore Root '${local.name_prefix}ca'"
  }
}
