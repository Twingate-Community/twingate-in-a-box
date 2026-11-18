# One Twingate Resource per published service: a Web App Resource for web apps,
# an SSH Resource for SSH servers. This is where a service becomes reachable
# through Twingate.
locals {
  # Groups named by any published service, looked up once each.
  group_names = distinct(flatten([
    for service in values(local.twingate_services) : service.group_names
  ]))

  group_ids = { for name, found in data.twingate_groups.by_name : name => found.groups[0].id }

  # A twingate.groups label replaces the default rather than adding to it, so a
  # service can be narrowed to a team without the box group tagging along.
  service_group_ids = {
    for name, service in local.twingate_services : name => (
      length(service.group_names) > 0
      ? [for group in service.group_names : local.group_ids[group]]
      : [twingate_group.box.id]
    )
  }
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

# Checks every published service has to pass, whatever its protocol. Kept off the
# Resources themselves so they are written once.
resource "terraform_data" "service_checks" {
  for_each = local.twingate_services

  lifecycle {
    precondition {
      condition     = contains(["web", "ssh"], each.value.protocol)
      error_message = "Service '${each.key}' sets twingate.protocol to '${each.value.protocol}'. Use web or ssh."
    }

    # The Gateway resolves the address over Docker DNS, which only answers for
    # services on this network.
    precondition {
      condition     = contains(local.service_networks[each.key], local.compose_network)
      error_message = "Service '${each.key}' is not on the ${local.compose_network} network, so the Gateway cannot resolve ${each.value.address}."
    }

    # A port on the host lets anything on the machine reach the service directly,
    # bypassing Twingate and breaking the secure environment.
    precondition {
      condition     = !contains(local.host_exposed, each.key)
      error_message = "Service '${each.key}' exposes ports to the host. Ports reachable from the host bypass Twingate entirely."
    }
  }
}

resource "twingate_web_app_resource" "app" {
  for_each = local.web_services

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
    for_each = toset(local.service_group_ids[each.key])
    content {
      group_id = access_group.value
    }
  }

  depends_on = [terraform_data.service_checks]

  lifecycle {
    precondition {
      condition     = each.value.upstream_port > 0
      error_message = "Service '${each.key}' sets twingate.enable but no twingate.port. Add the port the container listens on."
    }
  }
}

# The Client speaks SSH to the Gateway, which logs in to the server as
# module.stack.ssh_username with a certificate it signs per connection. The
# server only has to trust the SSH CA, see the ssh service in docker-compose.yaml.
resource "twingate_ssh_resource" "ssh" {
  for_each = local.ssh_services

  name              = each.value.display_name
  address           = each.value.address
  alias             = each.value.alias
  gateway_id        = module.stack.gateway_id
  remote_network_id = module.stack.remote_network_id

  # The port users type stays 22, whatever the container listens on.
  upstream = {
    port = each.value.upstream_port > 0 ? each.value.upstream_port : 22
  }

  dynamic "access_group" {
    for_each = toset(local.service_group_ids[each.key])
    content {
      group_id = access_group.value
    }
  }

  depends_on = [terraform_data.service_checks]
}
