output "app_urls" {
  description = "Published apps, once the Twingate Client is connected and the CA is installed."
  value = {
    for name, service in local.web_services :
    name => "${service.https ? "https" : "http"}://${service.host}"
  }
}

output "disabled_services" {
  description = "Compose services switched off by var.services. docker compose up leaves a running one alone after its profile is turned off, so these need removing by hand."
  value       = local.disabled_services
}
