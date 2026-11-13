# SSH servers in the box trust certificates signed by the SSH CA, so Compose needs
# its public key. Terraform writes it next to docker-compose.yaml, which mounts it.
#
# This is the public half only. The private key lives in terraform.tfstate and is
# uploaded straight into the Gateway container, never onto the host.
resource "local_file" "ssh_ca_pub" {
  content  = module.stack.ssh_ca_public_key
  filename = "${path.module}/ssh-ca.pub"

  file_permission = "0644"
}

output "ssh_hosts" {
  description = "Published SSH servers, once the Twingate Client is connected. Any username works: every session lands as the account in ssh_username."
  value = {
    for name, service in local.ssh_services : name => "ssh ${service.host}"
  }
}

output "ssh_username" {
  description = "The account every SSH session logs in as on the server."
  value       = module.stack.ssh_username
}
