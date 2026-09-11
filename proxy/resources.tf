# One Web App Resource per entry in var.services. This is where an app becomes
# reachable through Twingate. Terraform does not create, start or configure the
# apps themselves.
locals {
  # Merge the demo services with the user-defined services. User-defined services take precedence.
  services = merge(local.demo_services, var.services)

  web_apps = {
    for name, service in local.services : name => merge(service, {
      display_name = coalesce(service.name, name)

      # What users type. The alias if there is one, since an address here is
      # usually an IP.
      published_as = coalesce(service.alias, service.address)
    })
  }

  # Groups named by any published service, looked up once each.
  group_names = distinct(flatten([
    for service in values(local.services) : service.groups
  ]))

  group_ids = { for name, found in data.twingate_groups.by_name : name => found.groups[0].id }
}

data "twingate_groups" "by_name" {
  for_each = toset(local.group_names)
  name     = each.value

  lifecycle {
    postcondition {
      condition     = length(self.groups) > 0
      error_message = "No Twingate group named '${each.value}'. Check the groups list on the service that names it."
    }
  }
}

resource "twingate_web_app_resource" "app" {
  for_each = local.web_apps

  name              = each.value.display_name
  address           = each.value.address
  alias             = each.value.alias
  gateway_id        = module.stack.gateway_id
  remote_network_id = module.stack.remote_network_id

  # Gateway currently only supports HTTP on the downstream port.
  downstream = { port = 80 }
  upstream   = { port = each.value.port }

  request_header_rewrites = length(each.value.headers) > 0 ? each.value.headers : null

  dynamic "access_group" {
    for_each = toset([for name in each.value.groups : local.group_ids[name]])
    content {
      group_id = access_group.value
    }
  }
}
