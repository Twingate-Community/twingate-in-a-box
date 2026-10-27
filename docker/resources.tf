# One Web App Resource per published service. This is where a service becomes
# reachable through Twingate.
locals {
  # Groups named by any published service, looked up once each.
  group_names = distinct(flatten([
    for service in values(local.twingate_services) : service.group_names
  ]))

  group_ids = { for name, found in data.twingate_groups.by_name : name => found.groups[0].id }
}

data "twingate_groups" "by_name" {
  for_each = toset(local.group_names)
  name     = each.value

  lifecycle {
    postcondition {
      condition     = length(self.groups) > 0
      error_message = "No Twingate group named '${each.value}'. Check twingate.groups on the service."
    }
  }
}

resource "twingate_web_app_resource" "app" {
  for_each = local.twingate_services

  name              = each.value.display_name
  address           = each.value.address
  alias             = each.value.alias
  gateway_id        = module.stack.gateway_id
  remote_network_id = module.stack.remote_network_id

  # With https on, the Gateway terminates TLS using the wildcard certificate.
  downstream = {
    port     = each.value.https ? 443 : 80
    tls_mode = each.value.https ? "TLS13" : "NONE"
  }

  upstream = {
    port     = each.value.upstream_port
    tls_mode = each.value.upstream_tls_mode
  }

  request_header_rewrites = length(each.value.headers) > 0 ? each.value.headers : null

  dynamic "access_group" {
    for_each = toset([for name in each.value.group_names : local.group_ids[name]])
    content {
      group_id = access_group.value
    }
  }

  lifecycle {
    precondition {
      condition     = each.value.upstream_port > 0
      error_message = "Service '${each.key}' sets twingate.enable but no twingate.port. Add the port the container listens on."
    }

    # Without a group the Resource is created but nobody can reach it, which
    # looks identical to a broken Gateway.
    precondition {
      condition     = length(each.value.group_names) > 0
      error_message = "Service '${each.key}' sets twingate.enable but no twingate.groups. Name at least one Twingate group."
    }

    # The Gateway resolves the address over Docker DNS, which only answers for
    # services on this network.
    precondition {
      condition     = contains(local.service_networks[each.key], local.network_name)
      error_message = "Service '${each.key}' is not on the ${local.network_name} network, so the Gateway cannot resolve ${each.value.address}."
    }

    # A port on the host lets anything on the machine reach the app directly bypassing
    # Twingate and breaking the secure environment.
    precondition {
      condition     = !contains(local.host_exposed, each.key)
      error_message = "Service '${each.key}' exposes ports to the host. Ports reachable from the host can accept headers from any client."
    }
  }
}
