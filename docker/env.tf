# Compose reads .env on its own, so Terraform writes it. That keeps the set of
# services Compose starts identical to the set Terraform publishes, with
# terraform.tfvars as the one place to change either.
resource "local_file" "env" {
  filename        = "${path.module}/.env"
  file_permission = "0600"

  content = <<-EOT
    # Written by terraform apply. Change terraform.tfvars instead.
    TWINGATE_NETWORK=${var.tg_network}
    COMPOSE_PROFILES=${join(",", local.enabled_profiles)}
  EOT

  lifecycle {
    # A typo would otherwise switch nothing on and publish nothing, silently.
    precondition {
      condition     = length(setsubtract(local.enabled_profiles, local.available_services)) == 0
      error_message = "Unknown service in services: ${join(", ", setsubtract(local.enabled_profiles, local.available_services))}. Choose from: ${join(", ", local.available_services)}."
    }
  }
}
