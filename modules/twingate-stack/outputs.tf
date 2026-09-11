output "remote_network_id" {
  description = "For twingate_web_app_resource.remote_network_id."
  value       = twingate_remote_network.main.id
}

output "gateway_id" {
  description = "For twingate_web_app_resource.gateway_id."
  value       = twingate_gateway.main.id
}

output "network_name" {
  description = "The bridge apps join to be reachable by name. Null when host_network is set, since no network is created."
  value       = one(docker_network.box[*].name)
}

output "ca_cert_pem" {
  description = "The CA the Gateway's certificate chains to."
  value       = tls_self_signed_cert.ca.cert_pem
}

output "metrics_targets" {
  description = "Where the Gateway and Connector serve Prometheus metrics. Container names on the box network, loopback in the host namespace."
  value = var.host_network ? {
    gateway   = "127.0.0.1:${local.gateway_metrics_port}"
    connector = "127.0.0.1:${local.connector_metrics_port}"
    } : {
    gateway   = "${var.name_prefix}gateway:${local.gateway_metrics_port}"
    connector = "${var.name_prefix}connector:${local.connector_metrics_port}"
  }
}
