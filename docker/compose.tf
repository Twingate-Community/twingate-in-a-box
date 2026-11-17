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

  # Which services are switched on. Each optional service sits in a Compose
  # profile named after it, and var.services lists the profiles to turn on. A
  # service with no profile is always on.
  service_profiles = {
    for service_name, service in local.compose_services :
    service_name => try(tolist(service.profiles), [])
  }
  available_services = sort(distinct(flatten(values(local.service_profiles))))
  enabled_profiles   = var.services == null ? local.available_services : distinct(var.services)

  active_services = [
    for service_name, profiles in local.service_profiles : service_name
    if length(profiles) == 0 || length(setintersection(profiles, local.enabled_profiles)) > 0
  ]
  disabled_services = sort(tolist(setsubtract(keys(local.compose_services), local.active_services)))

  # Config for the published set of Twingate Resources. The Gateway uses this to configure itself, and the Twingate provider uses it to create the Resources.
  twingate_services = {
    for service_name, labels in local.service_labels : service_name => {
      # web publishes a Web App Resource, ssh an SSH Resource. Each is validated
      # in resources.tf, since a typo here would otherwise publish nothing.
      protocol = try(labels["twingate.protocol"], "web")

      # Docker DNS registers every service under <service>.<network>, and the
      # network is named after the domain, so this resolves with no config in the
      # compose file and sits under the wildcard certificate. See locals.tf.
      address = "${service_name}.${local.domain}"

      # Optional second name. An alias outside the domain still works, but puts
      # that name on the certificate, which restarts the Gateway.
      alias = try(labels["twingate.alias"], null)

      # What users type.
      host = coalesce(try(labels["twingate.alias"], null), "${service_name}.${local.domain}")

      # Web only. Serve this app over HTTPS, which the wildcard certificate
      # covers. Set twingate.https=false to publish it over plain HTTP instead.
      https = try(tobool(labels["twingate.https"]), true)

      # 0 when unset. A web app must set it, an SSH server defaults to 22.
      upstream_port = tonumber(try(labels["twingate.port"], 0))

      # Web only. How the Gateway reaches the app. Apps here speak plain HTTP, so
      # the default is NONE. Set twingate.tls for a backend that serves TLS.
      upstream_tls_mode = try(labels["twingate.tls"], "NONE")

      display_name = try(labels["twingate.name"], service_name)
      group_names  = try(split(",", labels["twingate.groups"]), [])

      # Web only.
      headers = {
        for label, value in labels : replace(label, "twingate.header.", "") => value
        if startswith(label, "twingate.header.")
      }
    }
    if try(tobool(labels["twingate.enable"]), false) && contains(local.active_services, service_name)
  }

  # Anything that is not ssh goes down the web path, so a bad protocol value
  # reaches the web resource's precondition instead of silently disappearing.
  web_services = { for name, service in local.twingate_services : name => service if service.protocol != "ssh" }
  ssh_services = { for name, service in local.twingate_services : name => service if service.protocol == "ssh" }

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