# Reads docker-compose.yaml to find the services to publish. Terraform never
# manages those services.
locals {
  # The compose file is the source of truth for what gets published.
  compose          = yamldecode(file("${path.module}/docker-compose.yaml"))
  compose_services = try(local.compose.services, {})

  # Labels are how a service opts in and configures itself. Normalized to
  # map(string) because an unquoted port decodes as a number.
  service_labels = {
    for service_name, service in local.compose_services :
    service_name => {
      for label, value in try(service.labels, {}) : label => tostring(value)
    }
  }

  # Config for the published set of Twingate Resources. The Gateway uses this to configure itself, and the Twingate provider uses it to create the Resources.
  twingate_services = {
    for service_name, labels in local.service_labels : service_name => {
      # Compose registers every service under <service>.<network> in Docker's
      # embedded DNS, so this resolves without any config in the compose file.
      address = "${service_name}.${local.network_name}"

      # What users type. Defaults under the wildcard so the certificate already
      # covers it. An explicit twingate.alias outside that domain still works,
      # but puts this service back on the certificate.
      alias = coalesce(try(labels["twingate.alias"], null), "${service_name}.${var.wildcard_domain}")

      # Serve this app over HTTPS, which the wildcard certificate covers. Set
      # twingate.https=false to publish it over plain HTTP instead.
      https = try(tobool(labels["twingate.https"]), true)

      upstream_port = tonumber(try(labels["twingate.port"], 0))

      # How the Gateway reaches the app. Apps here speak plain HTTP, so the
      # default is NONE. Set twingate.tls for a backend that serves TLS.
      upstream_tls_mode = try(labels["twingate.tls"], "NONE")

      display_name = try(labels["twingate.name"], service_name)
      group_names  = try(split(",", labels["twingate.groups"]), [])

      headers = {
        for label, value in labels : replace(label, "twingate.header.", "") => value
        if startswith(label, "twingate.header.")
      }
    }
    if try(tobool(labels["twingate.enable"]), false)
  }

  # Used to catch a published service that is not on the box network, which the
  # Gateway would be unable to resolve.
  service_networks = {
    for service_name, service in local.compose_services :
    service_name => can(keys(try(service.networks, {})))
    ? keys(try(service.networks, {}))
    : tolist(try(service.networks, []))
  }

  # Used to catch a service reachable without going through Twingate.
  host_exposed = [
    for service_name, service in local.compose_services :
    service_name if length(try(service.ports, [])) > 0
  ]
}