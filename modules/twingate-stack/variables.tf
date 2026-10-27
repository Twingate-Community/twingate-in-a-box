variable "name_prefix" {
  description = "Prefixes the objects this creates in Twingate and in Docker, so two stacks in one account stay apart."
  type        = string
}

variable "tg_network" {
  description = "Twingate network name (the '<network_name>' in <network_name>.twingate.com)."
  type        = string
}

# The one structural difference between the two deployments in this repo.
variable "host_network" {
  description = "Run the Gateway and Connector in the host's network namespace, so the Gateway reaches whatever the host reaches. When false, Terraform creates a bridge and both containers join it, and nothing off that bridge can reach the Gateway."
  type        = bool
  default     = false
}

variable "request_headers" {
  description = "Headers the Gateway injects into every proxied request. Per-Resource rewrites override these."
  type        = map(string)
}

variable "wildcard_domain" {
  description = "Domain the Gateway certificate wildcards over. Every published app gets an alias under it, so adding or removing a service never regenerates the certificate."
  type        = string
  default     = "box.internal"
}

variable "cert_dns_names" {
  description = "Extra DNS SANs, on top of the wildcard. Only needed for an alias outside wildcard_domain, which puts certificate regeneration back on the table."
  type        = list(string)
  default     = []
}

variable "cert_ip_addresses" {
  description = "IP SANs, for Resources reached by IP rather than by alias."
  type        = list(string)
  default     = []
}

variable "gateway_image" {
  description = "Gateway image."
  type        = string
}

variable "connector_image" {
  description = "Connector image."
  type        = string
}
