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
      address       = "${service_name}.${local.network_name}"
      alias         = try(labels["twingate.alias"], null)
      upstream_port = tonumber(try(labels["twingate.port"], 0))
      display_name  = try(labels["twingate.name"], service_name)
      group_names   = try(split(",", labels["twingate.groups"]), [])

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