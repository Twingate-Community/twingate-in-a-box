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

variable "cert_dns_names" {
  description = "DNS SANs for Resource aliases."
  type        = list(string)
  default     = []
}

variable "cert_ip_addresses" {
  description = "IP SANs, for Resources addressed by IP."
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
