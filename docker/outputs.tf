output "app_urls" {
  description = "Published apps, once the Twingate Client is connected and the CA is installed."
  value = {
    for name, service in local.twingate_services :
    name => "${service.https ? "https" : "http"}://${service.alias}"
  }
}
