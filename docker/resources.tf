# One Web App Resource per published service. This is where a service becomes
# reachable through Twingate.
resource "twingate_web_app_resource" "app" {
  for_each = local.twingate_services

  name              = each.value.display_name
  address           = each.value.address
  alias             = each.value.alias
  gateway_id        = twingate_gateway.main.id
  remote_network_id = twingate_remote_network.main.id

  downstream = { port = 80 }
  upstream   = { port = each.value.upstream_port }

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
  }
}
