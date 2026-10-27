output "app_urls" {
  description = "Published apps, once the Twingate Client is connected and the CA is installed."
  value = {
    for name, app in local.web_apps :
    name => "${app.https ? "https" : "http"}://${app.published_as}"
  }
}
