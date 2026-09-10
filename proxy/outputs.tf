output "app_urls" {
  description = "Published apps, once the Twingate Client is connected."
  value       = { for name, app in local.web_apps : name => "http://${app.published_as}" }
}
