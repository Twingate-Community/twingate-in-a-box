variable "name_prefix" {
  description = "Prefixes the objects this creates in Twingate and in Docker, so two stacks in one account stay apart."
  type        = string
}

variable "tg_network" {
  description = "Twingate network slug (the '<slug>' in <slug>.twingate.com). Passed in rather than read from the provider: a child module cannot see the provider's configuration."
  type        = string
}

# The one structural difference between the two deployments in this repo.
variable "host_network" {
  description = "Run the Gateway and Connector in the host's network namespace, so the Gateway reaches whatever the host reaches: LAN addresses, VMs, LXCs, other Docker bridges. When false, Terraform creates a bridge and both containers join it, and nothing off that bridge can reach the Gateway."
  type        = bool
  default     = false
}

variable "request_headers" {
  description = "Headers the Gateway injects into every proxied request. Applied with Header.Set(), so a Client cannot spoof them. Per-Resource rewrites override these."
  type        = map(string)
}

variable "cert_dns_names" {
  description = "DNS SANs on the certificate the Gateway presents. The Client validates the name it dialed, so every published address or alias has to appear here. Changing this reissues the leaf, which replaces the Gateway container and drops every app for a few seconds."
  type        = list(string)
  default     = []
}

variable "cert_ip_addresses" {
  description = "IP SANs, for Resources addressed by IP. A verifier will not match an IP literal against a DNS SAN, so an address like 192.168.1.50 has to go here instead of in cert_dns_names."
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
