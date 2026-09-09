output "app_urls" {
  description = "Published apps, once the Twingate Client is connected."
  value       = { for name, service in local.twingate_services : name => "http://${service.address}" }
}
